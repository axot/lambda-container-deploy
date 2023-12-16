#!/bin/bash

set -e

CONFIG_FILE=".lambda/config.ini"
CONFIG_KEYS=("SERVICE_NAME" "REGION")

LAMBDA_EXECUTION_ROLE='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

function __is_config_key() {
  local key=$1
  for config_key in "${CONFIG_KEYS[@]}"; do
    if [[ $key == $config_key ]]; then
      return 0
    fi
  done
  return 1
}

function __read_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value; do
      if __is_config_key "$key"; then
        eval "$key='$value'"
      fi
    done <"$CONFIG_FILE"
  fi
}

function __update_config() {
  local key=$1
  local value=$2

  # Create the config directory if it does not exist
  CONFIG_DIR=${CONFIG_FILE%%/*}
  mkdir -p "$CONFIG_DIR"

  # Create the config file if it does not exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  if ! grep -q "^$key=" "$CONFIG_FILE"; then
    echo "$key=$value" >>"$CONFIG_FILE"
  else
    new="$(sed "s/^$key=.*/$key=$value/" "$CONFIG_FILE")"
    echo "${new}" >"$CONFIG_FILE"
  fi
}

function __read_env_vars_file() {
  ENV_VARS_FILE=$1
  ENV_VARS=""

  # Read and format environment variables from the .env file
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip empty lines and lines starting with #
    [[ -z "$key" || "$key" == \#* ]] && continue
    # Format and append each variable to the ENV_VARS string
    ENV_VARS+="${key}='${value}',"
  done <"$ENV_VARS_FILE"

  # Remove the trailing comma
  ENV_VARS=${ENV_VARS%,}
  echo "${ENV_VARS}"
}

function __wait_lambda_complete() {
  SERVICE_NAME=$1
  MAX_ATTEMPTS=60
  SLEEP_SECONDS=5

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    echo -ne "Checking if Lambda function is updated (Attempt $attempt/$MAX_ATTEMPTS)...\r"

    # Fetch the current status of the Lambda function
    UPDATE_STATUS=$(aws lambda get-function --function-name "$SERVICE_NAME" \
      --query 'Configuration.LastUpdateStatus' --output text)

    # Check if the status is 'Active'
    if [[ "$UPDATE_STATUS" == "Successful" ]]; then
      echo -ne "\n"
      echo "Lambda Update is Successful."
      break
    elif [[ "$UPDATE_STATUS" == "InProgress" ]]; then
      # Wait before next attempt
      sleep "$SLEEP_SECONDS"
      continue
    else
      echo -ne "\n"
      echo "UNKNOWN Lambda Update Status: $UPDATE_STATUS, exit"
      exit 1
    fi

    # Exit if max attempts reached
    if [[ $attempt -eq $MAX_ATTEMPTS ]]; then
      echo -ne "\n"
      echo "Exceeded maximum attempts to check for Lambda function update. Exiting."
      exit 1
    fi
  done
}

function __generate_id() {
  xxd -l 4 -p /dev/urandom | head -c 7
}

function deploy_lambda() {
  echo "Deploying Lambda function..."
  __read_config

  # TODO: check $2 is not empty
  while [[ $# -gt 0 ]]; do
    case $1 in
    --service-name)
      SERVICE_NAME="$2"
      __update_config "SERVICE_NAME" "$SERVICE_NAME"
      shift
      shift
      ;;
    --region)
      REGION="$2"
      __update_config "REGION" "$REGION"
      shift
      shift
      ;;
    --env-vars-file)
      ENV_VARS_FILE="$2"
      shift
      shift
      ;;
    esac
  done

  if [[ -z $SERVICE_NAME ]]; then
    DEFAULT_SERVICE_NAME=$(basename "$PWD")
    # Prompt the user for the service name, with the current folder name as the default
    read -p "Enter service name [${DEFAULT_SERVICE_NAME}]: " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
    __update_config "SERVICE_NAME" "$SERVICE_NAME"
  fi

  if [[ -z $REGION ]]; then
    # Prompt the user for the region
    read -p "Enter AWS region: " REGION
    export AWS_REGION=$REGION
    __update_config "REGION" "$REGION"
  fi

  # get current aws account id
  ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

  TAG=$(__generate_id)
  docker buildx build --platform linux/arm64 --load -t ${SERVICE_NAME}:${TAG} .

  # Check if the ECR repository exists
  if ! aws ecr describe-repositories --repository-names ${SERVICE_NAME} >/dev/null 2>&1; then
    echo "Repository ${SERVICE_NAME} does not exist. Creating repository..."
    aws ecr create-repository --repository-name ${SERVICE_NAME} >/dev/null 2>&1
  fi

  # Check if the IAM role exists, you can update your custom policy
  ROLE_NAME="${SERVICE_NAME}-role"
  if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "Role $ROLE_NAME does not exist. Creating role..."

    aws iam create-role \
      --role-name $ROLE_NAME \
      --assume-role-policy-document "$LAMBDA_EXECUTION_ROLE" >/dev/null 2>&1

    aws iam attach-role-policy \
      --role-name $ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >/dev/null 2>&1

    # Attach the X-Ray daemon write access policy
    aws iam attach-role-policy \
      --role-name $ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess >/dev/null 2>&1
  fi

  # Build docker image
  ECR_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
  IMAGE_URI=${ECR_URI}/${SERVICE_NAME}:${TAG}
  aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_URI}

  # Push image to ECR
  docker tag ${SERVICE_NAME}:${TAG} ${IMAGE_URI}
  docker push ${IMAGE_URI}

  # Check if the Lambda function exists
  ROLE_ARN=$"arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_NAME}-role"
  if ! aws lambda get-function --function-name ${SERVICE_NAME} >/dev/null 2>&1; then
    echo "Lambda function ${SERVICE_NAME} does not exist. Creating function..."

    aws lambda create-function \
      --function-name ${SERVICE_NAME} \
      --package-type Image \
      --architectures arm64 \
      --tracing-config Mode=Active \
      --code ImageUri="${IMAGE_URI}" \
      --role ${ROLE_ARN} >/dev/null 2>&1

    # wait for the Lambda function to become active
    aws lambda wait function-active-v2 --function-name ${SERVICE_NAME}

    # add permission for public access
    aws lambda add-permission \
      --function-name ${SERVICE_NAME} \
      --statement-id "AllowPublicAccess" \
      --action "lambda:InvokeFunctionUrl" \
      --principal "*" \
      --function-url-auth-type "NONE" >/dev/null 2>&1
  else
    echo "Updating function..."
    aws lambda update-function-code \
      --function-name ${SERVICE_NAME} \
      --image-uri ${IMAGE_URI} >/dev/null 2>&1
  fi

  if [[ -f $ENV_VARS_FILE ]]; then
    __wait_lambda_complete ${SERVICE_NAME}

    ENV_VARS=$(__read_env_vars_file "${ENV_VARS_FILE}")
    # Update the Lambda function configuration
    aws lambda update-function-configuration \
      --function-name ${SERVICE_NAME} \
      --environment "Variables={${ENV_VARS}}" >/dev/null 2>&1
  fi

  if ! aws lambda get-function-url-config --function-name ${SERVICE_NAME} >/dev/null 2>&1; then
    echo "Function URL for ${SERVICE_NAME} does not exist. Creating Function URL..."
    aws lambda create-function-url-config \
      --function-name ${SERVICE_NAME} \
      --auth-type "NONE" >/dev/null 2>&1
  fi

  # Retrieve and print the Function URL
  FUNCTION_URL=$(aws lambda get-function-url-config --function-name ${SERVICE_NAME} --query 'FunctionUrl' --output text)
  echo "Public Lambda Function URL: ${FUNCTION_URL}, you can change auth-type to AWS_IAM"
}

function destroy_lambda() {
  echo "Destroying Lambda function..."
}

case "$1" in
deploy)
  deploy_lambda "${@:2}"
  ;;
*)
  echo "Usage: $0 deploy [--service-name SERVICE_NAME] [--region REGION] [--env-vars-file FILE]"
  exit 1
  ;;
esac

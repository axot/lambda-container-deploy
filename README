
The rapid implementation and verification of ideas are crucial in all aspects of software development. Utilizing AWS Lambda container offers a powerful solution for developers to quickly bring ideas to life and easily validate them. This project has been developed to simplify usage, reducing the hassle of setup and deployment, thus allowing developers to focus on their work. As development progresses, don't forget to use Infrastructure as Code (IaC) to build your environment. Enjoy the exciting development journey!

## Goal
- Rapid Deployment: Achieve the creation of container images, environment setup, and deployment with just a single command.
- Minimal Dependencies: Designed for easy use, even for engineers with limited AWS experience, relying only on bash and aws-cli.
- Customizability: Allows for configuration changes and the addition of other aws resources as development progresses, without being overwritten during deployment.
- Essential Features for Development: No need for certificates or domain setup. Includes features like IP restriction, local environment setup, distributed tracing, and logging capabilities.
- Language Agnostic: While this demo application uses Golang, support for other development languages is possible with just a Dockerfile.

## Usage
Set up and launch a local container application on AWS Lambda, and access your application through https://xxx.lambda-url.ap-northeast-1.on.aws/.
```
$ ./lambda.sh deploy
Deploying Lambda function...
Enter service name [lambda-container-blog]:
Enter AWS region: ap-northeast-1
[+] Building 10.7s (18/18) FINISHED                                                                                                                  docker:orbstack
 => [internal] load .dockerignore                                                                                                                               0.0s
 => => transferring context: 2B                                                                                                                                 0.0s
 => [internal] load build definition from Dockerfile                                                                                                            0.0s
 => => transferring dockerfile: 542B                                                                                                                            0.0s
 => [internal] load metadata for public.ecr.aws/awsguru/aws-lambda-adapter:0.7.1                                                                                2.3s
 => [internal] load metadata for docker.io/library/golang:1.21                                                                                                  2.7s
 => [internal] load metadata for docker.io/library/debian:stable-slim                                                                                           2.5s
 => [builder 1/6] FROM docker.io/library/golang:1.21@sha256:2ff79bcdaff74368a9fdcb06f6599e54a71caf520fd2357a55feddd504bcaffb                                    0.0s
 => => resolve docker.io/library/golang:1.21@sha256:2ff79bcdaff74368a9fdcb06f6599e54a71caf520fd2357a55feddd504bcaffb                                            0.0s
 => FROM public.ecr.aws/awsguru/aws-lambda-adapter:0.7.1@sha256:97c8f81e19e64841df0882d3b3c943db964c554992c1bac26100f1d6c41ea0bb                                0.0s
 => [stage-1 1/4] FROM docker.io/library/debian:stable-slim@sha256:375fb84f3c64691a1b9a9ff5ff3905173dcd0c5e11bc2aebd5c3472a139fa2b4                             0.0s
 => [internal] load build context                                                                                                                               0.0s
 => => transferring context: 17.80kB                                                                                                                            0.0s
 => CACHED [builder 2/6] WORKDIR /app                                                                                                                           0.0s
 => CACHED [builder 3/6] COPY go.* ./                                                                                                                           0.0s
 => CACHED [builder 4/6] RUN go mod download                                                                                                                    0.0s
 => [builder 5/6] COPY . ./                                                                                                                                     0.0s
 => [builder 6/6] RUN go build -v -o myapp                                                                                                                      7.8s
 => CACHED [stage-1 2/4] WORKDIR /app                                                                                                                           0.0s
 => CACHED [stage-1 3/4] COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.7.1 /lambda-adapter /opt/extensions/lambda-adapter                             0.0s
 => [stage-1 4/4] COPY --from=builder /app/myapp /app/myapp                                                                                                     0.0s
 => exporting to image                                                                                                                                          0.0s
 => => exporting layers                                                                                                                                         0.0s
 => => writing image sha256:6c2f79b6321f0cd9b4e7693763d1fb56208c85cc54edf4c2ea1ce9ea25ab4733                                                                    0.0s
 => => naming to docker.io/library/lambda-container-blog:1afe4a5                                                                                                0.0s
Login Succeeded
The push refers to repository [xxx.dkr.ecr.ap-northeast-1.amazonaws.com/lambda-container-blog]
9bec1d67c6e9: Pushed
a809e9675065: Pushed
e7f40a6b4e08: Pushed
03459226eed7: Pushed
1afe4a5: digest: sha256:9affcfcb65c0846891960046a8c25aadf5d3ac24a0117eebc39349688a9b3d61 size: 1157
Lambda function lambda-container-blog does not exist. Creating function...
Function URL for lambda-container-blog does not exist. Creating Function URL...
Public Lambda Function URL: https://xxx.lambda-url.ap-northeast-1.on.aws/
```

You can incorporate environment variables into your Lambda container by utilizing the --env-vars-file option.
```
$ ./lambda.sh deploy --env-vars-file .env
```
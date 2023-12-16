FROM golang:1.21 as builder

ENV GOPROXY=direct

WORKDIR /app

COPY go.* ./
RUN go mod download

COPY . ./

RUN go build -v -o myapp

FROM debian:stable-slim

WORKDIR /app

# tell lambda-adapter which port is listening
ENV PORT=8000

# handle lambda runtime api, convert requests to localhost:8000
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.7.1 /lambda-adapter /opt/extensions/lambda-adapter
COPY --from=builder /app/myapp /app/myapp

CMD ["/app/myapp"]
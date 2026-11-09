#!/bin/bash

APP="$1"

function usage() {
  echo "
  Builds the local source code for an application into a Docker image and
  pushes into the appropriate ECR repository in the deploy account.

  The image can then be deployed by applying the application Terraform and
  providing the image tag when prompted. The application Terraform can be found under
  forms-deploy/infra/deployments/<environment>/forms-[app|admin|runner]

  Dev images must only be used in Development and User Research environments.

  Local directory structure must be
  .
  ├── forms-deploy
  ├── forms-admin
  ├── forms-runner

  Usage:
     Run in a authorized shell for the deploy account using gds-cli or aws-vault
     $0 app-name

     app-name, the name of the application to build forms-admin | forms-runner

     Example:
     gds aws forms-deploy-admin -- ${0} forms-admin"
  exit 0
}

if [ "$APP" != "forms-admin" ] && [ "$APP" != "forms-runner" ]; then
  echo "APP must be either 'forms-admin' or 'forms-runner'."
  usage
fi

if ! docker info > /dev/null 2>&1 ; then
  echo "Docker is not running. Start Docker and try again. more info here:
  https://www.docker.com/products/docker-desktop/"
  exit 1
fi

echo "Building ${APP} docker image"

APP_DIR="../../../${APP}"
GIT_SHA="$(git --git-dir "${APP_DIR}/.git" describe --always --dirty)"
DEFAULT_TAG_SUFFIX="${GIT_SHA}"

echo "
All development image tags begin 'dev-'. You can choose the suffix. Image
tags are immutable and no two images can have the same tag. Images with tags
beginning 'dev-' will be periodically deleted from ECR.
"

read -rp "Enter tag suffix (defaults to abbreviated GIT SHA): [${DEFAULT_TAG_SUFFIX}]: " TAG_SUFFIX
TAG_SUFFIX=${TAG_SUFFIX:-${DEFAULT_TAG_SUFFIX}}
TAG="dev-${TAG_SUFFIX}"

docker build "${APP_DIR}" -t "${APP}:${TAG}"

echo "Logging into Deploy ECR"
aws ecr get-login-password --region eu-west-2 \
  | docker login --username AWS --password-stdin 711966560482.dkr.ecr.eu-west-2.amazonaws.com

docker tag "${APP}:${TAG}" "711966560482.dkr.ecr.eu-west-2.amazonaws.com/${APP}-deploy:${TAG}"

docker push "711966560482.dkr.ecr.eu-west-2.amazonaws.com/${APP}-deploy:${TAG}"

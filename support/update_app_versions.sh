#!/bin/bash

# This script updates the Ruby and Docker Alpine Versions for each app in the
# necessary places to make updating simpler.
#
# Change the NEW_RUBY_VERSION and or the DOCKER_ALPINE_VERSION to the desired
# new version and then run the script. It will create a branch, make the
# necessary updates, commit the changes and push to Github for you to raise a
# PR.

set -e

# Check that Docker is running
if ! docker info > /dev/null 2>&1 ; then
    echo "Docker is not running. Docker is required to find the correct docker
    base image for the new version of Ruby. Start Docker and try again. more
    info here: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Update these values as necessary and then run the script
NEW_RUBY_VERSION="3.4.9"
NEW_ALPINE_VERSION="3.24"

# Constants that should not need to be updated
APPS=(forms-admin forms-runner forms-product-page forms-e2e-tests)
DOCKER_IMAGE_NAME=ruby
DOCKER_IMAGE_TAG="${NEW_RUBY_VERSION}-alpine${NEW_ALPINE_VERSION}"
GIT_BRANCH_NAME="bump_base_image_to_${DOCKER_IMAGE_TAG}"
GIT_COMMIT_MSG=$'Bump base image\n\nBumps core dependencies and base image in Dockerfile.'

append_commit_msg () {
  GIT_COMMIT_MSG_APPEND+=$'\n'
  GIT_COMMIT_MSG_APPEND+="$*"
}

# Checks out main branch and pulls latests. Then creates a new
# branch for the updates. If the branch already exists it continues
# on and uses it.
setup_git_branch () {
  git checkout main
  git pull
  git branch "$GIT_BRANCH_NAME" || echo "Continuing with existing branch"
  git checkout "$GIT_BRANCH_NAME"

  GIT_COMMIT_MSG_APPEND=""
}

# Find the manifest list sha for the version of ruby and alpine
get_new_docker_image_digest () {
  docker buildx imagetools inspect "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" \
    | grep Digest \
    | cut -d : -f 2-3 \
    | tr -d ' '
}

update_ruby_version () {
  local OLD_RUBY_VERSION

  OLD_RUBY_VERSION="$(tr -d ' ' < .ruby-version)"

  if [ "$OLD_RUBY_VERSION" = "$NEW_RUBY_VERSION" ]; then
    return
  fi

  echo "Updating .ruby-version file"
  echo "$NEW_RUBY_VERSION" > .ruby-version

  echo "Running 'bundle install' to update Gemfile.lock"
  bundle install > /dev/null

  git add .ruby-version
  git add Gemfile
  git add Gemfile.lock

  append_commit_msg "- Bumps Ruby from ${OLD_RUBY_VERSION} to ${NEW_RUBY_VERSION}"
}

# Versions of Alpine generally have only one version of Node.js in the repository at a time
get_new_nodejs_version () {
  docker run --rm "$DOCKER_BASE_IMAGE" sh -c 'apk update && apk search -x nodejs' \
    | sed -E -n 's/^nodejs-([0-9.]+).*$/\1/p'
}

update_nodejs_version () {
  if [ ! -f .nvmrc ]; then
    return
  fi

  local OLD_NODEJS_VERSION

  OLD_NODEJS_VERSION="$(tr -d ' ' < .nvmrc)"

  if [ "$OLD_NODEJS_VERSION" = "$NEW_NODEJS_VERSION" ]; then
    return
  fi

  echo "Updating .nvmrc file"
  echo "$NEW_NODEJS_VERSION" > .nvmrc

  echo "Running 'npm install' to update package-lock.json"
  npm install > /dev/null

  git add .nvmrc
  git add package.json
  git add package-lock.json

  append_commit_msg "- Bumps Node.js from $OLD_NODEJS_VERSION to $NEW_NODEJS_VERSION"
}

update_dockerfile_base_image () {
  local OLD_ALPINE_VERSION NEW_NODEJS_MAJOR_VERSION

  OLD_ALPINE_VERSION="$(sed -E -n 's/^ARG ALPINE_VERSION=(.*)$/\1/p' Dockerfile)"

  echo "Updating Dockerfile base image"
  sed -i '' "s/^ARG ALPINE_VERSION=.*$/ARG ALPINE_VERSION=${NEW_ALPINE_VERSION}/" Dockerfile
  sed -i '' "s/^ARG RUBY_VERSION=.*$/ARG RUBY_VERSION=${NEW_RUBY_VERSION}/" Dockerfile

  sed -i '' "s/^ARG DOCKER_IMAGE_DIGEST=.*$/ARG DOCKER_IMAGE_DIGEST=${NEW_DOCKER_IMAGE_DIGEST}/" Dockerfile

  NEW_NODEJS_MAJOR_VERSION="$(echo "$NEW_NODEJS_VERSION" | cut -d. -f 1)"
  sed -i '' "s/^ARG NODEJS_VERSION=.*$/ARG NODEJS_VERSION=${NEW_NODEJS_MAJOR_VERSION}/" Dockerfile

  git add Dockerfile

  if [ "$OLD_ALPINE_VERSION" != "$NEW_ALPINE_VERSION" ]; then
    append_commit_msg "- Bumps Alpine Linux from ${OLD_ALPINE_VERSION} to ${NEW_ALPINE_VERSION}"
  fi
}

commit_changes () {
  echo "Committing changes"
  git commit -S -m "${GIT_COMMIT_MSG}${GIT_COMMIT_MSG_APPEND}" \
    && git push -u origin "${GIT_BRANCH_NAME}" \
    || echo "There are no commits, perhaps you've already run this script?"
}

# Main script begins here
NEW_DOCKER_IMAGE_DIGEST="$(get_new_docker_image_digest)"
DOCKER_BASE_IMAGE="${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}@${NEW_DOCKER_IMAGE_DIGEST}"

if [ -z "$NEW_DOCKER_IMAGE_DIGEST" ]; then
  echo 2>&1 "No Docker image found for ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}, aborting"
  exit 1
fi

NEW_NODEJS_VERSION="$(get_new_nodejs_version)"

echo "Updating to ${DOCKER_BASE_IMAGE}"
echo "ALPINE_VERSION=$NEW_ALPINE_VERSION"
echo "RUBY_VERSION=$NEW_RUBY_VERSION"
echo "NODEJS_VERSION=$NEW_NODEJS_VERSION"

for app in "${APPS[@]}"; do
  echo -e "\n\n****** BEGINNING UPDATE OF ${app} ********"
  cd "../../${app}"

  setup_git_branch

  update_ruby_version

  update_nodejs_version

  update_dockerfile_base_image

  commit_changes

  echo -e "****** FINISHED UPDATING ${app} ********\n\n"
  cd - > /dev/null
done

echo "Now raise a PR for each repo for the branches named ${GIT_BRANCH_NAME}"

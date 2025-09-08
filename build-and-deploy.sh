#!/bin/bash

set -e

# Configuration
DOCKER_REPO="ocristopfer/samba"
DOCKERFILE_PATH="./src/Dockerfile"
BUILD_CONTEXT="./src"

# Get version from git tag or use 'latest'
if git describe --tags --exact-match 2>/dev/null; then
    VERSION=$(git describe --tags --exact-match)
else
    VERSION="latest"
fi

echo "Building Docker image..."
echo "Repository: $DOCKER_REPO"
echo "Version: $VERSION"
echo "Dockerfile: $DOCKERFILE_PATH"
echo "Build context: $BUILD_CONTEXT"

# Build the Docker image
docker build -f "$DOCKERFILE_PATH" -t "$DOCKER_REPO:$VERSION" -t "$DOCKER_REPO:latest" "$BUILD_CONTEXT"

echo "Docker image built successfully!"

# Push to Docker Hub
echo "Pushing to Docker Hub..."
docker push "$DOCKER_REPO:$VERSION"

if [ "$VERSION" != "latest" ]; then
    docker push "$DOCKER_REPO:latest"
fi

echo "Docker image pushed successfully!"
echo "Image available at: $DOCKER_REPO:$VERSION"
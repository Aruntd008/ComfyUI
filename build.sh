#!/bin/bash

# Default values
IMAGE_NAME="comfyui-runpod"
IMAGE_TAG="latest"
PUSH=false
NO_CACHE=false
PLATFORM=""
EXTRA_ARGS=""

# Help function
show_help() {
    echo "Usage: ./build.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name         Set the image name (default: comfyui-runpod)"
    echo "  -t, --tag          Set the image tag (default: latest)"
    echo "  -p, --push         Push the image to registry after building"
    echo "  --platform <arch>  Set the target platform (e.g., linux/amd64)"
    echo "  --no-cache         Build without using any cache"
    echo "  --build-arg <arg>  Pass a build argument to Docker (e.g., --build-arg HTTP_PROXY=...)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Example:"
    echo "  ./build.sh --name arun/comfyui --tag v1.0.0 --push"
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) IMAGE_NAME="$2"; shift ;;
        -t|--tag) IMAGE_TAG="$2"; shift ;;
        -p|--push) PUSH=true ;;
        --platform) PLATFORM="$2"; shift ;;
        --no-cache) NO_CACHE=true ;;
        --build-arg) EXTRA_ARGS="$EXTRA_ARGS --build-arg $2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "🔨 Building Docker image: ${FULL_IMAGE_NAME}"

BUILD_CMD="docker build -t ${FULL_IMAGE_NAME}"

if [ "$NO_CACHE" = true ]; then
    echo "🚫 Building without cache"
    BUILD_CMD="${BUILD_CMD} --no-cache"
fi

if [ -n "$PLATFORM" ]; then
    echo "🎯 Target platform: ${PLATFORM}"
    BUILD_CMD="${BUILD_CMD} --platform ${PLATFORM}"
fi

if [ -n "$EXTRA_ARGS" ]; then
    BUILD_CMD="${BUILD_CMD} ${EXTRA_ARGS}"
fi

BUILD_CMD="${BUILD_CMD} ."

# Execute the build command
echo "Running: ${BUILD_CMD}"
eval $BUILD_CMD

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Push if requested
if [ "$PUSH" = true ]; then
    echo "🚀 Pushing image: ${FULL_IMAGE_NAME}"
    docker push "${FULL_IMAGE_NAME}"
    
    if [ $? -ne 0 ]; then
        echo "❌ Push failed!"
        exit 1
    fi
    echo "✅ Push successful!"
fi

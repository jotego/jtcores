#!/bin/bash
set -e

BUILDER_NAME="jotego-builder"
PLATFORMS="linux/amd64,linux/arm64"

main(){
    SUCCESS=()
    FAIL=()

    parse_args $*

    if $PUSH_IMAGES; then
        prepare_builder $BUILDER_NAME
        docker login
    fi

    image="jtcore-base"
    path="."
    if build $image $path $PUSH_IMAGES $PLATFORMS; then
        SUCCESS+=("$image")
    else
        FAIL+=("$image")
    fi

    image="jtcore13"
    path="/opt/altera"
    if build $image $path $PUSH_IMAGES $PLATFORMS; then
        SUCCESS+=("$image")
    else
        FAIL+=("$image")
    fi

    image="jtcore17"
    path="/opt/intelFPGA_lite"
    if build $image $path $PUSH_IMAGES $PLATFORMS; then
        SUCCESS+=("$image")
    else
        FAIL+=("$image")
    fi

    image="jtcore20"
    path="/opt/intelFPGA_lite"
    if build $image $path $PUSH_IMAGES $PLATFORMS; then
        SUCCESS+=("$image")
    else
        FAIL+=("$image")
    fi

    image="linter"
    path="."
    if build $image $path $PUSH_IMAGES $PLATFORMS; then
        SUCCESS+=("$image")
    else
        FAIL+=("$image")
    fi

    image="simulator"
    path="."
    if build $image $path $PUSH_IMAGES $PLATFORMS; then
        SUCCESS+=("$image")
    else
        FAIL+=("$image")
    fi

    echo "✅ Builds completed:"
    printf '  - %s\n' "${SUCCESS[@]}"

    echo "❌ Builds failed:"
    printf '  - %s\n' "${FAIL[@]}"

    if $PUSH_IMAGES; then
        echo "📤 Images were pushed to Docker Hub."
    else
        echo "📦 Images were loaded locally"
    fi
}

prepare_builder() {
    local name=$1
    if ! docker buildx inspect "$name" >/dev/null 2>&1; then
        echo "🔧 Creating buildx builder '$name'..."
        docker buildx create --name "$name" --driver "docker-container" --use
    else
        docker buildx use "$name"
    fi
    docker buildx inspect --bootstrap
}

build() {
    local image=$1
    local path=$2
    local push_flag=$3
    local platforms=$4

    echo "🚧 Building jotego/$image..."
    if $push_flag; then
        if ! docker buildx build --platform "$platforms" --file $image.df --tag jotego/$image:latest --push $path; then
            echo "⚠️ Build failed for $image"
            return 1
        fi
    else
        if ! docker build --file $image.df --tag jotego/$image:latest --load $path; then
            echo "⚠️ Build failed for $image"
            return 1
        fi
    fi
}

parse_args() {
    PUSH_IMAGES=false

	while [[ $# -gt 0 ]]; do
        case "$1" in
            --push) PUSH_IMAGES=true ;;
        esac
        shift
    done
}

main $*
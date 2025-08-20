#!/bin/bash -e

BUILDER_NAME="jotego-builder"

main(){
    SUCCESS=()
    FAIL=()

    parse_args "$@"

    if $PUSH_IMAGES; then
        prepare_builder $BUILDER_NAME
        docker login
    fi

    build "jtcore-base" "$JTFRAME"              "linux/amd64,linux/arm64"
    build "jtcore13"    "/opt/altera"           "linux/amd64"
    build "jtcore17"    "/opt/intelFPGA_lite"   "linux/amd64"
    build "jtcore20"    "/opt/intelFPGA_lite"   "linux/amd64"
    build "linter"      "."                     "linux/amd64,linux/arm64"
    build "simulator"   "."                     "linux/amd64,linux/arm64"

    print_results
}

prepare_builder() {
    local name=$1
    if ! docker buildx inspect "$name" >/dev/null 2>&1; then
        echo "Creating buildx builder '$name'..."
        docker buildx create --name "$name" --driver "docker-container" --use
    else
        docker buildx use "$name"
    fi
    docker buildx inspect --bootstrap
}

build() {
    local image=$1
    local path=$2
    local platforms=$3

    echo "Building jotego/$image..."
    if $PUSH_IMAGES; then
        if docker buildx build --platform "$platforms" --file $image.df --tag jotego/$image:latest --push $path; then
            SUCCESS+=("$image")
        else
            echo "Build failed for $image"
            FAIL+=("$image")
        fi
    else
        if docker build --file $image.df --tag jotego/$image:latest --load $path; then
            SUCCESS+=("$image")
        else
            echo "Build failed for $image"
            FAIL+=("$image")
        fi
    fi
}

parse_args() {
    PUSH_IMAGES=false

	while [[ $# -gt 0 ]]; do
        case "$1" in
            --push) PUSH_IMAGES=true ;;
            *) echo "Usage: $0 [--push]" && exit 1 ;;
        esac
        shift
    done
}

print_results() {
    echo "Builds completed:"
    if [ "${#SUCCESS[@]}" -gt 0 ]; then
        printf '  - %s\n' "${SUCCESS[@]}"
    else
        echo "  -"
    fi

    if [ "${#FAIL[@]}" -gt 0 ]; then
        echo "Builds failed:"
        printf '  - %s\n' "${FAIL[@]}"
    fi

    if $PUSH_IMAGES; then
        echo "Images were pushed to Docker Hub."
    else
        echo "Images were loaded locally"
    fi
}

main "$@"

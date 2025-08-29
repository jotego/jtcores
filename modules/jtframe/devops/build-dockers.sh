#!/bin/bash -e

BUILDER_NAME="jotego-builder"
BUILDER_NAME_MULTIARCH="jotego-multiarch-builder"

main(){
    SUCCESS=()
    FAIL=()

    parse_args "$@"

    if $PUSH_IMAGES; then
        prepare_builder true "$BUILDER_NAME_MULTIARCH"
        docker login
    else
        prepare_builder false "$BUILDER_NAME"
    fi

    declare -A CTX_BASE=(
        [jtframe]="$JTFRAME"
    )
    declare -A CTX_JTCORE13=(
        [jtframe]="$JTFRAME"
        [altera]="/opt/altera"
    )
    declare -A CTX_FPGA=(
        [intel]="/opt/intelFPGA_lite"
    )

    build "jtcore-base" "linux/amd64,linux/arm64"   CTX_BASE
    build "jtcore13"    "linux/amd64"               CTX_JTCORE13
    build "jtcore17"    "linux/amd64"               CTX_FPGA
    build "jtcore20"    "linux/amd64"               CTX_FPGA
    build "linter"      "linux/amd64,linux/arm64"
    build "simulator"   "linux/amd64,linux/arm64"

    print_results
}

prepare_builder() {
    local multiarch=$1
    local name=$2

    if docker buildx inspect "$name" >/dev/null 2>&1; then
        docker buildx use "$name"
        docker buildx inspect --bootstrap
        return
    fi

    echo "Creating buildx builder '$name'..."
    if $multiarch; then 
        docker buildx create --name "$name" --driver "docker-container" --use
    else
        docker buildx create --name "$name" --use
    fi
    docker buildx inspect --bootstrap
}

build() {
    local image=$1
    local platforms=$2
    local contexts_map_name=${3-}

    local -a build_contexts=()
    if [[ -n "$contexts_map_name" ]]; then
        local -n ctx_ref="$contexts_map_name"
        for name in "${!ctx_ref[@]}"; do
            build_contexts+=( --build-context "$name=${ctx_ref[$name]}" )
        done
    fi

    echo "Building jotego/$image..."
    if $PUSH_IMAGES; then
        if docker buildx build "${build_contexts[@]}" --platform "$platforms" --file "$image.df" --tag "jotego/$image:latest" --push .; then
            SUCCESS+=("$image")
        else
            echo "Build failed for $image"
            FAIL+=("$image")
        fi
    else
        if docker buildx build "${build_contexts[@]}" --file "$image.df" --tag "jotego/$image:latest" --load .; then
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
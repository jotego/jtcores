#!/bin/bash
# Simulate all scenes below the current verification folder.

main() {
    local run_folder
    run_folder=$(mktemp)
    trap 'rm -f "$run_folder"' EXIT

    make_runner "$run_folder"
    run_all_games "$run_folder"
    collect_images
}

make_runner() {
    local run_folder=$1

    cat > "$run_folder" <<'EOF'
#!/bin/bash
cd "$1" || exit 1
pwd
SIM=jtsim
if [ -e sim.sh ]; then
    SIM=sim.sh
fi

while IFS= read -r -d '' scene; do
    "$SIM" -batch -s "${scene##*/}"
done < <(find -L scenes -maxdepth 1 -mindepth 1 -type d -print0)
EOF
    chmod +x "$run_folder"
}

# note that this is designed to work when "scenes" is a symbolic link to
# a folder
run_all_games() {
    local run_folder=$1
    local scene_dir game_dir
    local -a game_dirs=()

    while IFS= read -r -d '' scene_dir; do
        [ -d "$scene_dir" ] || continue
        game_dir=$(realpath -s "$(dirname "$scene_dir")")
        game_dirs+=("$game_dir")
    done < <(find . \( -type d -o -type l \) -name scenes -print0)

    [ ${#game_dirs[@]} -eq 0 ] && return
    parallel "$run_folder" ::: "${game_dirs[@]}"
}

collect_images() {
    rm -rf allscenes
    mkdir -p allscenes
    [ -d scenes ] || return
    find -L scenes -type f \( -name '*.png' -o -name '*.jpg' \) -exec mv -t allscenes {} +
}

main "$@"

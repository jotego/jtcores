#!/bin/bash
# Simulate all scenes below the current verification folder.
# arguments are passed directly to jtsim. Set simulation macros
# with -d MACRO, as in jtsim

main() {
    local run_folder
    run_folder=$(mktemp)
    trap 'rm -f "$run_folder"' EXIT

    make_runner "$run_folder"
    run_all_games "$run_folder" "$@"
    collect_images
}

make_runner() {
    local run_folder=$1

    cat > "$run_folder" <<'EOF'
#!/bin/bash
game_dir="${!#}"
if [ "$#" -gt 1 ]; then
    set -- "${@:1:$#-1}"
else
    set --
fi

cd "$game_dir" || exit 1
pwd
SIM=jtsim
if [ -e sim.sh ]; then
    SIM=sim.sh
fi

while IFS= read -r -d '' scene; do
    "$SIM" -batch -s "${scene##*/}" "$@"
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
    shift

    while IFS= read -r -d '' scene_dir; do
        [ -d "$scene_dir" ] || continue
        game_dir=$(realpath -s "$(dirname "$scene_dir")")
        game_dirs+=("$game_dir")
    done < <(find . \( -type d -o -type l \) -name scenes -print0)

    [ ${#game_dirs[@]} -eq 0 ] && return
    parallel -j1 "$run_folder" "$@" ::: "${game_dirs[@]}"
}

collect_images() {
    rm -rf allscenes
    mkdir -p allscenes
    [ -d scenes ] || return

    # Keep only the frame rendered by jtsim for each scene.  Scene directories
    # also contain snapshot.png and diff images, whose repeated names would
    # otherwise make mv leave an incomplete allscenes directory.
    while IFS= read -r -d '' scene; do
        local name=${scene##*/}
        for ext in png jpg; do
            [ -f "$scene/$name.$ext" ] && cp "$scene/$name.$ext" "allscenes/$name.$ext"
        done
    done < <(find -L scenes -maxdepth 1 -mindepth 1 -type d -print0)
}

main "$@"

#!/bin/bash
# stash_sources.sh <JTROOT> <BUILDDIR> <GENROOT>
#
# Stash a Quartus build as a SELF-CONTAINED, REBUILDABLE tree. The artifact
# mirrors the repository layout: every captured file lands at
#   GENROOT/<path relative to JTROOT>
# (files outside JTROOT under GENROOT/extern/), and the build directory at its
# own relative path. Every .qip/.qsf reference is therefore resolvable and the
# .qpf opens directly in a plain Quartus.
#
# References are resolved RECURSIVELY from the build dir's .qsf/.qip:
#   - plain and quoted paths after any  -name *_FILE  assignment
#   - Tcl forms: [file join $::quartus(qip_path) "..."] and
#     [file normalize [file join ...]] (qip_path = the directory of that qip)
#   - SEARCH_PATH entries: the whole directory's HDL/include/hex content is
#     copied, since `include resolution through it leaves no FILE assignment
#   - referenced .qip/.qsf files are parsed too (visited-set bounded)
# Best-effort: a failure here must never fail the build.
set -u

JTROOT=${1:?JTROOT}
BUILDDIR=${2:?BUILDDIR}
GENROOT=${3:?GENROOT}

[ -d "$BUILDDIR" ] || { echo "stash_sources: no build dir $BUILDDIR"; exit 0; }

VISITED=$(mktemp)
QUEUE=$(mktemp)
trap 'rm -f "$VISITED" "$QUEUE"' EXIT

# canonical absolute path of an existing file (no realpath on some hosts)
canon() { # $1=path -> stdout abs path, empty if missing
    [ -f "$1" ] || return 0
    ( cd "$(dirname "$1")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$1")" )
}
canond() { # directory version
    [ -d "$1" ] || return 0
    ( cd "$1" 2>/dev/null && printf '%s\n' "$PWD" )
}

mirror_rel() { # $1=abs path -> the artifact-relative destination
    case $1 in
        "$JTROOT"/*) printf '%s' "${1#"$JTROOT"/}" ;;
        *)           printf 'extern/%s' "${1#/}"   ;;
    esac
}

copy_file() { # $1=abs file
    local rel; rel=$(mirror_rel "$1")
    mkdir -p "$GENROOT/$(dirname "$rel")" 2>/dev/null
    cp -f "$1" "$GENROOT/$rel" 2>/dev/null
}

copy_searchdir() { # $1=abs dir: HDL sources, includes and data files, recursively
    local d rel; d=$(canond "$1"); [ -n "$d" ] || return 0
    rel=$(mirror_rel "$d")
    ( cd "$d" && find . -type f \( -name '*.v' -o -name '*.sv' -o -name '*.vh' \
        -o -name '*.svh' -o -name '*.inc' -o -name '*.hex' -o -name '*.mif' \) \
        -print0 2>/dev/null ) |
    while IFS= read -r -d '' f; do
        mkdir -p "$GENROOT/$rel/$(dirname "$f")" 2>/dev/null
        cp -f "$d/$f" "$GENROOT/$rel/$f" 2>/dev/null
    done
}

enqueue() { # $1=abs qip/qsf path
    grep -qxF "$1" "$VISITED" 2>/dev/null && return 0
    echo "$1" >> "$VISITED"
    echo "$1" >> "$QUEUE"
}

# Extract one "kind<TAB>path" per reference line of a qip/qsf. Tcl noise is
# stripped textually; $::quartus(qip_path) becomes @QIP@ for the caller to
# substitute with the file's own directory.
extract_refs() { # $1=file
    sed -n 's/\r$//; /^set_global_assignment/p' "$1" 2>/dev/null |
    awk '
        {
            kind=""; val=""
            for(i=1;i<=NF;i++) if($i=="-name"){ kind=$(i+1); vstart=i+2; break }
            if(kind=="") next
            if(kind!="SEARCH_PATH" && kind !~ /_FILE$/) next
            if(kind ~ /^IP_/) next
            for(i=vstart;i<=NF;i++) val=val" "$i
            print kind "\t" val
        }' |
    sed -e 's/\[file normalize//g' -e 's/\[file join//g' -e 's/\]//g' \
        -e 's/\$::quartus(qip_path)/@QIP@/g' |
    awk -F'\t' '
        {
            n=split($2, t, /[ \t]+/); path=""
            for(i=1;i<=n;i++){
                p=t[i]; gsub(/^"|"$/, "", p)
                if(p=="" ) continue
                if(p=="ON"||p=="OFF") { path=""; break }
                path = (path=="" ? p : path "/" p)
            }
            if(path!="") print $1 "\t" path
        }'
}

process() { # $1=abs qip/qsf
    local file=$1 dir kind path abs
    dir=$(dirname "$file")
    extract_refs "$file" | while IFS=$'\t' read -r kind path; do
        path=${path//@QIP@/$dir}
        case $path in
            /*) : ;;
            *)  path=$dir/$path ;;
        esac
        if [ "$kind" = SEARCH_PATH ]; then
            copy_searchdir "$path"
        else
            abs=$(canon "$path"); [ -n "$abs" ] || continue
            copy_file "$abs"
            case $abs in
                *.qip|*.qsf) enqueue "$abs" ;;
            esac
        fi
    done
}

# 1) the build directory itself, at its own relative location (minus the
#    multi-GB Quartus working state; the bitstream is packaged under release/)
RELBUILD=$(mirror_rel "$(canond "$BUILDDIR")")
mkdir -p "$GENROOT/$RELBUILD"
tar -C "$BUILDDIR" \
    --exclude=db --exclude=incremental_db --exclude=output_files \
    -cf - . 2>/dev/null | tar -C "$GENROOT/$RELBUILD" -xf - 2>/dev/null

# 2) recursive reference resolution, seeded from the build dir's lists
find "$BUILDDIR" \( -name '*.qip' -o -name '*.qsf' \) -print0 2>/dev/null |
while IFS= read -r -d '' lst; do
    abs=$(canon "$lst"); [ -n "$abs" ] && echo "$abs" >> "$QUEUE" && echo "$abs" >> "$VISITED"
done

while [ -s "$QUEUE" ]; do
    CUR=$(head -1 "$QUEUE"); sed -i 1d "$QUEUE" 2>/dev/null || { tail -n +2 "$QUEUE" > "$QUEUE.n"; mv "$QUEUE.n" "$QUEUE"; }
    process "$CUR"
done

N=$(find "$GENROOT" -type f 2>/dev/null | wc -l)
echo "stash_sources: $N files mirrored under ${GENROOT#"$JTROOT"/} (open $RELBUILD/*.qpf in Quartus)"
exit 0

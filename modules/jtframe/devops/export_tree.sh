#!/bin/bash
# Packs the full source tree of a synthesis into one tarball, so the project
# can be used without the framework. The file list comes from
# "jtframe files plain" (one path per line, JTROOT-relative or absolute);
# .qip entries and the project .qsf are expanded for the target files
# (sys/pll trees, sys_top.sdc) and SEARCH_PATH include folders.
# usage: export_tree.sh <files list> [project.qsf] <out.tar.gz>
set -uo pipefail

OUT="${@: -1}"
LISTF="$1"
QSF="${2:-}"
[ "$QSF" = "$OUT" ] && QSF=""
ROOT="${JTROOT:?}"
STAGE=$(mktemp -d)
LIST=$(mktemp)
SEEN=$(mktemp)

resolve() { # <value> <base dir>
    local v="$1" base="$2" q
    if [[ "$v" == *"file join"* ]]; then
        q=$(echo "$v" | sed -nE 's/.*\[file join [^ ]+ +"([^"]+)" *\].*/\1/p')
        [ -z "$q" ] && q=$(echo "$v" | sed -nE 's/.*\[file join [^ ]+ +([^] "]+) *\].*/\1/p')
        v="$q"
    fi
    v="${v%\"}"; v="${v#\"}"
    [ -z "$v" ] && return 0
    [[ "$v" != /* ]] && v="$base/$v"
    echo "$v"
}

scan_qip() { # qsf or qip: pull file assignments, recurse into qips
    local f="$1" base kind val path
    [ -e "$f" ] || return 0
    grep -qxF "$f" "$SEEN" && return 0
    echo "$f" >> "$SEEN"
    echo "$f" >> "$LIST"
    base=$(dirname "$f")
    while read -r kind val || [ -n "${kind:-}" ]; do
        path=$(resolve "$val" "$base")
        case "$kind" in
            QIP_FILE) scan_qip "$path";;
            SEARCH_PATH)
                for i in "$path"/*.vh "$path"/*.inc; do
                    [ -e "$i" ] && echo "$i" >> "$LIST"
                done;;
            *) [ -e "$path" ] && echo "$path" >> "$LIST";;
        esac
    done < <(sed -nE 's/^set_global_assignment( -entity "[^"]+")?( -library "[^"]+")? +-name +(SYSTEMVERILOG_FILE|VERILOG_FILE|VHDL_FILE|SDC_FILE|VERILOG_INCLUDE_FILE|MISC_FILE|SOURCE_FILE|QIP_FILE|SEARCH_PATH) +(.*)$/\3 \4/p' "$f")
}

while read -r f; do
    [ -z "$f" ] && continue
    [[ "$f" != /* ]] && f="$ROOT/$f"
    case "$f" in
        *.qip) scan_qip "$f";;
        *)     [ -e "$f" ] && echo "$f" >> "$LIST";;
    esac
done < "$LISTF"
[ -n "$QSF" ] && scan_qip "$QSF"
# data files linked into the build folder (fonts, sound filters, core hex)
for i in "$(dirname "$(realpath "$LISTF")")"/*.hex; do
    [ -e "$i" ] && echo "$i" >> "$LIST"
done

sort -u "$LIST" | while read -r f; do
    rel=$(realpath --relative-to="$ROOT" "$(realpath "$f")" 2>/dev/null) || continue
    case "$rel" in ../*) rel="external/${f##*/}";; esac
    mkdir -p "$STAGE/$(dirname "$rel")"
    cp -L "$f" "$STAGE/$rel"
    echo "$rel" >> "$STAGE/files.txt"
done

tar -C "$STAGE" -czf "$OUT" .
echo "export_tree: $(wc -l < "$STAGE/files.txt") files -> $OUT"
rm -rf "$STAGE" "$LIST" "$SEEN"

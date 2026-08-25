#!/bin/bash
# usage:
# xjtcore <corename> [--debug] target-names...
set -e

git config --global --add safe.directory /jtcores
cd /jtcores
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe

source $JTFRAME/bin/setprj.sh > /dev/null
export PATH=$PATH:/usr/local/go/bin

# 1st argument is the core name
CORENAME=$1
shift
# next argument can select debug mode, which is on by default
NODBG=--nodbg
if [ $1 = --debug ]; then
    NODBG=
    shift
fi

if [ -z "$BETAKEY" ]; then
    BETAKEY=`printf "%04X%04X" $RANDOM $RANDOM`
    echo "WARNING: remote compilation with no beta key. Assigning random one"
fi

export JTUTIL=/jtutil
mkdir $JTUTIL
printf "%08x" 0x$BETAKEY | xxd -r -p > $JTUTIL/beta.bin
ls -l $JTUTIL/beta.bin


if [ -e $CORES/$CORENAME/cfg/macros.def ]; then
    # Beta key is enabled for cores listed in beta.yaml
    for TARGET in $*; do
        if jtframe cfgstr $CORENAME --target=$TARGET --output bash | grep -q '^export JTFRAME_SKIP='; then
            echo "Skipping $CORENAME for $TARGET because of JTFRAME_SKIP"
            continue
        fi
        if [ $TARGET != pocket ]; then SKIPPOCKET=--skipPocket; else unset SKIPPOCKET; fi
        jtframe mra $NODBG --skipROM $SKIPPOCKET $CORENAME
        echo "Compiling for $TARGET"
        # set -e would abort here on a failed build, before the gen stash
        # below. Capture the code and re-raise it AFTER stashing, so a FAILED
        # build still uploads the exact sources fed to Quartus for triage.
        set +e
        jtutil seed --max-trials 4 $CORENAME -$TARGET $NODBG --nolinter
        SEED_RC=$?
        set -e
        # Preserve the jtframe-generated build sources before reclaiming
        # disk. These are the outputs of `jtframe parse/mem/mmr/files`
        # (the parsed .qsf/.qpf, the *_game_sdram.v + mem_ports.inc from
        # `jtframe mem`, the MMR register modules, the .qip filelists) plus
        # the linked .hex files — i.e. exactly what was fed to Quartus.
        # `jtutil seed` builds under cores/<core>/seed/<target>/<seedNum>/build.
        # The heavy Quartus working dirs (db, incremental_db, output_files) are
        # excluded by name at any depth — GNU tar's unanchored --exclude matches
        # the nested per-seed copies — since they're multi-GB build state, not
        # generated source, and the bitstream is already packaged under release/.
        # Stashed to $JTROOT/gen/<core>/<target> so the workflow can upload it as
        # an artifact; the seed build dir is deleted right after to recover disk.
        BUILDDIR=$CORES/$CORENAME/seed/$TARGET
        GENDIR=$JTROOT/gen/$CORENAME/$TARGET
        if [ -d "$BUILDDIR" ]; then
            mkdir -p "$GENDIR"
            tar -C "$BUILDDIR" \
                --exclude=db --exclude=incremental_db --exclude=output_files \
                -cf - . | tar -C "$GENDIR" -xf -
        fi
        # Make the stash SELF-CONTAINED. files.qip/.qsf NAME every source Quartus
        # compiled but only REFERENCE it by path - the hand-written HDL lives in
        # cores/ and modules/, so the artifact alone couldn't be audited or rebuilt.
        # Resolve every reference and copy the real file in under
        # sources/<path relative to $JTROOT>, so gen/<core>/<target> holds the
        # generated sources AND the sources they were built against.
        # Best-effort: a failure here must never fail the build.
        if [ -d "$BUILDDIR" ] && [ -d "$GENDIR" ]; then
            find "$BUILDDIR" \( -name '*.qip' -o -name '*.qsf' \) -print0 2>/dev/null |
            while IFS= read -r -d '' lst; do
                awk '/set_global_assignment[[:space:]]+-name[[:space:]]+[A-Z_]*FILE/ {
                        f=$NF; gsub(/[]["]/,"",f);
                        if(f=="ON"||f=="OFF") next; print f }' "$lst" 2>/dev/null |
                while IFS= read -r f; do
                    # resolve relative refs WITHOUT realpath (not portable / absent
                    # on some hosts): cd canonicalises the dir, then re-attach basename
                    case $f in
                        /*) src=$f ;;
                        *)  src=$( cd "$(dirname "$lst")" 2>/dev/null &&
                                   cd "$(dirname "$f")"   2>/dev/null &&
                                   printf '%s/%s' "$PWD" "$(basename "$f")" ) ;;
                    esac
                    [ -n "$src" ] && [ -f "$src" ] || continue
                    case $src in
                        "$JTROOT"/*) rel=${src#"$JTROOT"/} ;;
                        *)           rel=extern/$(basename "$src") ;;
                    esac
                    mkdir -p "$GENDIR/sources/$(dirname "$rel")" 2>/dev/null
                    cp -f "$src" "$GENDIR/sources/$rel" 2>/dev/null
                done
            done || true
            echo "xjtcore: stashed $(find "$GENDIR/sources" -type f 2>/dev/null | wc -l) source files into gen/$CORENAME/$TARGET/sources"
        fi
        # recover hard disk space
        rm -rf "$BUILDDIR"
        # re-raise the seed/Quartus result now that gen sources are stashed
        [ "$SEED_RC" -eq 0 ] || exit "$SEED_RC"
    done
fi

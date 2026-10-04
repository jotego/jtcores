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
        # Stash a self-contained, rebuildable mirror of everything fed to
        # Quartus (generated sources, every file the .qip/.qsf chains reference
        # - recursively, Tcl path forms included - and the SEARCH_PATH dirs the
        # `includes resolve through). The tree mirrors the repo layout, so the
        # .qpf opens in a plain Quartus. Best-effort by design.
        BUILDDIR=$CORES/$CORENAME/seed/$TARGET
        GENDIR=$JTROOT/gen/$CORENAME/$TARGET
        bash $JTFRAME/devops/stash_sources.sh "$JTROOT" "$BUILDDIR" "$GENDIR" || true
        # recover hard disk space
        rm -rf "$BUILDDIR" $CORES/$CORENAME/$TARGET
        # re-raise the seed/Quartus result now that gen sources are stashed
        [ "$SEED_RC" -eq 0 ] || exit "$SEED_RC"
    done
fi

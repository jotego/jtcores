#!/bin/bash
# Define JTROOT before sourcing this file

if (echo $PATH | grep modules/jtframe/bin -q); then
    unalias jtcore
    PATH=$(echo $PATH | sed 's/:[^:]*jtframe\/bin//g')
    PATH=$(echo $PATH | sed 's/:\.//g')
    unset JT12 JT51 CC MRA ROM CORES
fi

export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe
# . path comes before JTFRAME/bin as setprj.sh
# can be in the working directory and in JTFRAME/bin
PATH=$PATH:.:$JTFRAME/bin

if [ ! -d "$JTBIN" ]; then
    export JTBIN=$JTROOT/release
    mkdir -p $JTBIN
fi

# derived variables
export CORES=$JTROOT/cores
RLS=$JTROOT/release
# Adds all core names to the auto-completion list of bash
ALLCORES=$(ls $CORES| tr '\n' ' ')
complete -W "$ALLCORES" jtcore
complete -W "$ALLCORES" swcore
unset ALLFOLDERS

export ROM=$JTROOT/rom
export RLS=$JTROOT/release
export MRA=$JTROOT/release/mra
export POCKET=$JTFRAME/target/pocket
DOC=$JTROOT/doc
MAME=$JTROOT/doc/mame
export MODULES=$JTROOT/modules

function cdjt {
    cd $JTROOT
}

function cdrls {
    cd $JTROOT/release
}

function lint {
    local CORENAME=$1
    if [ -z "$CORENAME" ]; then
        # derive the default core name from the path
        CORENAME=$(realpath . --relative-to=$CORES)
        CORENAME=${CORENAME%%/*}
    fi
    if [ ! -d "$CORES/$CORENAME" ]; then
        echo "Use a valid core name or run it from inside the core folder"
        return 1
    fi
    lint-one.sh $CORENAME -u JTFRAME_SKIP
}

function swcore {
    if [ -z "$JTROOT" ]; then
        echo Have you forgot to define JTROOT?
        return
    fi
    if [ ! -z "$2" ]; then
        cd $JTROOT/cores/$1/$2
        return
    fi
    if [ -z "$1" ]; then
        echo "Use swcore <corename>"
        return 1
    fi
    if [ ! -d "$JTROOT/cores/$1" ]; then
        echo "No folder for $1 core"
        return 1
    fi
    # get the location relative to $CORES/corename
    local cores=$(realpath $JTROOT/cores)
    local cur=`pwd`
    cur="${cur#$cores/}"
    if [ "$cur" = `pwd` ]; then
        # not in a core folder
        cd $JTROOT/cores/$1/$2
        return
    fi
    # extract the path after the current core
    cur="${cur#*/}"
    cd "$JTROOT/cores/$1"

    # replicate as much as possible from the previous location
    IFS=/ read -ra folders <<< $cur
    for i in ${folders[@]};do
        if [ -d $i ]; then
            cd $i
        else
            break
        fi
    done
}

# change to a folder inside "$CORES/*/ver" folders
function cdgame {
    local setname=$1
    if [ -z "$JTROOT" ]; then
        echo Have you forgot to define JTROOT?
        return 1
    fi
    if [ -z "$setname" ]; then
        echo "Use cdgame <MAME setname>"
        return 1
    fi
    local path=$(find $JTROOT/cores -name "$1" -path "*/ver/$setname" -type d | head -n 1)
    if [ -z "$path" ]; then echo "No $setname in verification folders"; return 1; fi
    cd "$path"
}

if [ "$1" != "--quiet" ]; then
    echo "Use swcore <corename> to switch to a different core once you are"
    echo "inside the cores folder"
fi

# Git prompt
source $JTFRAME/bin/git-prompt.sh
export GIT_PS1_SHOWUPSTREAM=
export GIT_PS1_SHOWDIRTYSTATE=
export GIT_PS1_SHOWCOLORHINTS=
function __git_subdir {
    PWD=$(pwd)
    echo ${PWD##${JTROOT}/}
}
PS1='[$(__git_subdir)$(__git_ps1 " (%s)")]\$ '

# Displays all available macros
# The argument is used to filter the output
function jtmacros {
    case "$1" in
        --using|-u)
            for i in `find $CORES -name "*.def" | xargs grep --files-with-matches "$2"`; do
                i=`dirname $i`
                i=${i##$CORES/}
                i=${i%%/cfg}
                len0=${#i}
                i=${i%%/ver/game}
                len1=${#i}
                if [ $len0 = $len1 ]; then echo $i; fi
            done;;
        --help|-h)
            cat<<EOF
jtmacros shows macro related information.
Usage:
    --using|-u name     shows all cores using a given macro
    --help|-h           shows this screen
    name                shows the description of macro "name"
    no arguments        shows the description of all macros
EOF
        ;;
        *)
            if [ ! -z "$1" ]; then
                grep -i "$1" $JTFRAME/doc/macros.md
            else
                cat $JTFRAME/doc/macros.md
                echo
            fi;;
    esac
}

# Cleans up the simulation folder
function cleansim {
    rm -f *.wav *.f *.def *bak *.raw *.bin test.* game_test.v frame*jpg \
          microrom.mem nanorom.mem *.log *.h waiver
    rm -rf obj_dir sdram.old cfg history
}

# compare two binary files
function hexdiff {
    sdiff --suppress-common-lines <(xxd $1) <(xxd $2)
}

# starts gtkwave and opens the test dump file in the current folder
function gw {
    local DIR=$(basename $(pwd))
    local DMPFILE=
    local FOUND=0
    if [ -e test.gtkw ]; then DMPFILE=$DIR/test.gtkw; fi
    for ext in lxt fst vcd; do
        if [ -e test.$ext ]; then
            # starts from .. so the folder name is shown on
            # GTKWave's title bar
            (cd ..; gtkwave $DIR/test.$ext $DMPFILE &)
            FOUND=1
            break
        fi
    done
    if [ $FOUND = 0 ]; then
        echo "No test.lxt, test.fst, test.vcd in the current folder"
        return 1
    fi
}

# set default jtframe target by calling the command-line target function
export TARGET=sidi128
function target {
    if [ -z "$1" ]; then
        echo $TARGET
        return 0
    fi
    if [ ! -d $JTFRAME/target/$1 ]; then
        echo "$1 is not a valid JTFRAME target"
        return 1
    fi
    export TARGET=$1
    echo $TARGET
}

# check that git hooks are present
for HOOK in $JTFRAME/bin/hooks/*; do
    echo cp --update $HOOK $(git rev-parse --git-path hooks)
done

if ! git config -l | grep instead > /dev/null; then
    cat<<EOF
Consider executing:
    git config --global url.ssh://git@github.com/.insteadOf https://github.com/

in order to avoid the need for GitHub tokens when pushing submodules
EOF
fi
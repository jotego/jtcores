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

# returns the current working directory with the core name
# changed by its argument. Use it to refer to the equivalent current folder
# in a different core
function incore {
    IFS=/ read -ra string <<< $(pwd)
    local j="/"
    local next=0
    for i in ${string[@]};do
        if [ $next = 0 ]; then
            j=${j}${i}/
        else
            next=0
            j=${j}$1/
        fi
    done
    echo $j
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

function jtpull {
    cd $JTFRAME
    git pull
    cd -
}

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
    if [ -e test.lxt ]; then
        gtkwave test.lxt &
    elif [ -e test.fst ]; then
        local DMPFILE=
        if [ -e test.gtkw ]; then DMPFILE=test.gtkw; fi
        gtkwave test.fst $DMPFILE &
    elif [ -e test.vcd ]; then
        gtkwave test.vcd &
    else
        echo "No test.lxt, test.fst, test.vcd in the current folder"
    fi
}

# generates a list of valid core names based on the existance of the TOML file
function get_cores {
    find "$CORES" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
      if [ -e "$dir/cfg/mame2mra.toml" ]; then
        dir=$(basename "$dir")
        echo -n "$dir "
      fi
    done
}

# check that git hooks are present
cp --update $JTFRAME/bin/post-merge $(git rev-parse --git-path hooks)/post-merge

# Recompiles jtframe quietly after each commit
cd $JTFRAME
JTFRAME_POSTCOMMIT=$(git rev-parse --git-path hooks)/post-commit
if [ ! -e $JTFRAME_POSTCOMMIT ]; then
    cat > $JTFRAME_POSTCOMMIT <<EOF
    #!/bin/bash
    jtframe > /dev/null
    if [ $(git branch --no-color --show-current) = master ]; then
        # automatically push changes to master branch
        git push
    fi
EOF
    chmod +x $JTFRAME_POSTCOMMIT
fi

if ! git config -l | grep instead > /dev/null; then
    cat<<EOF
Consider executing:
    git config --global url.ssh://git@github.com/.insteadOf https://github.com/

in order to avoid the need for GitHub tokens when pushing submodules
EOF
fi
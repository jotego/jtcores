#!/bin/bash

# Abort early if python is not available: this script depends on it
if ! command -v python >/dev/null 2>&1; then
    echo "setprj.sh: python is required. Please install python (or provide python as 'python' on PATH) before running." >&2
    exit 1
fi

# Remove jtframe from the PATH first
TMP=`mktemp`
cat > $TMP <<EOF
import os

paths = os.getenv('PATH').split(':')
# Filter out paths containing 'modules/jtframe'
new_paths = [path for path in paths if 'modules/jtframe' not in path]
print(':'.join(new_paths))
EOF

export PATH=`python $TMP`
rm -f $TMP

# restore all environment variables
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe
export CODEX_HOME=$JTROOT/.codex

source $JTFRAME/bin/setprj.sh
cd $JTROOT

if [ ! -z "$*" ]; then
    # execute the rest as a command
    echo "Executing " $*
    $*
fi

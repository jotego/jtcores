#!/bin/bash
# You can pass a number which is the used to copy a file from objram folder

ALT=objram/sf-obj${1}.bin
if [ -e $ALT ]; then
    ln -sf $ALT sf-obj.bin
    shift
fi

# Create a default file
if [ ! -e sf-obj.bin ]; then
    ln -s objram/sf-obj1.bin sf-obj.bin
fi

go.sh -d NOMAIN -d NOCHAR -d NOSCR -d NOSOUND -d GRAY -d OBJLOAD -video 2 -w $*

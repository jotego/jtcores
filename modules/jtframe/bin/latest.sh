#!/bin/bash
# returns the latest version

M=`git tag | grep ^v | cut -d . -f 1 | sort -n | tail -n 1`
F=`git tag | grep ^$M | cut -d . -f 2 | sort -n | tail -n 1`
P=`git tag | grep "^$M\.$F" | cut -d . -f 3 | sort -n | tail -n 1`

echo "$M.$F.$P"
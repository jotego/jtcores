#!/bin/bash

# Report which cores are affected by the last commit

GITLOG=`mktemp`
GITMOD=`mktemp`

# Get list of GIT modules
grep path .gitmodules > $GITMOD
sed -i "s/[ \t]*path = //" $GITMOD

function check_core {
	CORENAME=$1
	if [ ! -e $CORES/$CORENAME/cfg/macros.def ]; then return 0; fi
	if ! jtframe files plain $CORENAME; then return 0; fi
	while IFS= read -r LINE; do
		# reduce submodule files to just the module path
		while IFS= read -r MOD; do
			if [[ $LINE == "$MOD"* ]]; then
				LINE=$MOD
			fi
		done < $GITMOD

		if grep -q "$LINE" $GITLOG; then
			CHANGED="$CHANGED $CORENAME"
			echo $CORENAME $LINE
			return 0
		fi
	done < files
	return 1
}

IDs="$*"
if [ -z "$IDs" ]; then IDs=`git rev-parse HEAD`; fi

# for each commit ID, compare the files changed with those used by each core
for ID in $IDs; do
	git diff-tree --no-commit-id --name-only -r $ID > $GITLOG
	for i in $CORES/*; do
		check_core `basename $i`
	done
done

# Display the main titles affected
if [ ! -z "$CHANGED" ]; then
	ISSUE=`mktemp`
	echo "# Main titles affected" > $ISSUE
	jtframe mra $CHANGED --skipMRA --skipPocket --skipROM --mainonly --names | sed "s/^/- \[ \] /" >> $ISSUE
	gh issue create --assignee jtmiki --body-file $ISSUE --title "Regression test (`date +%Y-%M-%d`)" --label regression
	rm -f $ISSUE
fi

rm -f $GITLOG $GITMOD
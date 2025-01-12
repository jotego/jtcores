#!/bin/bash

# Report which cores are affected by the last commit

GITLOG=`mktemp`
GITMOD=`mktemp`

function get_git_modules {
	grep path .gitmodules > "$GITLOG"
	sed -i "s/[ \t]*path = //" "$GITLOG"
}

function check_core {
	local CORENAME=$1
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

function get_changed_files {
	local IDs="$*"
	if [ -z "$IDs" ]; then IDs=`git rev-parse HEAD`; fi

	# for each commit ID, compare the files changed with those used by each core
	for ID in $IDs; do
		git diff-tree --no-commit-id --name-only -r $ID > "$GITLOG"
		for i in $CORES/*; do
			check_core `basename $i`
		done
	done
}

function clean_up {
	rm -f $GITLOG $GITMOD
}

function show_one_game {
	jtframe mra $1 --skipMRA --skipPocket --skipROM --mainonly --names 2>/dev/null | sort --random-sort | head -n 1
}

function sort_file {
	local temp=`mktemp`
	sort $1 > temp
	mv temp $1
}

function make_github_issue {
	local ISSUE=`mktemp`
	echo "# Main titles affected" > $ISSUE
	for core in $CHANGED; do
		game=`show_one_game $core`
		if [ -z "$game" ]; then continue; fi
		echo "$game" | sed "s/^/- \[ \] /" >> $ISSUE
	done
	sort_file $ISSUE
	echo $(wc -l $ISSUE) "games to be tested"
	gh issue create --assignee jtmiki --body-file $ISSUE --title "Regression test (`date +%Y-%M-%d`)" --label regression
	rm -f $ISSUE
}

# main
cd $JTROOT
get_git_modules
get_changed_files

# Display the main titles affected
if [ -z "$CHANGED" ]; then
	clean_up
	exit 0
fi

make_github_issue
clean_up

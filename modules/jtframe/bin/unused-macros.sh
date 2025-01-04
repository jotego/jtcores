#!/bin/bash
all_macros=$(grep -ho "^JTFRAME_[^ |]*" $JTFRAME/doc/macros.md | sort | uniq)
bad=0
for macro in $all_macros; do
	found=0
	for file in `find $CORES -name "*.v" -type f`; do
		if grep --quiet --max-count=1 $macro $file; then
			found=1
			break
		fi
	done
	for file in `find $CORES -name "*.def" -type f`; do
		if grep --quiet --max-count=1 $macro $file; then
			found=1
			break
		fi
	done
	for file in `find $JTFRAME -name "*.v" -type f`; do
		if grep --quiet --max-count=1 $macro $file; then
			found=1
			break
		fi
	done
	for file in `find $JTFRAME -name "*.sv" -type f`; do
		if grep --quiet --max-count=1 $macro $file; then
			found=1
			break
		fi
	done
	for file in `find $JTFRAME -name cfgstr -type f`; do
		if grep --quiet --max-count=1 $macro $file; then
			found=1
			break
		fi
	done
	if grep --quiet $macro $JTFRAME/hdl/ver/test.cpp; then
		found=1
	fi
	if [ $found = 0 ]; then
		echo "$macro not used"
		bad=1
	fi
done
exit $bad
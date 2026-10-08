#!/bin/bash
used_macros=$(find $CORES -name "*.def" | xargs grep -ho "^JTFRAME_[^ =+]*"|sort|uniq)
bad=0
for macro in $used_macros; do
	if ! grep --quiet $macro $JTFRAME/doc/macros.md; then
		found_in=$(find $CORES -name "*.def" | xargs grep -H $macro)
		echo $macro is unknown
		for core in $found_in; do
			echo -e "\t"$(realpath --relative-to=$CORES $core| cut -f 1 -d/)
		done
		bad=1
	fi
done
exit $bad



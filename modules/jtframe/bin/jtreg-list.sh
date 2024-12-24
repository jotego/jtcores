#!/bin/bash
find $CORES -name setnames.txt -delete
for i in `find $CORES -maxdepth 1 -type d | xargs -l1 realpath --relative-to=$CORES`; do
	if [ -e $CORES/$i/cfg/macros.def ]; then
		jtframe mra --skipROM --mainonly --skipPocket $i
	else
		echo "Skipping $i"
	fi
done

cd $CORES
LOG=$JTROOT/log/reglist.log
rm -f $LOG
for i in `find -name setnames.txt`; do
	CORE=`echo $i | cut -d"/" -f2`
	while IFS= read -r line; do
	 	echo $(basename $CORE) "$line" >> $LOG
	done < "$i"
done

echo "See $LOG for the regression list"
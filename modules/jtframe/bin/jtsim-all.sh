#!/bin/bash
# simulate all scenes in the folders below

set -e
RUN_FOLDER=`mktemp`

cat > $RUN_FOLDER <<EOF
#!/bin/bash
cd \$1
pwd
for SCN in \`find scenes -maxdepth 1 -mindepth 1 -type d | xargs -l1 basename\`; do
	jtsim -batch -s \$SCN
done
EOF
chmod +x $RUN_FOLDER

for EACH in `find -type d -name scenes`; do
	if [ ! -z "$GAME" ]; then GAME="$GAME "; fi
	GAME="${GAME}`realpath $EACH/..`"
done

parallel $RUN_FOLDER ::: $GAME
rm -f $RUN_FOLDER


#!/bin/bash

exit_with_error() {
  echo -e "\nERROR:\n${1}\n"
  exit 1
}

check_dependencies() {
  if [[ $OSTYPE == darwin* ]]; then
    for j in unzip md5 cat cut; do
      command -v ${j} > /dev/null 2>&1 || exit_with_error "This script requires\n${j}"
    done
  else
    for j in unzip md5sum cat cut; do
      command -v ${j} > /dev/null 2>&1 || exit_with_error "This script requires\n${j}"
    done
  fi
}

check_permissions () {
  if [ ! -w ${BASEDIR} ]; then
    exit_with_error "Cannot write to\n${BASEDIR}"
  fi
}

read_ini () {
  if [ ! -f ${BASEDIR}/build_rom.ini ]; then
    exit_with_error "Missing build_rom.ini"
  else
    source ${BASEDIR}/build_rom.ini
  fi
}

uncompress_zip() {
  if [ -f ${BASEDIR}/${zip} ]; then
    tmpdir=tmp.`date +%Y%m%d%H%M%S%s`
    unzip -qq -d ${BASEDIR}/${tmpdir}/ ${BASEDIR}/${zip}
    if [ $? != 0 ] ; then
      rm -rf ${BASEDIR}/$tmpdir
      exit_with_error "Something went wrong\nwhen extracting\n${zip}"
    fi
  else
    exit_with_error "Cannot find ${zip}"
  fi
}

generate_rom() {
  for i in "${ifiles[@]}"; do
      # ensure provided zip contains required files
      if [ ! -f "${BASEDIR}/${tmpdir}/${i}" ]; then
        rm -rf ${BASEDIR}/$tmpdir
        exit_with_error "Provided ${zip}\nis missing required file:\n\n${i}"
      else
        cat ${BASEDIR}/${tmpdir}/${i} >> ${BASEDIR}/${tmpdir}/${ofile}
     fi
  done
}

validate_rom() {

  if [[ $OSTYPE == darwin* ]]; then
    ofileMd5sumCurrent=$(md5 -r ${BASEDIR}/${tmpdir}/${ofile}|cut -f 1 -d " ")
  else
    ofileMd5sumCurrent=$(md5sum ${BASEDIR}/${tmpdir}/${ofile}|cut -f 1 -d " ")
  fi

  if [[ "${ofileMd5sumValid}" != "${ofileMd5sumCurrent}" ]]; then
    echo -e "\nExpected checksum:\n${ofileMd5sumValid}"
    echo -e "Actual checksum:\n${ofileMd5sumCurrent}"
    mv ${BASEDIR}/${tmpdir}/${ofile} .
    rm -rf ${BASEDIR}/$tmpdir
    echo -e "Generated ${ofile}\nis invalid.\nThis is more likely\ndue to incorrect\n${zip} content."
  else
    mv ${BASEDIR}/${tmpdir}/${ofile} ${BASEDIR}/.
    rm -rf ${BASEDIR}/$tmpdir
    echo -e "\nChecksum verification passed\n\nCopy the ${ofile}\ninto root of SD card\nalong with the rbf file.\n"
  fi
}

BASEDIR=$(dirname "$0")

echo "Generating ROM ..."

## verify dependencies
check_dependencies

## verify write permissions
check_permissions

## load ini
read_ini

## extract package
uncompress_zip

## build rom
generate_rom

## verify rom
validate_rom

# create MiST file
echo "Use $ofile_mist for MiST and $ofile for MiSTer"
cp $ofile $ofile_mist


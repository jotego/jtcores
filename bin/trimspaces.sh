#!/bin/bash

find $JTGNG_ROOT -name "*.v" | xargs sed -i  's/[[:space:]]*$//'
find $JTGNG_ROOT -name "*.vhd" | xargs sed -i  's/[[:space:]]*$//'
find $JTGNG_ROOT -name "*.bak" -delete

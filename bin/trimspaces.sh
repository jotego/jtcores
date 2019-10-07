#!/bin/bash

find $JTGNG -name "*.v" | xargs sed -i  's/[[:space:]]*$//'
find $JTGNG -name "*.vhd" | xargs sed -i  's/[[:space:]]*$//'
find $JTGNG -name "*.bak" -delete

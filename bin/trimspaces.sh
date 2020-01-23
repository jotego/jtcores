#!/bin/bash

find $JTROOT -name "*.v" | xargs sed -i  's/[[:space:]]*$//'
find $JTROOT -name "*.vhd" | xargs sed -i  's/[[:space:]]*$//'
find $JTROOT -name "*.bak" -delete

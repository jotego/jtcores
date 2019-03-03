#!/bin/bash

find -name "*.v" | xargs sed -i  's/[[:space:]]*$//'
find -name "*.vhd" | xargs sed -i  's/[[:space:]]*$//'
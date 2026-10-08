#!/bin/bash -e
g++ tracker_test.cpp -o tracker_test
tracker_test
rm -f tracker_test
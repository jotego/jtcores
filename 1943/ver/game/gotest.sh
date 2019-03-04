#!/bin/bash
# Enter test mode

# example:
# gotest.sh -frame 75 -video -nosnd -d VIDEO_START=73 -deep

../../../bin/sim.sh $* -sysname 1943 -mist -d DIP_TEST -nosnd

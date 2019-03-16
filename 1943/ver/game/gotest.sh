#!/bin/bash
# Enter test mode

# example:
# gotest.sh -frame 75 -video -nosnd -d VIDEO_START=73 -deep

go.sh $* -mist -d DIP_TEST -nosnd

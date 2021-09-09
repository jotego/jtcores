#!/bin/bash

ln -s --force coin_inputs.hex sim_inputs.hex
go.sh -g sfj -video 1600 -d DUMP_START=1400 -w -d SIM_INPUTS -nosnd $*

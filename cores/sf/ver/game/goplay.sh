#!/bin/bash

ln -s --force coin_inputs.hex sim_inputs.hex
go.sh -g sfj -video 1800 -d DUMP_START=1340 -w -d SIM_INPUTS -nosnd $*

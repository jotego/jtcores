#!/bin/bash

ln -s --force coin_inputs.hex sim_inputs.hex
go.sh -video 1400 -d DUMP_START=1340 -w -d SIM_INPUTS -nosnd $*

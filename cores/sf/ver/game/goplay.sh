#!/bin/bash

ln -s --force coin_inputs.hex sim_inputs.hex
go.sh -video 1180 -d DUMP_START=1170 -w -d SIM_INPUTS -nosnd $*

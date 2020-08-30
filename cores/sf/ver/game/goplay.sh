#!/bin/bash

ln -s --force coin_inputs.hex sim_inputs.hex
go.sh -video 1050 -d DUMP_START=1040 -w -d SIM_INPUTS $*

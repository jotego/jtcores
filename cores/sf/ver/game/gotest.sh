#!/bin/bash

ln -s --force test_inputs.hex sim_inputs.hex
go.sh -video 200 -w -d DUMP_START=60 -d SIM_INPUTS -d JTFRAME_SIM_DIPS="~32'h8000" $*

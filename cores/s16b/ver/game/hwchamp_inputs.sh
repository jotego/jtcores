#!/bin/bash
cp test_option1.hex sim_inputs.hex
sim.sh -nosnd -g hwchamp -video 35 -inputs -w  -d DUMP_START=31 -d DUMPMAIN

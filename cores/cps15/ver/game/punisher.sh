#!/bin/bash
# Tests punisher music
# Sound starts at frame 514
cp punisher.inputs sim_inputs.hex
go.sh -g punisher -d DIP_TEST -d PUNISHER_SIM -inputs -w -video 550 -d DUMP_START=505

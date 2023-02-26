#!/bin/bash
cp cotton_coin.hex sim_inputs.hex
sim.sh -g cotton -video 150 -inputs -w -d JT7759_FIFO_DUMP -d DUMP_START=34

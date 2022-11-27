#!/bin/bash
# The MCU is interrupted once around frame 63
# and then again when the demo play starts 
# around frame 1687
go.sh -nosnd -w -d DUMP_START=1680 -video 1890
#!/bin/bash

# isolated banks
sim.sh -nodump -period 15.6 -time 10 -1banks
sim.sh -nodump -period 15.6 -time 10 -2banks
sim.sh -nodump -period 15.6 -time 10 -3banks

# allbanks
sim.sh -nodump -period 15.6 -time 10

# Special cases
sim.sh -nodump -period 15.6 -time 10 -norefresh
sim.sh -nodump -period 15.6 -time 10 -perf

#Latencytest
sim.sh -nodump -period 15.6 -time 100
sim.sh -nodump -period 15.6 -time 100 -idle 90

# MiSTer connection
sim.sh -nodump -period 15.6 -mister -time 10 -perf
sim.sh -nodump -period 15.6 -mister -time 20 -idle 90
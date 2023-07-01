#!/bin/bash

# isolated banks
go.sh -nodump -period 15.6 -time 10 -1banks
go.sh -nodump -period 15.6 -time 10 -2banks
go.sh -nodump -period 15.6 -time 10 -3banks

# allbanks
go.sh -nodump -period 15.6 -time 10

# Special cases
go.sh -nodump -period 15.6 -time 10 -norefresh
go.sh -nodump -period 15.6 -time 10 -perf

#Latencytest
go.sh -nodump -period 15.6 -time 100
go.sh -nodump -period 15.6 -time 100 -idle 90

# MiSTer connection
go.sh -nodump -period 15.6 -mister -time 10 -perf
go.sh -nodump -period 15.6 -mister -time 20 -idle 90
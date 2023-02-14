#!/bin/bash
for i in scene*; do
    k=${i#scene}
    sim_video.sh -s $k -verilator
done

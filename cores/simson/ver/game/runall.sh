#!/bin/bash

for i in scenes/*; do
    sim.sh -s $(basename $i)
done

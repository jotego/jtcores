#!/bin/bash
echo -e 0\\n0 > scrpos.hex
sim.sh -load -d NOMAIN -nosnd -d NOMCU $*

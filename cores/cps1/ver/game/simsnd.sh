#!/bin/bash
# Do not forget to call with -g game and -time frames like
# -frame won't work as video is disabled
# simsnd.sh -g nemo -time 600

sim.sh -d NOMAIN -d NOVIDEO -d FAKE_LATCH $*

#!/bin/bash
# Do not forget to call with -g game and -frame frames like
# gosnd.sh -g nemo -frame 600

go.sh -d NOMAIN -d NOVIDEO -d FAKE_LATCH $*

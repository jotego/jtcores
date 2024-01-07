#!/bin/bash
# This file is part of JTFRAME.
# JTFRAME program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# JTFRAME program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

# Author: Jose Tejada Gomez. Twitter: @topapate
# Version: 1.0
# Date: 12-1-2023

PRJCOMMIT=$(git rev-parse --short HEAD)

# if there is a version tag that matches the commit, use it instead
PRJTAG=`git tag --points-at $PRJCOMMIT | grep "^v[0-9]\+\.[0-9]\+\.[0-9]\+$" | tail -n 1`
if [ ! -z "$PRJTAG" ]; then
    echo $PRJTAG;
    exit 0
else
    echo $PRJCOMMIT
    exit 1
fi

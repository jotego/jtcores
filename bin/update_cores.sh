#!/bin/bash
cores="1942 1943 gng commando"

(for i in $cores; do echo $i; done) | parallel jtcore 
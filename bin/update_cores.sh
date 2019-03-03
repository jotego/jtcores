#!/bin/bash
cores="1942 1943 gng"

(for i in $cores; do echo jt$i; done) | parallel compile.sh 
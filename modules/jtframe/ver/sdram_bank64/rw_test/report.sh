#!/bin/bash

parallel echo go.sh -nodump -readonly -norefresh {1} -idle {2} ::: -mister -mist :::: <(seq 10 20 90) > jobs
bash jobs | sed  /LXT"\|"WARNING"\|"make/d
| tee report.txt
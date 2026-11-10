#!/bin/bash
main() { simunit.sh --run "$(dirname "$0")" "$@"; }
main "$@"

# Agent Recommendations

- Prefer `yq` over `awk` when parsing YAML for clarity.
- Use the `test` command (or `[ ]`) for condition checks outside a explicit if statement instead of `[[ ]]`.
- Indent with 4 spaces (not 2).
- Order functions by use: place `main` at the top and list helper functions in the order they are called.
- Source `setprj.sh` before running project scripts to set `JTROOT` and `CORES`.

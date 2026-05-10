package main

import (
    "fmt"
    "os"
    "os/exec"
)

func main() {
    cmd := exec.Command("jtframe", "mmr", "rungun")
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr

    if err := cmd.Run(); err != nil {
        fmt.Fprintf(os.Stderr, "init: failed to generate MMR files: %v\n", err)
        os.Exit(1)
    }
}

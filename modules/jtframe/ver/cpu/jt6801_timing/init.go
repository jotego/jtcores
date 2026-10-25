package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
)

func main() {
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/6801.yaml", "baf841439c7905da2a4b88494c5db8e1e13132e2bd756c2d513d91d3fd079782")
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/680x.yaml", "5f10bd56dfd2ea0b16d73de3598007e76921de94f829bed88e3d23075e68400d")
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/6801_bus.yaml", "0e0b026d8faecec6a6f6849a59f77fa6f27de97328b0993345cf1e101520303b")
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6801", "--output", "6801")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	assertDigest("6801.uc", "61bf360b0e0bddb9170594d80735e9f543f4081511afab95a572b270e6f560ca")
	assertDigest("6801.vh", "2feb8dab50bebdff2fe045757f36210cafc9049d07c6d3a6768cedb8878fe850")
	checkOtherProfile("6301", "445163a157db81389aa36da928bde9615943305547283ab64bd47614eafa83db")
}

func checkOtherProfile(name, uc string) {
	cmd := exec.Command("jtframe", "ucode", "jt680x", name, "--output", "negative_profile")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil { panic(err) }
	assertDigest("negative_profile.uc", uc)
	for _, path := range []string{"negative_profile.uc", "negative_profile.vh", "negative_profile_param.vh"} {
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) { panic(err) }
	}
}

func assertDigest(path, expected string) {
	data, err := os.ReadFile(path)
	if err != nil { panic(err) }
	sum := sha256.Sum256(data)
	actual := hex.EncodeToString(sum[:])
	if actual != expected { panic(fmt.Sprintf("6801 profile generation mismatch for %s: got %s", path, actual)) }
}

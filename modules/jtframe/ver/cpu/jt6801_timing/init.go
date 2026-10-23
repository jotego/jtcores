package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
)

func main() {
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/6801.yaml", "0f95d0bb1328294389cdc4fe3f26b5192e24753d87577785389053eee4b9429f")
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/680x.yaml", "2acf654e984428e984b1706de02819fd3d0ea99150e6f65f59f16625f1d63d91")
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6801", "--output", "6801")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	assertDigest("6801.uc", "61bf360b0e0bddb9170594d80735e9f543f4081511afab95a572b270e6f560ca")
	assertDigest("6801.vh", "093bfc8af68b6faafb754ee876ed5724c8a7974604cd89d5694a9a7c29b1cd7e")
	checkOtherProfile("6301", "445163a157db81389aa36da928bde9615943305547283ab64bd47614eafa83db")
	path := os.Getenv("JTROOT") + "/modules/jt680x/hdl/jt680x_ctrl.v"
	assertDigest(path, "86d41459286e9de845a2125af6239558a37b40ae25994d5c5902470d4568a878")
	src, err := os.ReadFile(path)
	if err != nil { panic(err) }
	if err := os.WriteFile("jt680x_ctrl_sim.rtl", src, 0644); err != nil { panic(err) }

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

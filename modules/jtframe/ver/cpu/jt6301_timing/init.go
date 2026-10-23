package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
)

func main() {
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/6301.yaml", "d699f62696058286b28531d08896b921fcf92ee6251a9e3e7085a7f8259260e3")
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/680x.yaml", "257e2b05d3d6ee89137a799d84c0f5587f38dbee98f598ffb4de1f08b95f8e63")
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6301", "--output", "6801")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	assertDigest("6801.uc", "445163a157db81389aa36da928bde9615943305547283ab64bd47614eafa83db")
	assertDigest("6801.vh", "0d788b6687e8cd475fab0fdcaa03a1826e345196280bc239141cb51c66592f94")
	checkOtherProfile("6801", "61bf360b0e0bddb9170594d80735e9f543f4081511afab95a572b270e6f560ca")
	path := os.Getenv("JTROOT") + "/modules/jt680x/hdl/jt680x_ctrl.v"
	assertDigest(path, "2417b42c946155ea0080ebc97c8c12e2f5db3ab6e33c87fd96f6549fd337bbab")
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
	if actual != expected { panic(fmt.Sprintf("6301 profile generation mismatch for %s: got %s", path, actual)) }
}

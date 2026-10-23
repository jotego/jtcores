package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"strings"
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
	src, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	if sum := sha256.Sum256(src); hex.EncodeToString(sum[:]) != "5c6bfeab1f716fc3917d660ef24134d4ecd14e1abfcfe8f2111ab6d72c3befa6" {
		panic("jt680x_ctrl.v changed; re-audit the Icarus declaration-order adapter")
	}
	decl := "wire [4:0] jsr_sel;\nreg  [2:0] iv_sel;\nwire       halt, swi, ni, still;\nreg        nmi_l, pendng;\n"
	includes := "`include \"6801_param.vh\"\n`include \"6801.vh\"\n"
	text := string(src)
	if strings.Count(text, decl) != 1 || strings.Count(text, includes) != 1 {
		panic("jt680x_ctrl.v adapter anchors must each occur exactly once")
	}
	text = strings.Replace(text, decl, "", 1)
	text = strings.Replace(text, includes, decl+includes, 1)
	if strings.Replace(text, decl+includes+"\n", includes+"\n"+decl, 1) != string(src) {
		panic("jt680x_ctrl.v adapter is not a declaration-only relocation")
	}
	if err := os.WriteFile("jt680x_ctrl_sim.rtl", []byte(text), 0644); err != nil {
		panic(err)
	}
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

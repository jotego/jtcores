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
	assertDigest(os.Getenv("JTROOT")+"/modules/jt680x/ucode/6801.yaml", "0f95d0bb1328294389cdc4fe3f26b5192e24753d87577785389053eee4b9429f")
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6801", "--output", "6801")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	assertDigest("6801.uc", "283b2bb595411833d8326a9163226c9384f56deee0db6a7e25aa521a16efe019")
	assertDigest("6801.vh", "093bfc8af68b6faafb754ee876ed5724c8a7974604cd89d5694a9a7c29b1cd7e")
	checkOtherProfile("6301", "980c638131cd1e14ac90ed16a042555f967677d27877481778d372b558f87c68")
	// Icarus rejects the existing ctrl source's implicit-net uses because the
	// generated include precedes declarations. Keep a suite-local equivalent
	// with declarations moved above the includes; control logic remains verbatim.
	path := os.Getenv("JTROOT") + "/modules/jt680x/hdl/jt680x_ctrl.v"
	src, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	text := string(src)
	if sum := sha256.Sum256(src); hex.EncodeToString(sum[:]) != "7f25784b672af47571e4ccf53a211c55b38eed69d479702a575428e9ea11b6fa" {
		panic("jt680x_ctrl.v changed; re-audit the Icarus declaration-order adapter")
	}
	decl := "wire [4:0] jsr_sel;\nreg  [2:0] iv_sel;\nwire       halt, swi, ni, still;\nreg        nmi_l, pendng;\n"
	includes := "`include \"6801_param.vh\"\n`include \"6801.vh\"\n"
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
	if actual != expected { panic(fmt.Sprintf("6801 profile generation mismatch for %s: got %s", path, actual)) }
}

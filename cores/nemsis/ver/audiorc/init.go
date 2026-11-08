package main

import (
	"crypto/sha256"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

func must(ok bool, format string, args ...any) {
	if !ok {
		panic(fmt.Sprintf(format, args...))
	}
}

func main() {
	root, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		panic(err)
	}
	repo := strings.TrimSpace(string(root))
	cmd := exec.Command("jtframe", "mem", "nemsis", "-t", "mist")
	cmd.Dir = repo
	if out, err := cmd.CombinedOutput(); err != nil {
		panic(fmt.Sprintf("jtframe mem failed: %v\n%s", err, out))
	}
	path := filepath.Join(repo, "cores", "nemsis", "mist", "jtnemsis_game_sdram.v")
	data, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	source := string(data)
	hash := sha256.Sum256(data)

	expected := []struct {
		name  string
		width string
	}{
		{"ay7e", "[ 9:0]"}, {"ay8e", "[ 9:0]"}, {"wav1", "[ 7:0]"}, {"wav2", "[ 7:0]"},
	}
	for _, ch := range expected {
		must(regexp.MustCompile(`wire\s+`+regexp.QuoteMeta(ch.width)+`\s+`+ch.name+`\s*;`).MatchString(source),
			"generated width mismatch for %s", ch.name)
	}
	for i, ch := range []string{"ay7e", "ay8e", "wav1", "wav2"} {
		re := regexp.MustCompile(fmt.Sprintf(`\.ch%d\s*\(\s*%s\s*\)`, i, ch))
		must(re.MatchString(source), "generated channel order mismatch: ch%d should be %s", i, ch)
	}
	getPort := func(name string) string {
		re := regexp.MustCompile(`(?s)\.` + name + `\s*\(\s*(.*?)\s*\)\s*,`)
		m := re.FindStringSubmatch(source)
		must(len(m) == 2, "generated %s connection missing", name)
		return strings.TrimSpace(m[1])
	}
	p0, p1, p2, p3 := getPort("p0"), getPort("p1"), getPort("p2"), getPort("p3")
	norm := func(s string) string { return strings.ToLower(strings.Join(strings.Fields(s), "")) }
	p0n := norm(p0)
	must(strings.Contains(p0n, "ay7e_rcen[0]?{15'h7fea,15'h701b}"), "p0 both-cap bank not in generated wrapper: %s", p0)
	must(strings.Contains(p0n, "ay7e_rcen[1]?{15'h00,15'h701b}"), "p0 33nF bank not in generated wrapper: %s", p0)
	must(strings.Contains(p0n, "ay7e_rcen[2]?{15'h7fea,15'h00}"), "p0 C23 bank not in generated wrapper: %s", p0)
	must(norm(p1) == "ay8e_rcen?{15'h00,15'h7fea}:30'h0", "p1 common pole mapping mismatch: %s", p1)
	must(norm(p2) == "wav1_rcen?{15'h00,15'h7fea}:30'h0", "p2 common pole mapping mismatch: %s", p2)
	must(norm(p3) == "wav2_rcen?{15'h00,15'h7fea}:30'h0", "p3 common pole mapping mismatch: %s", p3)
	coeffs := regexp.MustCompile(`15'h([0-9a-fA-F]+)`).FindAllStringSubmatch(p0, -1)
	must(len(coeffs) >= 6, "could not extract AY7E filter coefficients: %s", p0)
	var a33, a47 string
	for _, m := range coeffs {
		if strings.EqualFold(m[1], "701B") {
			a33 = "701B"
		}
		if strings.EqualFold(m[1], "7FEA") {
			a47 = "7FEA"
		}
	}
	must(a33 != "" && a47 != "", "expected generated 33nF/C23 coefficients missing in p0: %s", p0)
	out := fmt.Sprintf("// Extracted from generated wrapper SHA256 %x\nlocalparam [14:0] A33_COEF=15'h%s, A47_COEF=15'h%s;\nassign p0=%s;\nassign p1=%s;\nassign p2=%s;\nassign p3=%s;\n", hash, a33, a47, p0, p1, p2, p3)
	if err := os.WriteFile("generated_audio_coeffs.vh", []byte(out), 0644); err != nil {
		panic(err)
	}
	var lut strings.Builder
	for i := 0; i < 19200; i++ {
		v := int16(math.Round(12000 * math.Sin(2*math.Pi*float64(i)/19200)))
		fmt.Fprintf(&lut, "%04X\n", uint16(v))
	}
	if err := os.WriteFile("sine_10hz.hex", []byte(lut.String()), 0644); err != nil {
		panic(err)
	}
	fmt.Printf("generated audio test coefficients from %s SHA256=%x\n", path, hash)
}

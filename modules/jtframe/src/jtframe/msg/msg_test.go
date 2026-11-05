/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-1-2025 */

package msg

import(
    "fmt"
	"os"
	"path/filepath"
    "strings"
	"testing"
)

func Test_Run(t *testing.T) {

}

func Test_roundup_1k(t *testing.T) {
    var msg Compiler
    msg.data=make(ChData,1)
    const ref=12
    msg.data[0]=ref
    msg.roundup_1k()
    if len(msg.data)!=1024 { t.Errorf("wrong capacity. Got %d entries",len(msg.data))}
    if msg.data[0]!=ref {t.Errorf("wrong content")}
}

func Test_roundup_1k_empty_message(t *testing.T) {
	var msg Compiler
	msg.roundup_1k()
	if len(msg.data) != 1024 {
		t.Fatalf("Empty message must still occupy one page, got %d entries", len(msg.data))
	}
}

func Test_dump_msg_writes_numbered_pages(t *testing.T) {
	dir := t.TempDir()
	original_dir, err := os.Getwd()
	if err != nil { t.Fatal(err) }
	if err = os.Chdir(dir); err != nil { t.Fatal(err) }
	defer os.Chdir(original_dir)

	var msg Compiler
	msg.data = make(ChData, 11*1024)
	for page := 0; page < 11; page++ {
		msg.data[page*1024] = int16(page + 1)
	}
	if err := msg.dump_msg(); err != nil { t.Fatal(err) }
	for page := 0; page < 11; page++ {
		name := filepath.Join(dir, fmt.Sprintf("msg%d.bin", page))
		data, err := os.ReadFile(name)
		if err != nil { t.Fatalf("Missing page %d: %v", page, err) }
		lines := strings.Split(strings.TrimSpace(string(data)), "\n")
		if len(lines) != 1024 { t.Fatalf("Page %d has %d words", page, len(lines)) }
		if lines[0] != fmt.Sprintf("%b", page+1) { t.Fatalf("Page %d starts with %s", page, lines[0]) }
	}
}

func Test_convert_rejects_more_than_16_pages(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	msgpath := filepath.Join(root, "cores", "bigmsg", "cfg", "msg")
	if err := os.MkdirAll(filepath.Dir(msgpath), 0o755); err != nil { t.Fatal(err) }
	if err := os.WriteFile(msgpath, []byte(strings.Repeat("\n", 513)), 0o644); err != nil { t.Fatal(err) }
	output_dir := filepath.Join(root, "build")
	if err := os.MkdirAll(output_dir, 0o755); err != nil { t.Fatal(err) }
	original_dir, err := os.Getwd()
	if err != nil { t.Fatal(err) }
	if err = os.Chdir(output_dir); err != nil { t.Fatal(err) }
	defer os.Chdir(original_dir)

	msg := MakeCompiler("bigmsg")
	if err := msg.Convert(); err == nil || !strings.Contains(err.Error(), "17 pages; maximum is 16") {
		t.Fatalf("Expected a clear 17-page limit error, got %v", err)
	}
}

func Test_compiler_parse_stream(t *testing.T) {
    full_lines(t)
    too_long(t)
    palette(t)
}

func full_lines(t *testing.T) {
    content:=`01234567890123456789012345678912
01234567890123456789012345678912
01234567890123456789012345678912
`
    var msg Compiler
    lines, e := msg.parse_stream( strings.NewReader(content) )
    if e!=nil { t.Error(e) }
    if lines!=4 { t.Errorf("Wrong number of parsed lines. Got %d",lines)}
}

func too_long(t *testing.T) {
    content:=`01234567890123456789012345678912
01234567890123456789012345678912
012345678901234567890123456789123
`
    var msg Compiler
    lines, e := msg.parse_stream( strings.NewReader(content) )
    if e==nil { t.Error("Line too long was not detected") }
    if lines!=3 { t.Errorf("Wrong number of parsed lines. Got %d",lines)}
}

func palette(t *testing.T) {
    content:=`NO COLOR
\RRED
\GGREEN
\BBLUE
WHITE
`
    var msg Compiler
    lines, e := msg.parse_stream( strings.NewReader(content) )
    if e!=nil { t.Error(e) }
    if lines!=6 { t.Errorf("Wrong number of parsed lines. Got %d",lines)}
    expected := []int{3,0,1,2,3}
    show_content:=false
    for line:=0;line<len(expected);line++ {
        pal := expected[line]
        for col:=0; col<32; col++ {
            char := msg.data[line*32+col]
            pal_got := int(char)>>7
            if pal_got!=pal && char!=0 {
                t.Errorf("Palette mismatch at line %d(%d). Got %d (%X), expected %d",
                    line, col, pal_got, char, pal)
                show_content = true
                break
            }
        }
    }
    if show_content {
        t.Log(content)
        t.Logf("Message lines %d\n",len(msg.data)/32)
        t.Logf("Parsed content:\n%s",show_hex(msg.data))
    }
}

func show_hex(d ChData) string {
    var sb strings.Builder
    for k, v := range d {
        sb.WriteString(fmt.Sprintf("%03X ",v))
        if k%16==15 {
            if k%32==31 {
                sb.WriteString(" (line end)\n")
            }
            sb.WriteString("\n")
        }
    }
    return sb.String()
}

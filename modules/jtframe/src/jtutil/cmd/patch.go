/*  This file is part of JTCORES.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 26-3-2026 */

package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/spf13/cobra"
	"jotego/jtframe/macros"
	"jotego/jtframe/mra"
)

type rom_patch struct {
	offset int
	data   []byte
}

type patch_args struct {
	hack, setname, name, rom_path string
}

var patchArgs patch_args

var patchCmd = &cobra.Command{
	Use:   "patch <core-name>",
	Short: "Generate TOML patches from a hacked .rom file",
	Long:  man_blurb("jtutil-patch", "Generate TOML patches from a hacked .rom file."),
	Args:  cobra.ExactArgs(1),
	Run:   run_patch,
}

func init() {
	rootCmd.AddCommand(patchCmd)
	mame_roms := filepath.Join(os.Getenv("HOME"), ".mame", "roms")
	patchCmd.Flags().StringVar(&patchArgs.hack, "hack", "", "Path to the hacked .rom file")
	patchCmd.Flags().StringVar(&patchArgs.setname, "setname", "", "MRA setname to patch")
	patchCmd.Flags().StringVar(&patchArgs.name, "name", "", "Altversion name to store in TOML")
	patchCmd.Flags().StringVar(&patchArgs.rom_path, "path", mame_roms, "Path to MAME .zip files")
	must(patchCmd.MarkFlagRequired("hack"))
	must(patchCmd.MarkFlagRequired("setname"))
	must(patchCmd.MarkFlagRequired("name"))
}

func run_patch(cmd *cobra.Command, args []string) {
	core := args[0]
	patches, e := make_patch_data(core)
	must(e)
	e = update_toml_file(core, patches)
	must(e)
}

func make_patch_data(core string) ([]rom_patch, error) {
	base_rom, e := create_base_rom(core)
	if e != nil {
		return nil, e
	}
	hacked_rom, e := os.ReadFile(patchArgs.hack)
	if e != nil {
		return nil, e
	}
	return build_patches(base_rom, hacked_rom)
}

func create_base_rom(core string) ([]byte, error) {
	cmd := exec.Command("jtframe", "mra", core, "--path", patchArgs.rom_path)
	output, e := cmd.CombinedOutput()
	if e != nil {
		return nil, fmt.Errorf("jtframe mra failed: %w\n%s", e, string(output))
	}
	rom_path := filepath.Join(os.Getenv("JTROOT"), "rom", patchArgs.setname+".rom")
	base_rom, e := os.ReadFile(rom_path)
	if e != nil {
		return nil, e
	}
	return base_rom, nil
}

func update_toml_file(core string, patches []rom_patch) error {
	toml_path := mra.TomlPath(core)
	toml_data, e := os.ReadFile(toml_path)
	if e != nil {
		return e
	}
	updated, e := replace_altversion_patches(string(toml_data), patchArgs.setname, patchArgs.name, patches)
	if e != nil {
		return e
	}
	return os.WriteFile(toml_path, []byte(updated), 0664)
}

func build_patches(base_rom, hacked_rom []byte) ([]rom_patch, error) {
	if len(base_rom) != len(hacked_rom) {
		return nil, fmt.Errorf("base and hacked ROM files have different lengths (%d != %d)", len(base_rom), len(hacked_rom))
	}
	header_len := macros.GetInt("JTFRAME_HEADER")
	patches := make([]rom_patch, 0, 32)
	for k := 0; k < len(base_rom); {
		if base_rom[k] == hacked_rom[k] {
			k++
			continue
		}
		if k < header_len {
			return nil, fmt.Errorf("cannot generate TOML patches inside JTFRAME_HEADER (%d bytes)", header_len)
		}
		start := k
		data := make([]byte, 0, 32)
		for ; k < len(base_rom) && base_rom[k] != hacked_rom[k]; k++ {
			data = append(data, hacked_rom[k])
		}
		patches = append(patches, rom_patch{offset: start - header_len, data: data})
	}
	return patches, nil
}

func replace_altversion_patches(toml_data, setname, altversion string, patches []rom_patch) (string, error) {
	rom_start, rom_end, e := find_rom_section(toml_data)
	if e != nil {
		return "", e
	}
	rom_section := toml_data[rom_start:rom_end]
	patch_start, patch_end, found, e := find_patches_block(rom_section)
	if e != nil {
		return "", e
	}
	generated := format_patches_block(setname, altversion, patches)
	if !found {
		rom_prefix := strings.TrimRight(rom_section, "\n\t ")
		tail := rom_section[len(rom_prefix):]
		if !strings.HasSuffix(rom_prefix, "\n") {
			generated = "\n" + generated
		}
		return toml_data[:rom_start] + rom_prefix + generated + tail + toml_data[rom_end:], nil
	}
	existing := rom_section[patch_start:patch_end]
	replaced, e := replace_patch_entries(existing, altversion, patches, setname)
	if e != nil {
		return "", e
	}
	return toml_data[:rom_start] + rom_section[:patch_start] + replaced + rom_section[patch_end:] + toml_data[rom_end:], nil
}

func find_rom_section(toml_data string) (int, int, error) {
	re := regexp.MustCompile(`(?m)^\[ROM\]\s*$`)
	loc := re.FindStringIndex(toml_data)
	if loc == nil {
		return 0, 0, fmt.Errorf("cannot find [ROM] section in TOML file")
	}
	next_re := regexp.MustCompile(`(?m)^\[[^\]]+\]\s*$`)
	next_loc := next_re.FindStringIndex(toml_data[loc[1]:])
	if next_loc == nil {
		return loc[0], len(toml_data), nil
	}
	return loc[0], loc[1] + next_loc[0], nil
}

func find_patches_block(rom_section string) (int, int, bool, error) {
	idx := find_token_outside_text(rom_section, "patches")
	if idx < 0 {
		return 0, 0, false, nil
	}
	eq := strings.Index(rom_section[idx:], "=")
	if eq < 0 {
		return 0, 0, false, fmt.Errorf("patches array is missing '='")
	}
	eq += idx
	bracket := strings.Index(rom_section[eq:], "[")
	if bracket < 0 {
		return 0, 0, false, fmt.Errorf("patches array is missing '['")
	}
	bracket += eq
	end, e := find_matching_square(rom_section, bracket)
	if e != nil {
		return 0, 0, false, e
	}
	line_start := strings.LastIndex(rom_section[:idx], "\n") + 1
	line_end := end + 1
	if line_end < len(rom_section) && rom_section[line_end] == '\n' {
		line_end++
	}
	return line_start, line_end, true, nil
}

func replace_patch_entries(existing_block, altversion string, patches []rom_patch, setname string) (string, error) {
	open := strings.Index(existing_block, "[")
	close, e := find_matching_square(existing_block, open)
	if e != nil {
		return "", e
	}
	prefix := existing_block[:open+1]
	content := existing_block[open+1 : close]
	suffix := existing_block[close:]
	items := extract_inline_tables(content)
	kept := make([]string, 0, len(items))
	for _, each := range items {
		if patch_altversion(each) == altversion {
			continue
		}
		kept = append(kept, strings.TrimSpace(each))
	}
	for _, each := range format_patch_entries(setname, altversion, patches) {
		kept = append(kept, each)
	}
	var body strings.Builder
	if len(kept) > 0 {
		body.WriteString("\n")
		for _, each := range kept {
			body.WriteString("    ")
			body.WriteString(each)
			body.WriteString(",\n")
		}
	}
	return prefix + body.String() + suffix, nil
}

func extract_inline_tables(content string) []string {
	items := make([]string, 0, 16)
	start := -1
	depth := 0
	in_string := false
	triple := false
	escaped := false
	for i := 0; i < len(content); i++ {
		if in_string {
			if escaped {
				escaped = false
				continue
			}
			if triple {
				if i+2 < len(content) && content[i:i+3] == `"""` {
					in_string = false
					triple = false
					i += 2
				}
				continue
			}
			if content[i] == '\\' {
				escaped = true
				continue
			}
			if content[i] == '"' {
				in_string = false
			}
			continue
		}
		if content[i] == '#' {
			for ; i < len(content) && content[i] != '\n'; i++ {
			}
			continue
		}
		if content[i] == '"' {
			in_string = true
			triple = i+2 < len(content) && content[i:i+3] == `"""`
			if triple {
				i += 2
			}
			continue
		}
		switch content[i] {
		case '{':
			if depth == 0 {
				start = i
			}
			depth++
		case '}':
			if depth == 0 {
				continue
			}
			depth--
			if depth == 0 && start >= 0 {
				items = append(items, content[start:i+1])
				start = -1
			}
		}
	}
	return items
}

func patch_altversion(entry string) string {
	re := regexp.MustCompile(`altversion\s*=\s*"([^"]*)"`)
	match := re.FindStringSubmatch(entry)
	if len(match) != 2 {
		return ""
	}
	return match[1]
}

func format_patches_block(setname, altversion string, patches []rom_patch) string {
	var body strings.Builder
	body.WriteString("patches = [")
	entries := format_patch_entries(setname, altversion, patches)
	if len(entries) == 0 {
		body.WriteString("]\n")
		return body.String()
	}
	body.WriteString("\n")
	for _, each := range entries {
		body.WriteString("    ")
		body.WriteString(each)
		body.WriteString(",\n")
	}
	body.WriteString("]\n")
	return body.String()
}

func format_patch_entries(setname, altversion string, patches []rom_patch) []string {
	entries := make([]string, 0, len(patches))
	for _, each := range patches {
		entries = append(entries, fmt.Sprintf("{ altversion=%q, setname=%q, offset=0x%X, data=%s }",
			altversion,
			setname,
			each.offset,
			format_patch_data(each.data)))
	}
	return entries
}

func format_patch_data(data []byte) string {
	if len(data) == 0 {
		return `""`
	}
	var body strings.Builder
	for k, each := range data {
		if k != 0 {
			if (k & 15) == 0 {
				body.WriteString("\n")
			} else {
				body.WriteString(" ")
			}
		}
		body.WriteString(fmt.Sprintf("%02X", each))
	}
	if strings.IndexByte(body.String(), '\n') == -1 {
		return fmt.Sprintf("%q", body.String())
	}
	return fmt.Sprintf("\"\"\"\\\n%s\"\"\"", body.String())
}

func find_token_outside_text(text, token string) int {
	in_string := false
	triple := false
	escaped := false
	for i := 0; i < len(text); i++ {
		if in_string {
			if escaped {
				escaped = false
				continue
			}
			if triple {
				if i+2 < len(text) && text[i:i+3] == `"""` {
					in_string = false
					triple = false
					i += 2
				}
				continue
			}
			if text[i] == '\\' {
				escaped = true
				continue
			}
			if text[i] == '"' {
				in_string = false
			}
			continue
		}
		if text[i] == '#' {
			for ; i < len(text) && text[i] != '\n'; i++ {
			}
			continue
		}
		if text[i] == '"' {
			in_string = true
			triple = i+2 < len(text) && text[i:i+3] == `"""`
			if triple {
				i += 2
			}
			continue
		}
		if strings.HasPrefix(text[i:], token) {
			return i
		}
	}
	return -1
}

func find_matching_square(text string, start int) (int, error) {
	depth := 0
	in_string := false
	triple := false
	escaped := false
	for i := start; i < len(text); i++ {
		if in_string {
			if escaped {
				escaped = false
				continue
			}
			if triple {
				if i+2 < len(text) && text[i:i+3] == `"""` {
					in_string = false
					triple = false
					i += 2
				}
				continue
			}
			if text[i] == '\\' {
				escaped = true
				continue
			}
			if text[i] == '"' {
				in_string = false
			}
			continue
		}
		if text[i] == '#' {
			for ; i < len(text) && text[i] != '\n'; i++ {
			}
			continue
		}
		if text[i] == '"' {
			in_string = true
			triple = i+2 < len(text) && text[i:i+3] == `"""`
			if triple {
				i += 2
			}
			continue
		}
		switch text[i] {
		case '[':
			depth++
		case ']':
			depth--
			if depth == 0 {
				return i, nil
			}
		}
	}
	return -1, fmt.Errorf("cannot find the end of the patches array")
}

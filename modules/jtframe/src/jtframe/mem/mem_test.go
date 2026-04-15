/*  This file is part of JTFRAME.
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
    Date: 4-1-2025 */

package mem

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"
	"text/template"

	"jotego/jtframe/macros"

	"github.com/Masterminds/sprig/v3"
	"gopkg.in/yaml.v2"
)

func TestDelete_optional_IOCTL(t *testing.T) {
	cfg := MemConfig{
		BRAM: []BRAMBus{
			BRAMBus{
				Name: "onlydebug",
				Ioctl: BRAMBus_Ioctl{
					Order:   0,
					Restore: true,
					Unless:  []string{"JTFRAME_RELEASE"},
				},
			},
			BRAMBus{
				Name: "onlyrelease",
				Ioctl: BRAMBus_Ioctl{
					Order:   0,
					Restore: true,
					When:    []string{"JTFRAME_RELEASE"},
				},
			},
			BRAMBus{
				Name: "onlypocket",
				Ioctl: BRAMBus_Ioctl{
					Order:   1,
					Restore: true,
					When:    []string{"POCKET"},
				},
			},
		},
	}
	copy, e := json.Marshal(cfg)
	if e != nil {
		t.Error(e)
		return
	}
	macros_debug_pocket := map[string]string{
		"POCKET": "",
	}
	macros.MakeFromMap(macros_debug_pocket)
	delete_optional_ioctl(cfg.BRAM)
	if count_ioctl_buses(cfg.BRAM, t) != 2 {
		show_ioctl(cfg.BRAM, t)
		t.Error("Expected only entries for POCKET and debug")
	}

	macros_release_mister := map[string]string{
		"MISTER":          "",
		"JTFRAME_RELEASE": "",
	}

	// restores the test data
	if e := json.Unmarshal(copy, &cfg); e != nil {
		t.Error(e)
		return
	}
	macros.MakeFromMap(macros_release_mister)
	delete_optional_ioctl(cfg.BRAM)
	if count := count_ioctl_buses(cfg.BRAM, t); count != 1 {
		t.Logf("Found %d IOCTL buses.\nDump", count)
		show_ioctl(cfg.BRAM, t)
		t.Error("Expected only the entry for MiSTer")
	}
}

func count_ioctl_buses(bram_buses []BRAMBus, t *testing.T) int {
	total := 0
	for _, bus := range bram_buses {
		if bus.Ioctl.Save || bus.Ioctl.Restore || bus.Ioctl.Order > 0 {
			t.Log(bus.Name)
			total++
		}
	}
	return total
}

func show_ioctl(bram_buses []BRAMBus, t *testing.T) {
	for _, bus := range bram_buses {
		t.Log(bus.Name)
		t.Log(bus.Ioctl)
	}
}

func Test_BRAMBus_When_Unless(t *testing.T) {
	sample := `name: sample_BRAM
when: [ WHEN_MACRO ]
unless: [ UNLESS_MACRO ]
rw: true
`
	var bram BRAMBus
	if e := yaml.Unmarshal([]byte(sample), &bram); e != nil {
		t.Error(e)
	}
	if bram.Name != "sample_BRAM" {
		t.Errorf("Bad name: %s", bram.Name)
	}
	if slices.Compare(bram.When, []string{"WHEN_MACRO"}) != 0 {
		t.Errorf("Bad 'when' field: %s", bram.When)
	}
	if slices.Compare(bram.Unless, []string{"UNLESS_MACRO"}) != 0 {
		t.Errorf("Bad 'unless' field: %s", bram.Unless)
	}
	if !bram.Rw {
		t.Errorf("Bad RW (should be true)")
	}
	macros.MakeFromMap(map[string]string{"WHEN_MACRO": ""})
	if !bram.Enabled() {
		t.Errorf("Should have been enabled")
	}

	macros.MakeFromMap(map[string]string{"xx": ""})
	if bram.Enabled() {
		t.Errorf("Should have been disabled")
	}

	macros.MakeFromMap(nil)
	if bram.Enabled() {
		t.Errorf("Should have been disabled")
	}
}

func Test_BRAMBus_Size_To_AddrWidth(t *testing.T) {
	sample := `bram:
  - { name: plain_bytes, size: 1024 }
  - { name: bytes_suffix, size: 1024B }
  - { name: kilobytes_suffix, size: 1kB }
  - { name: kilobytes_no_b, size: 1k }
  - { name: kilobytes_spaced, size: "1 kB" }
  - { name: kilobytes_spaced_no_b, size: "1 k" }
  - { name: max_size, size: 512kB }
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Fatal(e)
	}
	if e := cfg.normalize_bram(); e != nil {
		t.Fatal(e)
	}

	expected := map[string]int{
		"plain_bytes":           10,
		"bytes_suffix":          10,
		"kilobytes_suffix":      10,
		"kilobytes_no_b":        10,
		"kilobytes_spaced":      10,
		"kilobytes_spaced_no_b": 10,
		"max_size":              19,
	}
	for _, bram := range cfg.BRAM {
		if bram.Addr_width != expected[bram.Name] {
			t.Errorf("Wrong addr_width for %s. Got %d, wanted %d",
				bram.Name, bram.Addr_width, expected[bram.Name])
		}
	}
}

func Test_parse_memory_size(t *testing.T) {
	cases := map[string]int{
		"1024": 1024,
		"1k":   1024,
		"1kB":  1024,
		"1 kB": 1024,
		"1MB":  1024 * 1024,
		"8 MB": 8 * 1024 * 1024,
	}
	for raw, expected := range cases {
		got, err := parse_memory_size(raw)
		if err != nil {
			t.Fatalf("Unexpected error for %s: %v", raw, err)
		}
		if got != expected {
			t.Fatalf("Wrong size for %s. Got %d, wanted %d", raw, got, expected)
		}
	}
}

func Test_BRAMBus_Size_Rejections(t *testing.T) {
	cases := []string{
		`bram: [ { name: mixed, addr_width: 10, size: 1kB } ]`,
		`bram: [ { name: not_power_of_two, size: 3kB } ]`,
		`bram: [ { name: too_large, size: 1024kB } ]`,
		`bram: [ { name: bad_suffix, size: 1KB } ]`,
		`bram: [ { name: bad_suffix_lower, size: 1kb } ]`,
		`bram: [ { name: bad_suffix_spaced, size: "1 KB" } ]`,
		`bram: [ { name: bad_suffix_spaced_lower, size: "1 kb" } ]`,
	}

	for _, sample := range cases {
		var cfg MemConfig
		if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
			t.Errorf("Unexpected YAML error for %s: %v", sample, e)
			continue
		}
		if e := cfg.normalize_bram(); e == nil {
			t.Errorf("Expected size validation to fail for %s", sample)
		}
	}
}

func Test_BRAMBus_SimBigEndian_Unmarshal(t *testing.T) {
	sample := `bram:
  - { name: default_little, size: 1kB }
  - { name: explicit_big, size: 1kB, sim_big_endian: true }
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Fatal(e)
	}
	if cfg.BRAM[0].Sim_big_endian {
		t.Fatalf("Expected sim_big_endian to default to false")
	}
	if !cfg.BRAM[1].Sim_big_endian {
		t.Fatalf("Expected sim_big_endian to unmarshal as true")
	}
}

func Test_BRAMBus_SimBigEndian_Validation(t *testing.T) {
	cfg := MemConfig{
		BRAM: []BRAMBus{
			{
				Name:           "bytes",
				Data_width:     8,
				Sim_big_endian: true,
			},
			{
				Name:           "words",
				Data_width:     16,
				Sim_big_endian: true,
			},
			{
				Name:           "longs",
				Data_width:     32,
				Sim_big_endian: true,
			},
		},
	}
	if e := cfg.normalize_bram(); e == nil {
		t.Fatalf("Expected 8-bit big-endian BRAM to be rejected")
	}

	cfg.BRAM = cfg.BRAM[1:]
	if e := cfg.normalize_bram(); e != nil {
		t.Fatalf("Expected 16-bit and 32-bit big-endian BRAMs to be accepted: %v", e)
	}
}

func Test_fill_implicit_ports_expands_32bit_bram_write_enable(t *testing.T) {
	cfg := MemConfig{
		BRAM: []BRAMBus{
			{
				Name:       "fb",
				Addr_width: 11,
				Data_width: 32,
				Rw:         true,
				Dual_port: struct {
					Name     string `yaml:"name"`
					Addr     string `yaml:"addr"`
					Din      string `yaml:"din"`
					Dout     string `yaml:"dout"`
					Rw       bool   `yaml:"rw"`
					We       string `yaml:"we"`
					AddrFull string
				}{
					Name: "video",
					Rw:   true,
					We:   "video_we",
				},
			},
		},
	}

	fill_implicit_ports(&cfg)

	ports := map[string]Port{}
	for _, each := range cfg.Ports {
		ports[each.Name] = each
	}

	if got := ports["fb_we"].MSB; got != 3 {
		t.Fatalf("fb_we width mismatch. Got MSB %d, wanted 3", got)
	}
	if got := ports["video_we"].MSB; got != 3 {
		t.Fatalf("video_we width mismatch. Got MSB %d, wanted 3", got)
	}
	if got := ports["fb_addr"].LSB; got != 2 {
		t.Fatalf("fb_addr LSB mismatch. Got %d, wanted 2", got)
	}
	if got := ports["video_addr"].LSB; got != 2 {
		t.Fatalf("video_addr LSB mismatch. Got %d, wanted 2", got)
	}
	if got := cfg.BRAM[0].Dual_port.AddrFull; got != "video_addr[10:2]" {
		t.Fatalf("unexpected dual-port address expansion: %s", got)
	}
}

func Test_make_ioctl_restore_uses_32bit_write_enable_width(t *testing.T) {
	cfg := MemConfig{
		BRAM: []BRAMBus{
			{
				Name:       "fb",
				Addr_width: 11,
				Data_width: 32,
				Rw:         true,
				Ioctl: BRAMBus_Ioctl{
					Save:    true,
					Restore: true,
					Order:   0,
				},
			},
		},
	}

	fill_implicit_ports(&cfg)
	make_ioctl(&cfg)

	if got := cfg.Ioctl.Buses[0].We; got != "fb_we" {
		t.Fatalf("wrong IOCTL restore write-enable source. Got %s, wanted fb_we", got)
	}
	if got := cfg.BRAM[0].We; got != "fb_wemx" {
		t.Fatalf("wrong BRAM restore mux write-enable. Got %s", got)
	}
}

func Test_SDRAMCacheLine_Unmarshal(t *testing.T) {
	sample := `sdram:
  big_endian: true
  cache-lines:
    - name: tiles
      cache: { blocks: 32, size: 1kB, data_width: 32 }
      at:    { bank: 3, offset: CHAR, length: 8MB }
      simfile: tilechar.bin
      sim_big_endian: true
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Fatal(e)
	}
	if len(cfg.SDRAM.Cache_lines) != 1 {
		t.Fatalf("Wrong cache-line count. Got %d, wanted 1", len(cfg.SDRAM.Cache_lines))
	}
	if !cfg.SDRAM.Big_endian {
		t.Fatal("Expected sdram.big_endian to unmarshal as true")
	}
	line := cfg.SDRAM.Cache_lines[0]
	if line.Name != "tiles" {
		t.Fatalf("Wrong cache-line name. Got %s", line.Name)
	}
	if line.At.Offset != "CHAR" {
		t.Fatalf("Wrong cache-line offset. Got %s", line.At.Offset)
	}
	if line.Simfile != "tilechar.bin" {
		t.Fatalf("Wrong cache-line simfile. Got %s", line.Simfile)
	}
	if !line.Sim_big_endian {
		t.Fatalf("Expected cache-line sim_big_endian to unmarshal as true")
	}
}

func Test_SDRAMCacheLine_Unmarshal_RejectsStart(t *testing.T) {
	sample := `sdram:
  cache-lines:
    - name: tiles
      cache: { blocks: 32, size: 1kB, data_width: 32 }
      at:    { bank: 3, start: CHAR, length: 8MB }
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e == nil {
		t.Fatal("Expected cache-line start field to be rejected")
	}
}

func Test_SDRAMBus_Simfile_Unmarshal(t *testing.T) {
	sample := `sdram:
  banks:
    - buses:
        - name: tiles
          addr_width: 12
          data_width: 16
          simfile: tiles.bin
          sim_big_endian: true
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Fatal(e)
	}
	if got := cfg.SDRAM.Banks[0].Buses[0].Simfile; got != "tiles.bin" {
		t.Fatalf("Wrong bus simfile. Got %s", got)
	}
	if !cfg.SDRAM.Banks[0].Buses[0].Sim_big_endian {
		t.Fatalf("Expected bus sim_big_endian to unmarshal as true")
	}
}

func Test_check_sdram_cache_lines(t *testing.T) {
	cfg := MemConfig{
		Params: []Param{{Name: "CHAR", Value: "22'h100"}},
		SDRAM: SDRAMCfg{
			Cache_lines: []SDRAMCacheLine{
				{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     32,
						Size:       "1kB",
						Data_width: 32,
					},
					At: SDRAMCacheAddr{
						Bank:   3,
						Offset: "CHAR",
						Length: "8MB",
					},
				},
				{
					Name: "pal",
					Cache: SDRAMCacheCfg{
						Blocks:     8,
						Size:       "512B",
						Data_width: 16,
					},
					At: SDRAMCacheAddr{
						Length: "256kB",
					},
				},
			},
		},
	}
	macros.MakeFromMap(map[string]string{"JTFRAME_SDRAM_LARGE": ""})
	if e := cfg.check_sdram(); e != nil {
		t.Fatal(e)
	}
	if cfg.SDRAM.Burst_len != 1024 {
		t.Fatalf("Wrong burst length. Got %d, wanted 1024", cfg.SDRAM.Burst_len)
	}
	if cfg.SDRAM.Burst != "1kB" {
		t.Fatalf("Wrong default burst. Got %s, wanted 1kB", cfg.SDRAM.Burst)
	}
	if cfg.SDRAM.Cache_lines[0].Total != 32*1024 {
		t.Fatalf("Wrong total cache size. Got %d", cfg.SDRAM.Cache_lines[0].Total)
	}
}

func Test_check_sdram_cache_lines_accepts_exact_bank_end(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Cache_lines: []SDRAMCacheLine{{
				Name: "tiles",
				Cache: SDRAMCacheCfg{
					Blocks:     1,
					Size:       "512B",
					Data_width: 32,
				},
				At: SDRAMCacheAddr{
					Offset: "0x3FF000",
					Length: "8kB",
				},
			}},
		},
	}
	macros.MakeFromMap(nil)
	if e := cfg.check_sdram(); e != nil {
		t.Fatal(e)
	}
}

func Test_check_sdram_cache_lines_rejects_bank_overflow(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Cache_lines: []SDRAMCacheLine{{
				Name: "tiles",
				Cache: SDRAMCacheCfg{
					Blocks:     1,
					Size:       "512B",
					Data_width: 32,
				},
				At: SDRAMCacheAddr{
					Offset: "0x3FF000",
					Length: "16kB",
				},
			}},
		},
	}
	macros.MakeFromMap(nil)
	if e := cfg.check_sdram(); e == nil {
		t.Fatal("Expected cache-line bank overflow to fail")
	}
}

func Test_check_sdram_cache_lines_accepts_large_bank_overflow_case(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Cache_lines: []SDRAMCacheLine{{
				Name: "tiles",
				Cache: SDRAMCacheCfg{
					Blocks:     1,
					Size:       "512B",
					Data_width: 32,
				},
				At: SDRAMCacheAddr{
					Offset: "0x3FF000",
					Length: "16kB",
				},
			}},
		},
	}
	macros.MakeFromMap(map[string]string{"JTFRAME_SDRAM_LARGE": ""})
	if e := cfg.check_sdram(); e != nil {
		t.Fatal(e)
	}
}

func Test_check_sdram_cache_lines_rejects(t *testing.T) {
	cases := []MemConfig{
		{
			SDRAM: SDRAMCfg{
				Banks:       []SDRAMBank{{}},
				Cache_lines: []SDRAMCacheLine{{Name: "tiles"}},
			},
		},
		{
			SDRAM: SDRAMCfg{
				Cache_lines: []SDRAMCacheLine{{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     0,
						Size:       "1kB",
						Data_width: 32,
					},
					At: SDRAMCacheAddr{Length: "8MB"},
				}},
			},
		},
		{
			SDRAM: SDRAMCfg{
				Cache_lines: []SDRAMCacheLine{{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     1,
						Size:       "1kB",
						Data_width: 24,
					},
					At: SDRAMCacheAddr{Length: "8MB"},
				}},
			},
		},
		{
			SDRAM: SDRAMCfg{
				Cache_lines: []SDRAMCacheLine{{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     1,
						Size:       "1kB",
						Data_width: 16,
					},
					At: SDRAMCacheAddr{
						Offset: "UNKNOWN",
						Length: "8MB",
					},
				}},
			},
		},
		{
			SDRAM: SDRAMCfg{
				Cache_lines: []SDRAMCacheLine{{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     1,
						Size:       "1kB",
						Data_width: 8,
					},
					At:             SDRAMCacheAddr{Length: "8MB"},
					Sim_big_endian: true,
				}},
			},
		},
	}
	for _, cfg := range cases {
		macros.MakeFromMap(nil)
		if e := cfg.check_sdram(); e == nil {
			t.Fatal("Expected cache-line validation to fail")
		}
	}
}

func Test_check_sdram_rejects_empty_definition(t *testing.T) {
	cfg := MemConfig{}
	macros.MakeFromMap(nil)
	if e := cfg.check_sdram(); e == nil {
		t.Fatal("Expected empty SDRAM definition to fail")
	}
}

func Test_check_sdram_rejects_8bit_big_endian_bank_simfile(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Banks: []SDRAMBank{{
				Buses: []SDRAMBus{{
					Name:           "tiles",
					Data_width:     8,
					Sim_big_endian: true,
				}},
			}},
		},
	}
	if e := cfg.check_sdram(); e == nil {
		t.Fatal("Expected 8-bit bank sim_big_endian to fail")
	}
}

func Test_check_sdram_rejects_bank_big_endian(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Big_endian: true,
			Banks: []SDRAMBank{{
				Buses: []SDRAMBus{{
					Name:       "tiles",
					Data_width: 16,
					Addr_width: 12,
				}},
			}},
		},
	}
	if e := cfg.check_sdram(); e == nil {
		t.Fatal("Expected sdram.big_endian with bank SDRAM to fail")
	}
}

func Test_check_sdram_cache_lines_accepts_hex_offset(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Cache_lines: []SDRAMCacheLine{
				{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     1,
						Size:       "512B",
						Data_width: 16,
					},
					At: SDRAMCacheAddr{
						Offset: "0x100",
						Length: "256kB",
					},
				},
			},
		},
	}
	macros.MakeFromMap(nil)
	if e := cfg.check_sdram(); e != nil {
		t.Fatal(e)
	}
}

func Test_check_sdram_cache_lines_rejects_decimal_offset(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Cache_lines: []SDRAMCacheLine{
				{
					Name: "tiles",
					Cache: SDRAMCacheCfg{
						Blocks:     1,
						Size:       "512B",
						Data_width: 16,
					},
					At: SDRAMCacheAddr{
						Offset: "256",
						Length: "256kB",
					},
				},
			},
		},
	}
	macros.MakeFromMap(nil)
	if e := cfg.check_sdram(); e == nil {
		t.Fatal("Expected decimal cache-line offset to fail")
	}
}

func Test_ParseFile_Converts_BRAM_Size(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)

	cfgDir := filepath.Join(root, "cores", "sizeparse", "cfg")
	if e := os.MkdirAll(cfgDir, 0o755); e != nil {
		t.Fatal(e)
	}

	memPath := filepath.Join(cfgDir, "mem.yaml")
	memYaml := `bram:
  - { name: spaced_kilo, size: "1 kB" }
  - { name: plain_kilo, size: "1k" }
`
	if e := os.WriteFile(memPath, []byte(memYaml), 0o644); e != nil {
		t.Fatal(e)
	}

	var cfg MemConfig
	if e := ParseFile("sizeparse", "mem.yaml", &cfg); e != nil {
		t.Fatal(e)
	}

	if len(cfg.BRAM) != 2 {
		t.Fatalf("Wrong BRAM count. Got %d, wanted 2", len(cfg.BRAM))
	}
	for _, bram := range cfg.BRAM {
		if bram.Addr_width != 10 {
			t.Errorf("Wrong addr_width for %s. Got %d, wanted 10", bram.Name, bram.Addr_width)
		}
	}
}

func Test_delete_optional_bram(t *testing.T) {
	sample := `bram:
  - {name: always }
  - {name: not_pocket, unless: [ POCKET ] }
  - {name: only_pocket, when: [ POCKET ] }
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Error(e)
		return
	}
	macros.MakeFromMap(map[string]string{"POCKET": ""})
	delete_optional_bram(&cfg)
	var always, not_pocket, only_pocket bool
	for _, bram := range cfg.BRAM {
		switch bram.Name {
		case "always":
			always = true
		case "not_pocket":
			not_pocket = true
		case "only_pocket":
			only_pocket = true
		}
	}
	if total := len(cfg.BRAM); total != 2 {
		t.Errorf("Expecting 2 elements, found %d", total)
	}
	if !always {
		t.Error("Missing 'always'")
	}
	if not_pocket {
		t.Error("'not_pocket' should not appear")
	}
	if !only_pocket {
		t.Error("missing 'only_pocket")
	}
}

func Test_delete_optional_sdram(t *testing.T) {
	sample := `sdram:
  banks:
    - buses:
      - {name: always }
      - {name: not_pocket, unless: [ POCKET ] }
      - {name: only_pocket, when: [ POCKET ] }
    - buses:
      - {name: always }
      - {name: not_pocket, unless: [ POCKET ] }
      - {name: only_pocket, when: [ POCKET ] }
    - buses:
      - {name: not_pocket1, unless: [ POCKET ] }
      - {name: not_pocket2, unless: [ POCKET ] }
      - {name: not_pocket3, unless: [ POCKET ] }
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Error(e)
		return
	}
	if len(cfg.SDRAM.Banks) != 3 {
		t.Errorf("Expecting 3 SDRAM banks")
		return
	}
	for k := 0; k < 3; k++ {
		if total := len(cfg.SDRAM.Banks[k].Buses); total != 3 {
			t.Errorf("Expecting 3 SDRAM buses at bank %d. Found %d", k, total)
			return
		}
	}

	macros.MakeFromMap(map[string]string{"POCKET": ""})
	delete_optional_sdram(&cfg)

	if len(cfg.SDRAM.Banks) != 3 {
		t.Errorf("Expecting 3 SDRAM banks")
		return
	}
	for k := 0; k < 2; k++ {
		if total := len(cfg.SDRAM.Banks[k].Buses); total != 2 {
			t.Errorf("Expecting 2 SDRAM buses at bank %d. Found %d", k, total)
			return
		}
	}
	if len(cfg.SDRAM.Banks[2].Buses) != 0 {
		t.Errorf("Bank 2 should be empty")
	}

	var always, not_pocket, only_pocket bool
	for k := 0; k < 2; k++ {
		for _, bus := range cfg.SDRAM.Banks[k].Buses {
			t.Logf("bank[%d]: %s", k, bus.Name)
			switch bus.Name {
			case "always":
				always = true
			case "not_pocket":
				not_pocket = true
			case "only_pocket":
				only_pocket = true
			}
		}
		if !always {
			t.Errorf("Missing 'always' at bank %d", k)
		}
		if not_pocket {
			t.Errorf("'not_pocket' should not appear at bank %d", k)
		}
		if !only_pocket {
			t.Errorf("missing 'only_pocket at bank %d", k)
		}
	}
}

func Test_empty_bank(t *testing.T) {
	mem_yaml := `
sdram:
  banks:
    -
    - buses:
        - name: cart0
`
	var cfg MemConfig
	e := unmarshal([]byte(mem_yaml), &cfg)
	if e != nil {
		t.Error(e)
		return
	}
	if total := len(cfg.SDRAM.Banks); total != 2 {
		t.Errorf("Expecting 2 banks, got %d", total)
		return
	}
	if total := len(cfg.SDRAM.Banks[1].Buses); total != 1 {
		t.Errorf("Expecting 2 buses on bank 1, got %d", total)
		return
	}
	if cfg.SDRAM.Banks[1].Buses[0].Name != "cart0" {
		t.Error("Bus 0 of Bank 1 is not named cart0")
	}
}

const BRAM_YAML = `
bram:
  - name: pal
    addr_width: 8
    data_width: 8
    prom: true
  - name: pal1
    addr_width: 9
    data_width: 8
    prom: true
  - name: pal2
    addr_width: 5
    data_width: 8
    prom: true
  - name: pal3
    addr_width: 6
    data_width: 4
    prom: true
`

func Test_prom_start(t *testing.T) {
	var cfg MemConfig
	e := unmarshal([]byte(BRAM_YAML), &cfg)
	if e != nil {
		t.Error(e)
		return
	}
	cfg.calc_prom_we()
	expected := []int{0, 0x100, 0x300, 0x320}
	for k, bram := range cfg.BRAM {
		if bram.PROM_offset != expected[k] {
			t.Errorf("Wrong start for PROM %d. Got %X, wanted %X",
				k, bram.PROM_offset, expected[k])
		}
	}
}

func Test_prom_template(t *testing.T) {
	var cfg MemConfig
	e := unmarshal([]byte(BRAM_YAML), &cfg)
	if e != nil {
		t.Error(e)
		return
	}
	cfg.check_bram()
	cfg.calc_prom_we()
	tpl := get_prom_dwnld_template(t)
	var verilog strings.Builder
	for _, bram := range cfg.BRAM {
		tpl.Execute(&verilog, bram)
	}
	expected_fname := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "mem", "prom_test.out")
	compare_string_with_file(verilog.String(), expected_fname, t)
}

func compare_string_with_file(got, fname string, t *testing.T) {
	expected, e := os.ReadFile(fname)
	if e != nil {
		t.Error(e)
	}
	bad := false
	if got != string(expected) {
		e := string(expected)
		line := 1
		col := 1
		for k, _ := range got {
			if k >= len(e) {
				t.Logf("Result is too long. Difference at line %d, column %d", line, col)
				bad = true
				break
			}
			if got[k] != e[k] {
				t.Logf("Difference at line %d, column %d", line, col)
				bad = true
				break
			}
			col++
			if got[k] == '\n' {
				line++
				col = 1
			}
		}
		t.Error("Output differs")
	}
	if bad {
		t.Log(got)
	}
}

func get_prom_dwnld_template(t *testing.T) *template.Template {
	prom_dwnld := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "prom_dwnld.v")
	tpl := template.New("prom_dwnld.v")
	tpl.Funcs(funcMap)
	_, e := tpl.ParseFiles(prom_dwnld)
	if e != nil {
		t.Error(e)
		t.FailNow()
	}
	return tpl
}

func get_game_sdram_template(t *testing.T) *template.Template {
	gameAudio := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "game_audio.v")
	gameSdram := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "game_sdram.v")
	ioctlDump := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "ioctl_dump.v")
	promDwnld := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "prom_dwnld.v")

	tpl := template.New("game_sdram.v")
	tpl.Funcs(funcMap).Funcs(sprig.FuncMap())
	tpl.Funcs(audio_template_functions)
	_, e := tpl.ParseFiles(gameAudio, gameSdram, ioctlDump, promDwnld)
	if e != nil {
		t.Error(e)
		t.FailNow()
	}
	return tpl
}

func Test_game_sdram_template_uses_32bit_bram_wrappers(t *testing.T) {
	sample := `bram:
  - name: fb
    addr_width: 11
    data_width: 32
    rw: true
    sim_file: true
  - name: scene
    addr_width: 12
    data_width: 32
    rw: true
    sim_file: true
    dual_port:
      name: video
      rw: true
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Fatal(e)
	}
	cfg.Core = "test"
	cfg.normalize_bram_data_width()
	if e := cfg.normalize_bram(); e != nil {
		t.Fatal(e)
	}
	if e := cfg.check_bram(); e != nil {
		t.Fatal(e)
	}
	fill_implicit_ports(&cfg)
	make_ioctl(&cfg)
	cfg.fill_gfx_sort()

	tpl := get_game_sdram_template(t)
	var verilog strings.Builder
	if e := tpl.Execute(&verilog, cfg); e != nil {
		t.Fatal(e)
	}
	out := verilog.String()

	checks := []string{
		"jtframe_ram32 #(",
		"jtframe_dual_ram32 #(",
		".ENDIAN(0)",
		".SIMFILE(\"fb.bin\")",
		".SIMFILE(\"scene.bin\")",
		".we0",
		"scene_we",
		".we1",
		"video_we",
		"wire    [3:0]video_we;",
		".AW(11)",
		".AW(12)",
	}
	for _, each := range checks {
		if !strings.Contains(out, each) {
			t.Fatalf("generated template is missing %q\n%s", each, out)
		}
	}
	if strings.Contains(out, ".DW(32)") {
		t.Fatalf("generated template should not pass .DW(32) to jtframe_ram32\n%s", out)
	}
	if strings.Contains(out, ".SIMFILE_0(") || strings.Contains(out, ".SIMFILE_3(") {
		t.Fatalf("generated template should not emit per-lane binary SIMFILE parameters\n%s", out)
	}
}

func Test_game_sdram_template_passes_cache_endian_to_mux(t *testing.T) {
	sample := `sdram:
  big_endian: true
  cache-lines:
    - name: tiles
      cache: { blocks: 4, size: 512B, data_width: 32 }
      at:    { bank: 3, offset: TILES, length: 4MB }
`
	var cfg MemConfig
	if e := yaml.Unmarshal([]byte(sample), &cfg); e != nil {
		t.Fatal(e)
	}
	cfg.Core = "test"
	cfg.Params = []Param{{Name: "TILES", Value: "22'h100"}}
	macros.MakeFromMap(nil)
	if e := cfg.check_sdram(); e != nil {
		t.Fatal(e)
	}

	tpl := get_game_sdram_template(t)
	var verilog strings.Builder
	if e := tpl.Execute(&verilog, cfg); e != nil {
		t.Fatal(e)
	}
	out := verilog.String()

	checks := []string{
		"jtframe_cache_mux #(",
		".ENDIAN   ( 1 )",
		".DW0      ( 32 )",
	}
	for _, each := range checks {
		if !strings.Contains(out, each) {
			t.Fatalf("generated template is missing %q\n%s", each, out)
		}
	}
}

func Test_byte_en_width(t *testing.T) {
	cases := map[int]int{
		8:  1,
		16: 2,
		32: 4,
	}
	for dw, expected := range cases {
		t.Run(strconv.Itoa(dw), func(t *testing.T) {
			if got := byte_en_width(dw); got != expected {
				t.Fatalf("wrong byte enable width for %d-bit bus. Got %d, wanted %d", dw, got, expected)
			}
		})
	}
}

func Test_fill_gfx_sort_rejects_conflicting_gfx16b0(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Banks: []SDRAMBank{
				{
					Buses: []SDRAMBus{
						{Name: "a", Addr_width: 16, Gfx: "hhvvvv"},
						{Name: "b", Addr_width: 16, Offset: "16'h100", Gfx: "hvvvvx"},
					},
				},
			},
		},
	}
	defer func() {
		if recover() == nil {
			t.Fatal("fill_gfx_sort should panic when gfx16 and gfx16c require different bit0")
		}
	}()
	cfg.fill_gfx_sort()
}

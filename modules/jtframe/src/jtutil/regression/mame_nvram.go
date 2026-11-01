/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"hash/crc32"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v2"
	"jotego/jtframe/mra"
)

type mame_nvram_file struct {
	path string
	data []byte
}

type mame_nvram_default struct {
	data     []byte
	declared bool
	region   bool
}

type mame_nvram_mra struct {
	Name    string   `xml:"name"`
	Setname string   `xml:"setname"`
	ROM     []mraROM `xml:"rom"`
}

func prepare_mame_nvram(ctx context.Context, mame, setname, rompath, workspace, source, core string) error {
	if ctx == nil {
		ctx = context.Background()
	}
	if workspace == "" || source == "" || core == "" || setname == "" {
		return fmt.Errorf("MAME NVRAM setup needs set, workspace, source and core")
	}
	if err := mame_nvram_workspace(filepath.Join(workspace, "nvram")); err != nil {
		return err
	}
	probe_ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	machine, err := mame_machine_xml(probe_ctx, mame, setname, rompath, workspace)
	if err != nil {
		return err
	}
	defaults, err := project_nvram_default(source, core, setname, machine)
	if err != nil {
		return err
	}
	if !defaults.declared {
		defaults, err = mame_mra_nvram_default(source, setname, rompath, machine)
		if err != nil {
			return err
		}
	}
	if defaults.declared && len(defaults.data) == 0 && !defaults.region {
		return fmt.Errorf("NVRAM defaults are declared for %s but contain no bytes", setname)
	}
	if defaults.declared && !defaults.region {
		if err = verify_project_nvram_seed(source, setname, defaults.data); err != nil {
			return err
		}
	}
	probe_dir, err := os.MkdirTemp(workspace, "mame-nvram-probe-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(probe_dir)
	for _, dir := range []string{"cfg", "nvram", "input", "state", "snap", "diff", "ini"} {
		if err = os.MkdirAll(filepath.Join(probe_dir, dir), 0750); err != nil {
			return err
		}
	}
	lua := "emu.register_frame_done(function() manager.machine:exit() end, 'jt_nvram_probe')\n"
	lua_path := filepath.Join(probe_dir, "probe.lua")
	if err = os.WriteFile(lua_path, []byte(lua), 0600); err != nil {
		return err
	}
	args := []string{setname, "-rompath", rompath, "-skip_gameinfo", "-sound", "none", "-video", "none", "-nothrottle", "-noautosave", "-noreadconfig", "-inipath", filepath.Join(probe_dir, "ini"), "-cfg_directory", filepath.Join(probe_dir, "cfg"), "-nvram_directory", filepath.Join(probe_dir, "nvram"), "-input_directory", filepath.Join(probe_dir, "input"), "-state_directory", filepath.Join(probe_dir, "state"), "-snapshot_directory", filepath.Join(probe_dir, "snap"), "-diff_directory", filepath.Join(probe_dir, "diff"), "-autoboot_script", lua_path, "-autoboot_delay", "0"}
	cmd := exec.CommandContext(probe_ctx, mame, args...)
	cmd.Dir = probe_dir
	cmd.Env = append(os.Environ(), "XDG_CONFIG_HOME="+filepath.Join(probe_dir, "xdg"))
	out, run_err := cmd.CombinedOutput()
	if probe_ctx.Err() == context.DeadlineExceeded {
		return fmt.Errorf("MAME NVRAM probe timed out after 30s for %s", setname)
	}
	if run_err != nil {
		return fmt.Errorf("MAME NVRAM probe failed for %s: %w: %s", setname, run_err, strings.TrimSpace(string(out)))
	}
	files, err := list_mame_nvram_files(filepath.Join(probe_dir, "nvram"), setname)
	if err != nil {
		return err
	}
	if defaults.declared && defaults.region {
		defaults, err = mame_region_nvram_default(source, setname, rompath, machine)
		if err != nil {
			return err
		}
	}
	if defaults.declared {
		if len(defaults.data) == 0 {
			return fmt.Errorf("NVRAM defaults are declared for %s but no seed bytes were resolved", setname)
		}
		seed, device_path, map_err := mame_nvram_seed_target(source, core, setname, machine, defaults.data, files)
		if map_err != nil {
			return map_err
		}
		if err = os.MkdirAll(filepath.Join(workspace, "nvram"), 0750); err != nil {
			return err
		}
		path := filepath.Join(workspace, "nvram", device_path)
		if err = os.MkdirAll(filepath.Dir(path), 0750); err != nil {
			return err
		}
		if err = os.WriteFile(path, seed, 0600); err != nil {
			return fmt.Errorf("write MAME NVRAM seed for %s: %w", setname, err)
		}
		return nil
	}
	return os.MkdirAll(filepath.Join(workspace, "nvram"), 0750)
}

func mame_nvram_seed_target(source, core, setname string, machine mra.MachineXML, seed []byte, files []mame_nvram_file) ([]byte, string, error) {
	if core == "simson" && setname == "simpsons" {
		// The initial seed is 144 bytes, but this FPGA map exposes only addresses
		// 0..127. MAME models the device as a 128-byte ER5911 EEPROM, so this
		// specific mapping omits the 16 initial-seed bytes unreachable by FPGA.
		if machine.Name != "simpsons" || len(seed) != 144 {
			return nil, "", fmt.Errorf("simson/simpsons NVRAM mapping requires the 144-byte simpsons default")
		}
		mapped_bytes, err := simpsons_fpga_nvram_capacity(source)
		if err != nil {
			return nil, "", err
		}
		mame_bytes := 0
		for _, rom := range machine.Rom {
			if strings.EqualFold(rom.Region, "eeprom") {
				mame_bytes += rom.Size
			}
		}
		if mame_bytes != 128 || mapped_bytes != mame_bytes {
			return nil, "", fmt.Errorf("simson/simpsons EEPROM capacity mismatch: FPGA map %d bytes, MAME XML %d bytes", mapped_bytes, mame_bytes)
		}
		var found *mame_nvram_file
		for i := range files {
			if files[i].path == "simpsons/eeprom" && len(files[i].data) == 128 {
				if found != nil {
					return nil, "", fmt.Errorf("simson/simpsons MAME EEPROM mapping is ambiguous")
				}
				found = &files[i]
			}
		}
		if found == nil {
			return nil, "", fmt.Errorf("simson/simpsons MAME EEPROM is not a unique 128-byte device")
		}
		return append([]byte(nil), seed[:mapped_bytes]...), found.path, nil
	}
	var found *mame_nvram_file
	for i := range files {
		if len(files[i].data) != len(seed) {
			continue
		}
		if found != nil {
			return nil, "", fmt.Errorf("cannot uniquely map %d-byte NVRAM seed for %s to MAME devices", len(seed), setname)
		}
		found = &files[i]
	}
	if found == nil {
		return nil, "", fmt.Errorf("cannot uniquely map %d-byte NVRAM seed for %s to MAME devices (matching device files: 0)", len(seed), setname)
	}
	return append([]byte(nil), seed...), found.path, nil
}

func simpsons_fpga_nvram_capacity(source string) (int, error) {
	path := filepath.Join(source, "cores", "simson", "cfg", "mem.yaml")
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, fmt.Errorf("read simson NVRAM address map %s: %w", path, err)
	}
	var config struct {
		BRAM []struct {
			Name      string `yaml:"name"`
			AddrWidth int    `yaml:"addr_width"`
			DataWidth int    `yaml:"data_width"`
			Ioctl     struct {
				Save    bool `yaml:"save"`
				Restore bool `yaml:"restore"`
				Order   int  `yaml:"order"`
			} `yaml:"ioctl"`
		} `yaml:"bram"`
	}
	if err = yaml.Unmarshal(data, &config); err != nil {
		return 0, fmt.Errorf("parse simson NVRAM address map: %w", err)
	}
	var nvram *struct {
		Name      string `yaml:"name"`
		AddrWidth int    `yaml:"addr_width"`
		DataWidth int    `yaml:"data_width"`
		Ioctl     struct {
			Save    bool `yaml:"save"`
			Restore bool `yaml:"restore"`
			Order   int  `yaml:"order"`
		} `yaml:"ioctl"`
	}
	for i := range config.BRAM {
		if config.BRAM[i].Name == "nvram" {
			if nvram != nil {
				return 0, fmt.Errorf("simson mem.yaml declares multiple NVRAM BRAMs")
			}
			nvram = &config.BRAM[i]
		}
	}
	if nvram == nil || nvram.AddrWidth != 7 || nvram.DataWidth != 8 || !nvram.Ioctl.Save || !nvram.Ioctl.Restore || nvram.Ioctl.Order != 0 {
		return 0, fmt.Errorf("simson NVRAM address map must remain AW7/DW8 with IOCTL save/restore order 0")
	}
	return 1 << nvram.AddrWidth, nil
}

func mame_machine_xml(ctx context.Context, mame, setname, rompath, workspace string) (mra.MachineXML, error) {
	var result mra.MachineXML
	list_dir, err := os.MkdirTemp(workspace, "mame-nvram-listxml-")
	if err != nil {
		return result, err
	}
	defer os.RemoveAll(list_dir)
	ini_dir, cfg_dir := filepath.Join(list_dir, "ini"), filepath.Join(list_dir, "cfg")
	if err := os.MkdirAll(ini_dir, 0750); err != nil {
		return result, err
	}
	if err := os.MkdirAll(cfg_dir, 0750); err != nil {
		return result, err
	}
	cmd := exec.CommandContext(ctx, mame, "-listxml", setname, "-rompath", rompath, "-noreadconfig", "-inipath", ini_dir, "-cfg_directory", cfg_dir)
	cmd.Dir = workspace
	cmd.Env = append(os.Environ(), "XDG_CONFIG_HOME="+filepath.Join(workspace, "xdg"))
	out, err := cmd.Output()
	if ctx.Err() == context.DeadlineExceeded {
		return result, fmt.Errorf("MAME -listxml timed out for %s", setname)
	}
	if err != nil {
		return result, fmt.Errorf("MAME -listxml failed for %s: %w", setname, err)
	}
	var xml_data struct {
		Machine []mra.MachineXML `xml:"machine"`
	}
	if err = xml.Unmarshal(out, &xml_data); err != nil {
		return result, fmt.Errorf("parse MAME -listxml for %s: %w", setname, err)
	}
	for _, machine := range xml_data.Machine {
		if machine.Name == setname {
			return machine, nil
		}
	}
	return result, fmt.Errorf("MAME -listxml did not describe set %s", setname)
}

func project_nvram_default(source, core, setname string, machine mra.MachineXML) (mame_nvram_default, error) {
	config_dir := filepath.Join(source, "cores", core, "cfg")
	set_file := filepath.Join(config_dir, setname+".nvm")
	if data, err := os.ReadFile(set_file); err == nil {
		return mame_nvram_default{data: data, declared: true}, nil
	} else if !os.IsNotExist(err) {
		return mame_nvram_default{}, fmt.Errorf("read NVRAM seed %s: %w", set_file, err)
	}
	if machine.Cloneof != "" && machine.Cloneof != setname {
		clone_file := filepath.Join(config_dir, machine.Cloneof+".nvm")
		if data, err := os.ReadFile(clone_file); err == nil {
			return mame_nvram_default{data: data, declared: true}, nil
		} else if !os.IsNotExist(err) {
			return mame_nvram_default{}, fmt.Errorf("read clone NVRAM seed %s: %w", clone_file, err)
		}
	}
	toml_path := filepath.Join(config_dir, "mame2mra.toml")
	toml_file, err := os.Open(toml_path)
	if err != nil {
		return mame_nvram_default{}, fmt.Errorf("open core MRA config %s: %w", toml_path, err)
	}
	cfg, err := mra.NewMRAcfgFromTOML(toml_file)
	toml_file.Close()
	if err != nil {
		return mame_nvram_default{}, fmt.Errorf("parse core MRA config %s: %w", toml_path, err)
	}
	var chosen *mra.RawData
	for i := range cfg.ROM.Nvram.Defaults {
		each := &cfg.ROM.Nvram.Defaults[i]
		if chosen == nil && each.Machine == "" && each.Setname == "" {
			chosen = each
		}
		if each.Match(&machine) > 0 {
			chosen = each
		}
		if each.Setname == setname {
			chosen = each
			break
		}
	}
	if chosen != nil {
		data, e := mame_nvram_hex(chosen.Data)
		if e != nil {
			return mame_nvram_default{}, fmt.Errorf("decode NVRAM default for %s: %w", setname, e)
		}
		return mame_nvram_default{data: data, declared: true}, nil
	}
	for _, region := range cfg.ROM.Regions {
		if strings.EqualFold(region.Name, "nvram") && region.Match(&machine) > 0 {
			return mame_nvram_default{declared: true, region: true}, nil
		}
	}
	return mame_nvram_default{}, nil
}

func mame_nvram_hex(data string) ([]byte, error) {
	fields := strings.Fields(data)
	if len(fields) == 0 {
		return nil, fmt.Errorf("empty NVRAM default")
	}
	b := make([]byte, len(fields))
	for i, field := range fields {
		if len(field) != 2 {
			return nil, fmt.Errorf("NVRAM byte %q is not two hex digits", field)
		}
		decoded, err := hex.DecodeString(field)
		if err != nil {
			return nil, err
		}
		b[i] = decoded[0]
	}
	return b, nil
}

func mame_nvram_workspace(path string) error {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect MAME NVRAM workspace %s: %w", path, err)
	}
	if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
		return fmt.Errorf("MAME NVRAM workspace is not a private directory: %s", path)
	}
	entries, err := os.ReadDir(path)
	if err != nil {
		return fmt.Errorf("inspect MAME NVRAM workspace %s: %w", path, err)
	}
	if len(entries) != 0 {
		return fmt.Errorf("MAME NVRAM workspace is not empty: %s", path)
	}
	return nil
}

func verify_project_nvram_seed(source, setname string, data []byte) error {
	mra_path, mra_data, err := find_set_mra(source, setname)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return verify_optional_nvram_ram(source, setname, data)
		}
		return fmt.Errorf("configured NVRAM seed for %s has no generated MRA: %w", setname, err)
	}
	var game_mra mame_nvram_mra
	if err = xml.Unmarshal(mra_data, &game_mra); err != nil {
		return fmt.Errorf("parse MRA %s: %w", mra_path, err)
	}
	if game_mra.Setname != setname {
		return fmt.Errorf("MRA %s describes set %s, expected %s", mra_path, game_mra.Setname, setname)
	}
	var rom *mraROM
	for i := range game_mra.ROM {
		if game_mra.ROM[i].Index == "2" {
			rom = &game_mra.ROM[i]
			break
		}
	}
	if rom == nil {
		return fmt.Errorf("configured NVRAM seed for %s is absent from MRA %s (no index-2 ROM)", setname, mra_path)
	}
	parts := rom.AllParts()
	if len(parts) != 1 || parts[0].Name != "" {
		return fmt.Errorf("configured NVRAM seed in MRA %s is not one raw data part", mra_path)
	}
	mra_bytes, err := mame_nvram_hex(parts[0].Text)
	if err != nil {
		return fmt.Errorf("decode index-2 defaults in %s: %w", mra_path, err)
	}
	if !bytes.Equal(mra_bytes, data) {
		return fmt.Errorf("MRA index-2 defaults for %s differ from selected JTFRAME source", setname)
	}
	return verify_optional_nvram_ram(source, setname, data)
}

func verify_optional_nvram_ram(source, setname string, data []byte) error {
	ram_path := filepath.Join(source, "rom", strings.ToUpper(setname)+".RAM")
	ram_data, err := os.ReadFile(ram_path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read generated NVRAM RAM %s: %w", ram_path, err)
	}
	if !bytes.Equal(ram_data, data) {
		return fmt.Errorf("generated %s differs from selected JTFRAME NVRAM defaults", ram_path)
	}
	return nil
}

func mame_region_nvram_default(source, setname, rompath string, machine mra.MachineXML) (mame_nvram_default, error) {
	mra_path, mra_data, err := find_set_mra(source, setname)
	if err != nil {
		return mame_nvram_default{}, err
	}
	var region_mra mame_nvram_mra
	if err = xml.Unmarshal(mra_data, &region_mra); err != nil {
		return mame_nvram_default{}, fmt.Errorf("parse MRA %s: %w", mra_path, err)
	}
	if region_mra.Setname != setname {
		return mame_nvram_default{}, fmt.Errorf("MRA %s describes set %s, expected %s", mra_path, region_mra.Setname, setname)
	}
	var rom *mraROM
	for i := range region_mra.ROM {
		if region_mra.ROM[i].Index == "2" {
			rom = &region_mra.ROM[i]
			break
		}
	}
	if rom == nil {
		return mame_nvram_default{}, fmt.Errorf("core config declares NVRAM region for %s but MRA %s has no index-2 ROM", setname, mra_path)
	}
	parts := rom.AllParts()
	if len(parts) != 1 || parts[0].Name == "" {
		return mame_nvram_default{}, fmt.Errorf("NVRAM region in %s does not identify one source ROM", mra_path)
	}
	for _, entry := range machine.Rom {
		if !strings.EqualFold(entry.Region, "nvram") || entry.Name != parts[0].Name {
			continue
		}
		data, err := read_mame_rom(rompath, setname, machine.Cloneof, entry.Name)
		if err != nil {
			return mame_nvram_default{}, err
		}
		if len(data) != entry.Size {
			return mame_nvram_default{}, fmt.Errorf("NVRAM ROM %s size mismatch: MAME XML %d, ZIP %d", entry.Name, entry.Size, len(data))
		}
		crc := crc32.ChecksumIEEE(data)
		if fmt.Sprintf("%08x", crc) != strings.ToLower(entry.Crc) || (parts[0].CRC != "" && fmt.Sprintf("%08x", crc) != strings.ToLower(parts[0].CRC)) {
			return mame_nvram_default{}, fmt.Errorf("NVRAM ROM %s CRC does not match MAME XML/MRA", entry.Name)
		}
		return mame_nvram_default{data: data, declared: true}, nil
	}
	return mame_nvram_default{}, fmt.Errorf("MRA NVRAM ROM %s is absent from MAME XML set %s", parts[0].Name, setname)
}

func mame_mra_nvram_default(source, setname, rompath string, machine mra.MachineXML) (mame_nvram_default, error) {
	mra_path, mra_data, err := find_set_mra(source, setname)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return mame_nvram_default{}, nil
		}
		return mame_nvram_default{}, err
	}
	var game_mra mame_nvram_mra
	if err = xml.Unmarshal(mra_data, &game_mra); err != nil {
		return mame_nvram_default{}, fmt.Errorf("parse MRA %s: %w", mra_path, err)
	}
	if game_mra.Setname != setname {
		return mame_nvram_default{}, fmt.Errorf("MRA %s describes set %s, expected %s", mra_path, game_mra.Setname, setname)
	}
	var rom *mraROM
	for i := range game_mra.ROM {
		if game_mra.ROM[i].Index == "2" {
			rom = &game_mra.ROM[i]
			break
		}
	}
	if rom == nil || len(rom.AllParts()) == 0 {
		return mame_nvram_default{}, nil
	}
	parts := rom.AllParts()
	if len(parts) != 1 {
		return mame_nvram_default{}, fmt.Errorf("MRA %s has %d NVRAM parts; cannot map them unambiguously", mra_path, len(parts))
	}
	if parts[0].Name != "" {
		return mame_region_nvram_default(source, setname, rompath, machine)
	}
	data, err := mame_nvram_hex(parts[0].Text)
	if err != nil {
		return mame_nvram_default{}, fmt.Errorf("decode NVRAM defaults in %s: %w", mra_path, err)
	}
	ram_path := filepath.Join(source, "rom", strings.ToUpper(setname)+".RAM")
	ram_data, err := os.ReadFile(ram_path)
	if err != nil {
		return mame_nvram_default{}, fmt.Errorf("MRA %s declares NVRAM defaults but generated RAM %s is missing: %w", mra_path, ram_path, err)
	}
	if !bytes.Equal(data, ram_data) {
		return mame_nvram_default{}, fmt.Errorf("MRA defaults and generated %s differ", ram_path)
	}
	return mame_nvram_default{data: data, declared: true}, nil
}

func find_set_mra(source, setname string) (string, []byte, error) {
	path := filepath.Join(source, "release", "mra", setname+".mra")
	if data, err := os.ReadFile(path); err == nil {
		return path, data, nil
	} else if !os.IsNotExist(err) {
		return "", nil, err
	}
	files, err := filepath.Glob(filepath.Join(source, "release", "mra", "*.mra"))
	if err != nil {
		return "", nil, err
	}
	var found string
	var data []byte
	for _, candidate := range files {
		b, e := os.ReadFile(candidate)
		if e != nil {
			continue
		}
		var m mame_nvram_mra
		if xml.Unmarshal(b, &m) == nil && m.Setname == setname {
			if found != "" {
				return "", nil, fmt.Errorf("multiple MRAs match set %s: %s and %s", setname, found, candidate)
			}
			found, data = candidate, b
		}
	}
	if found == "" {
		return "", nil, fmt.Errorf("generated MRA is missing for NVRAM set %s: %w", setname, os.ErrNotExist)
	}
	return found, data, nil
}

func read_mame_rom(rompath, setname, parent, name string) ([]byte, error) {
	for _, dir := range filepath.SplitList(rompath) {
		sets := []string{setname}
		if parent != "" && parent != setname {
			sets = append(sets, parent)
		}
		for _, set := range sets {
			archive := filepath.Join(dir, set+".zip")
			zr, err := zip.OpenReader(archive)
			if err != nil {
				continue
			}
			for _, f := range zr.File {
				if f.Name != name {
					continue
				}
				r, e := f.Open()
				if e != nil {
					zr.Close()
					return nil, e
				}
				data, e := io.ReadAll(r)
				r.Close()
				zr.Close()
				if e != nil {
					return nil, e
				}
				return data, nil
			}
			zr.Close()
		}
	}
	return nil, fmt.Errorf("MAME NVRAM ROM %s not found in ROM ZIP path", name)
}

func list_mame_nvram_files(root, setname string) ([]mame_nvram_file, error) {
	set_dir := filepath.Join(root, setname)
	var out []mame_nvram_file
	err := filepath.WalkDir(set_dir, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("MAME NVRAM probe produced non-regular file %s", path)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		out = append(out, mame_nvram_file{path: rel, data: data})
		return nil
	})
	if os.IsNotExist(err) {
		err = nil
	}
	if err != nil {
		return nil, fmt.Errorf("inspect MAME NVRAM probe for %s: %w", setname, err)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].path < out[j].path })
	return out, nil
}

/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"hash/crc32"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
)

const miSTerNativeConfigRoot = "/media/fat/config"

var errMiSTerUnusableROMArchive = errors.New("unusable MiSTer ROM archive candidate")

// MiSTerAssetFile describes an immutable local input and its MRA-visible name.
// Paths are staging references; Name is the logical upload/archive name.
type MiSTerAssetFile struct {
	Role   FixtureRole `json:"role"`
	Name   string      `json:"name"`
	Path   string      `json:"path"`
	SHA256 string      `json:"sha256"`
}

// MiSTerNativeStatusProof binds the native config path to the qualified Main
// parser and selected MRA set name.
type MiSTerNativeStatusProof struct {
	MainSHA256       string `json:"main_sha256"`
	ExpectedCoreName string `json:"expected_core_name"`
	ConfigVersion    uint64 `json:"config_version,omitempty"`
	NativeStatusPath string `json:"native_status_path"`
}

type MiSTerGameAssets struct {
	OriginalMRA  MiSTerAssetFile         `json:"original_mra"`
	LaunchMRA    MiSTerAssetFile         `json:"launch_mra"`
	ROMArchives  []MiSTerAssetFile       `json:"rom_archives"`
	DefaultRAM   []MiSTerAssetFile       `json:"default_ram,omitempty"`
	NativeStatus MiSTerNativeStatusProof `json:"native_status"`
}

type MiSTerBoardConfig struct {
	ID                string `yaml:"id"`
	Host              string `yaml:"host"`
	User              string `yaml:"user"`
	SSHConfig         string `yaml:"ssh-config"`
	IdentityFile      string `yaml:"identity-file,omitempty"`
	RemoteStagingRoot string `yaml:"remote-staging-root"`
}

type MiSTerCaptureContract struct {
	Generation            string            `yaml:"generation"`
	Convention            CaptureConvention `yaml:"convention"`
	QualificationID       string            `yaml:"qualification-id"`
	QualificationEvidence string            `yaml:"qualification-evidence"`
	MainSHA256            string            `yaml:"main-sha256"`
	CommandTimeoutSeconds int               `yaml:"command-timeout-seconds"`
	LoadTimeoutSeconds    int               `yaml:"load-timeout-seconds"`
	CaptureTimeoutSeconds int               `yaml:"capture-timeout-seconds"`
	CleanupTimeoutSeconds int               `yaml:"cleanup-timeout-seconds"`
	MaxHoldMS             uint32            `yaml:"max-hold-ms"`
	ExpectedBridgeCount   int               `yaml:"expected-bridge-count"`
}

type MiSTerSessionBuildOptions struct {
	SourceRoot string
	ConfigSourceRoot string
	CabPacker  string
	Generation string
	Convention CaptureConvention
	MainSHA256 string
	MaxHoldMS  uint32
	StagingDir string
}

// PrepareMiSTerSession resolves the selected spec's profile inputs through the
// same cabinet_pack exporter used by regression, then freezes CAB/JTCP/assets
// into a transport-independent prepared session.
func PrepareMiSTerSession(ctx context.Context, core string, spec GameSpec, options MiSTerSessionBuildOptions) (PreparedSession, []byte, []byte, error) {
	var empty PreparedSession
	if ctx == nil || !manualComponent(core) || options.SourceRoot == "" || options.Generation == "" || options.Convention != CaptureNativeNonRotatedRGB888 {
		return empty, nil, nil, fmt.Errorf("MiSTer session preparation requires context, source, core, generation and native RGB888 convention")
	}
	if spec.MisterAssets == nil || spec.Setname == "" || spec.Profile.Setname != spec.Setname || !isSHA256Hex(options.MainSHA256) || spec.MisterAssets.NativeStatus.MainSHA256 != options.MainSHA256 {
		return empty, nil, nil, fmt.Errorf("selected MiSTer game requires matching profile and prepared assets")
	}
	if options.MaxHoldMS < capturePlanMinHoldMS || options.MaxHoldMS > capturePlanMaxHoldMS {
		return empty, nil, nil, fmt.Errorf("MiSTer max hold is outside supported bounds")
	}
	source, err := filepath.Abs(options.SourceRoot)
	if err != nil {
		return empty, nil, nil, err
	}
	configSource := options.ConfigSourceRoot
	if configSource == "" {
		configSource = source
	}
	frameRateMilliHz, frameRateSource, err := resolveMiSTerFrameRate(configSource, core, spec.Setname)
	if err != nil {
		return empty, nil, nil, fmt.Errorf("resolve capture frame-rate estimate: %w", err)
	}
	maxEstimatedFrames := uint64(frameRateMilliHz) * 300 / 1000
	if maxEstimatedFrames > misterCABMaxFrames {
		maxEstimatedFrames = misterCABMaxFrames
	}
	if spec.Profile.Video <= 0 || uint64(spec.Profile.Video) > maxEstimatedFrames {
		return empty, nil, nil, fmt.Errorf("frame budget %d exceeds the 300-second estimate for %s at %d mHz (maximum %d)", spec.Profile.Video, spec.Setname, frameRateMilliHz, maxEstimatedFrames)
	}
	packer := options.CabPacker
	if packer == "" {
		packer, err = build_mame_cab_packer(ctx, source)
		if err != nil {
			return empty, nil, nil, err
		}
	}
	packerSHA, err := file_sha256(packer)
	if err != nil {
		return empty, nil, nil, fmt.Errorf("hash CAB exporter: %w", err)
	}
	candidate := mame_candidate{core: core, set: spec.Setname, profile: cloneProfile(spec.Profile)}
	if spec.CAB != "" {
		candidate.cab_source = spec.CAB
	} else if spec.Profile.Inputs != "" {
		candidate.cab_source = filepath.Clean(filepath.Join(source, "cores", core, "ver", spec.Setname, spec.Profile.Inputs))
	}
	if candidate.cab_source != "" {
		candidate.cab_digest, err = file_sha256(candidate.cab_source)
		if err != nil {
			return empty, nil, nil, fmt.Errorf("hash selected source CAB: %w", err)
		}
	}
	work, err := os.MkdirTemp("/tmp", "jtutil-mister-prep-")
	if err != nil {
		return empty, nil, nil, err
	}
	defer os.RemoveAll(work)
	if _, _, err = exportMiSTerCAB(ctx, candidate, packer, work); err != nil {
		return empty, nil, nil, err
	}
	effectivePath, packedPath := filepath.Join(work, "profile-inputs.cab"), filepath.Join(work, "profile-inputs.jtcab")
	effectiveSHA, err := file_sha256(effectivePath)
	if err != nil {
		return empty, nil, nil, err
	}
	packedCAB, err := os.ReadFile(packedPath)
	if err != nil {
		return empty, nil, nil, err
	}
	cab, err := inspectPackedCAB(packedCAB)
	if err != nil {
		return empty, nil, nil, fmt.Errorf("validate exported packed CAB: %w", err)
	}
	packedSum := sha256.Sum256(packedCAB)
	entries, err := CapturePlanEntries(spec.Profile.Video, spec.Profile.Startup, 100, int(options.MaxHoldMS))
	if err != nil {
		return empty, nil, nil, err
	}
	plan, err := EncodeCapturePlan(packedCAB, entries)
	if err != nil {
		return empty, nil, nil, err
	}
	original, launch, rbf := spec.MisterAssets.OriginalMRA, spec.MisterAssets.LaunchMRA, spec.RBF
	originalSHA, err := FileSHA256(original.Path)
	if err != nil {
		return empty, nil, nil, err
	}
	launchSHA, err := FileSHA256(launch.Path)
	if err != nil {
		return empty, nil, nil, err
	}
	rbfSHA, err := FileSHA256(rbf)
	if err != nil {
		return empty, nil, nil, err
	}
	if originalSHA != original.SHA256 || launchSHA != launch.SHA256 {
		return empty, nil, nil, fmt.Errorf("MRA fixture changed during preparation")
	}
	fixtures := make([]FixtureDigest, 0, len(spec.MisterAssets.ROMArchives)+len(spec.MisterAssets.DefaultRAM))
	for _, asset := range spec.MisterAssets.ROMArchives {
		fixtures = append(fixtures, FixtureDigest{Role: asset.Role, SHA256: asset.SHA256})
	}
	for _, asset := range spec.MisterAssets.DefaultRAM {
		fixtures = append(fixtures, FixtureDigest{Role: asset.Role, SHA256: asset.SHA256})
	}
	sort.Slice(fixtures, func(i, j int) bool {
		if fixtures[i].Role == fixtures[j].Role {
			return fixtures[i].SHA256 < fixtures[j].SHA256
		}
		return fixtures[i].Role < fixtures[j].Role
	})
	sourceSHA := candidate.cab_digest
	session := PreparedSession{Core: core, Setname: spec.Setname, FrameRateMilliHz: frameRateMilliHz, FrameRateSource: frameRateSource, Profile: cloneProfile(spec.Profile),
		OriginalMRA: FixtureDigest{Role: FixtureOriginalMRA, SHA256: originalSHA}, LaunchMRA: FixtureDigest{Role: FixtureLaunchMRA, SHA256: launchSHA}, Fixtures: fixtures,
		RBF: FixtureDigest{Role: FixtureRBF, SHA256: rbfSHA}, NativeVideoStatusSeed: NativeVideoStatusSeedFixture(),
		CAB:         CABIdentity{SourceSHA256: sourceSHA, EffectiveSHA256: effectiveSHA, PackedSHA256: hex.EncodeToString(packedSum[:]), PayloadCRC32: cab.payloadCRC32, ExporterVersion: "cabinet_pack/sha256:" + packerSHA, TotalFrames: cab.totalFrames},
		Checkpoints: make([]uint32, len(entries)), Generation: options.Generation, Convention: options.Convention,
		Paths: SessionPaths{OriginalMRA: original.Path, LaunchMRA: launch.Path, StagingDir: options.StagingDir}}
	for i, entry := range entries {
		session.Checkpoints[i] = entry.Checkpoint
	}
	if err = session.Validate(); err != nil {
		return empty, nil, nil, err
	}
	if err = validateMiSTerAssets(core, spec.Setname, spec, session); err != nil {
		return empty, nil, nil, err
	}
	if _, err = decodePreparedCapturePlan(plan, cab, session.Checkpoints); err != nil {
		return empty, nil, nil, err
	}
	return session, packedCAB, plan, nil
}

// ValidateMiSTer validates additive MiSTer configuration while allowing old
// board-free regression configs to continue loading unchanged.
func (c Config) ValidateMiSTer() error {
	if c.Target == "" && len(c.Boards) == 0 && c.CaptureContract == nil {
		return nil
	}
	if c.Target == "sidi128" && len(c.Boards) == 0 && c.CaptureContract == nil {
		return nil
	}
	if c.Target != "mister" {
		return fmt.Errorf("target must be sidi128 or mister; MiSTer settings require target=mister")
	}
	ids, hosts := map[string]bool{}, map[string]bool{}
	for i, b := range c.Boards {
		if !manualComponent(b.ID) || strings.TrimSpace(b.Host) == "" || strings.TrimSpace(b.User) == "" || strings.TrimSpace(b.SSHConfig) == "" || strings.TrimSpace(b.RemoteStagingRoot) == "" {
			return fmt.Errorf("boards[%d] requires a safe id, host, user, SSH config reference and staging root", i)
		}
		if !externalConfigReference(b.SSHConfig) || b.IdentityFile != "" && !externalConfigReference(b.IdentityFile) {
			return fmt.Errorf("boards[%d] SSH config and identity file must be external path references", i)
		}
		if hasControl(b.Host) || hasControl(b.User) || hasControl(b.SSHConfig) || hasControl(b.IdentityFile) || hasControl(b.RemoteStagingRoot) {
			return fmt.Errorf("boards[%d] contains a control character", i)
		}
		id, host := strings.ToLower(strings.TrimSpace(b.ID)), strings.ToLower(strings.TrimSpace(b.Host))
		if ids[id] {
			return fmt.Errorf("duplicate normalized MiSTer board id %q", id)
		}
		if hosts[host] {
			return fmt.Errorf("duplicate normalized MiSTer board host %q", host)
		}
		ids[id], hosts[host] = true, true
		if !strings.HasPrefix(b.RemoteStagingRoot, "/") || path.Clean(b.RemoteStagingRoot) != b.RemoteStagingRoot || strings.Contains(b.RemoteStagingRoot, "..") {
			return fmt.Errorf("boards[%d] remote staging root must be a clean absolute path", i)
		}
	}
	if c.CaptureContract == nil {
		return nil
	}
	q := c.CaptureContract
	if strings.TrimSpace(q.Generation) == "" || q.Convention != CaptureNativeNonRotatedRGB888 || strings.TrimSpace(q.QualificationID) == "" || !externalConfigReference(q.QualificationEvidence) || !isSHA256Hex(q.MainSHA256) {
		return fmt.Errorf("MiSTer capture contract requires generation, native RGB888 convention, qualification evidence and Main SHA256")
	}
	for name, seconds := range map[string]int{"command": q.CommandTimeoutSeconds, "load": q.LoadTimeoutSeconds, "capture": q.CaptureTimeoutSeconds, "cleanup": q.CleanupTimeoutSeconds} {
		if seconds < 1 || seconds > 3600 {
			return fmt.Errorf("MiSTer %s timeout must be in 1..3600 seconds", name)
		}
	}
	if q.MaxHoldMS < capturePlanMinHoldMS || q.MaxHoldMS > capturePlanMaxHoldMS || q.ExpectedBridgeCount < 1 || q.ExpectedBridgeCount > 64 {
		return fmt.Errorf("MiSTer capture hold or bridge count is outside supported bounds")
	}
	return nil
}

func (c Config) ValidateMiSTerRun() error {
	if c.Target != "mister" || len(c.Boards) == 0 || c.CaptureContract == nil {
		return fmt.Errorf("MiSTer run requires target=mister, boards and capture-contract")
	}
	return c.ValidateMiSTer()
}

func hasControl(s string) bool { return strings.ContainsAny(s, "\x00\r\n") }

func externalConfigReference(value string) bool {
	if hasControl(value) || strings.TrimSpace(value) != value {
		return false
	}
	if !filepath.IsAbs(value) && !strings.HasPrefix(value, "~/") {
		return false
	}
	for _, part := range strings.Split(strings.ReplaceAll(value, "\\", "/"), "/") {
		if part == ".." {
			return false
		}
	}
	return true
}

func validateMiSTerAssets(core, set string, spec GameSpec, session PreparedSession) error {
	a := spec.MisterAssets
	if a == nil {
		return fmt.Errorf("selected game has no MiSTer assets")
	}
	if a.OriginalMRA.Role != FixtureOriginalMRA || a.LaunchMRA.Role != FixtureLaunchMRA {
		return fmt.Errorf("MiSTer MRA assets have invalid roles")
	}
	for _, asset := range append([]MiSTerAssetFile{a.OriginalMRA, a.LaunchMRA}, append(append([]MiSTerAssetFile(nil), a.ROMArchives...), a.DefaultRAM...)...) {
		if err := validateMiSTerAsset(asset); err != nil {
			return err
		}
	}
	if err := validateAssetBytes(a.OriginalMRA); err != nil {
		return err
	}
	if err := validateAssetBytes(a.LaunchMRA); err != nil {
		return err
	}
	if session.OriginalMRA.SHA256 != a.OriginalMRA.SHA256 || session.LaunchMRA.SHA256 != a.LaunchMRA.SHA256 || session.Paths.OriginalMRA != a.OriginalMRA.Path || session.Paths.LaunchMRA != a.LaunchMRA.Path {
		return fmt.Errorf("MiSTer MRA assets do not match session roles, digests or paths")
	}
	if err := validateMRAIdentityAndArchives(a.OriginalMRA.Path, core, set, a.ROMArchives, a.DefaultRAM); err != nil {
		return err
	}
	if err := validateROMAndRAMFixtures(session.Fixtures, a.ROMArchives, a.DefaultRAM); err != nil {
		return err
	}
	rbfSHA, err := FileSHA256(spec.RBF)
	if err != nil {
		return fmt.Errorf("hash selected RBF: %w", err)
	}
	if rbfSHA != session.RBF.SHA256 {
		return fmt.Errorf("selected RBF changed after session preparation")
	}
	if a.NativeStatus.ExpectedCoreName != set {
		return fmt.Errorf("native config name must follow the MRA setname override")
	}
	if err := validateNativeStatusProof(a.NativeStatus, set); err != nil {
		return err
	}
	expectedNativePath := miSTerNativeStatusPath(set, a.NativeStatus.ConfigVersion)
	if a.NativeStatus.NativeStatusPath != expectedNativePath {
		return fmt.Errorf("prepared native status path must be the exact absolute Main config path %q", expectedNativePath)
	}
	return nil
}

func validateMiSTerAsset(asset MiSTerAssetFile) error {
	if asset.Role == "" || !safeLogicalAssetName(asset.Name) || asset.Path == "" || hasControl(asset.Path) || !isSHA256Hex(asset.SHA256) {
		return fmt.Errorf("MiSTer asset has unsafe name/path, empty role or invalid SHA256")
	}
	return nil
}

func validateAssetBytes(asset MiSTerAssetFile) error {
	info, err := os.Lstat(asset.Path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() || info.Size() == 0 {
		return fmt.Errorf("MiSTer asset is not a nonempty regular file: %s", asset.Name)
	}
	digest, err := FileSHA256(asset.Path)
	if err != nil {
		return err
	}
	if digest != asset.SHA256 {
		return fmt.Errorf("MiSTer asset digest mismatch: %s", asset.Name)
	}
	return nil
}

func safeLogicalAssetName(name string) bool {
	if name == "" || strings.ContainsAny(name, "\\\x00\r\n") || strings.HasPrefix(name, "/") {
		return false
	}
	clean := path.Clean(name)
	return clean == name && clean != "." && clean != ".." && !strings.HasPrefix(clean, "../")
}

func validateMRAIdentityAndArchives(filename, core, set string, archives, defaultRAM []MiSTerAssetFile) error {
	raw, err := os.ReadFile(filename)
	if err != nil {
		return err
	}
	var m mraInventory
	if err = xml.Unmarshal(raw, &m); err != nil {
		return fmt.Errorf("decode original MRA: %w", err)
	}
	mraCore := strings.TrimSuffix(filepath.Base(m.RBF), filepath.Ext(m.RBF))
	mraCore = strings.TrimPrefix(mraCore, "jt")
	if !manualComponent(core) || !manualComponent(set) || m.Setname != set || mraCore != core {
		return fmt.Errorf("original MRA core/set identity does not match selected job")
	}
	declared := map[string]map[string]mraPart{}
	partsToCheck, err := effectiveMRAArchiveReads(m)
	if err != nil {
		return err
	}
	for _, requirement := range partsToCheck {
		candidates := requirement.candidates
		for _, name := range candidates {
			if declared[name] == nil {
				declared[name] = map[string]mraPart{}
			}
		}
		for _, name := range candidates {
			declared[name][requirement.part.Name] = requirement.part
		}
	}
	var ramBytes []byte
	ramDeclared := false
	for _, rom := range m.ROM {
		if rom.Index != "2" || len(rom.AllParts()) == 0 {
			continue
		}
		if ramDeclared {
			return fmt.Errorf("MRA has multiple default RAM declarations")
		}
		ramDeclared = true
		parts := rom.AllParts()
		if len(parts) != 1 {
			return fmt.Errorf("MRA default RAM parts are ambiguous or empty")
		}
		var err error
		if parts[0].Name != "" {
			candidates, candidateErr := effectiveMRAArchiveCandidates(rom, parts[0])
			if candidateErr != nil {
				return candidateErr
			}
			ramBytes, err = readMRAArchivePart(archives, strings.Join(candidates, "|"), parts[0])
		} else {
			ramBytes, err = mame_nvram_hex(parts[0].Text)
			if err == nil {
				ramBytes, err = mraPartWindow(ramBytes, parts[0])
			}
		}
		if err != nil {
			return fmt.Errorf("resolve MRA default RAM: %w", err)
		}
	}
	if len(ramBytes) == 0 && len(defaultRAM) != 0 {
		return fmt.Errorf("default RAM fixture is not declared by the selected MRA")
	}
	if len(ramBytes) != 0 {
		if len(defaultRAM) != 1 || defaultRAM[0].Name != strings.ToUpper(set)+".RAM" || defaultRAM[0].Role != FixtureDefaultRAM {
			return fmt.Errorf("MRA default RAM requires exactly %s.RAM", strings.ToUpper(set))
		}
		actual, err := os.ReadFile(defaultRAM[0].Path)
		if err != nil {
			return err
		}
		if !bytes.Equal(actual, ramBytes) {
			return fmt.Errorf("default RAM fixture bytes differ from selected MRA default")
		}
	}
	seen := map[string]bool{}
	for _, asset := range archives {
		_, required := declared[asset.Name]
		if asset.Role != FixtureROMArchive || !required || seen[asset.Name] {
			return fmt.Errorf("ROM archive fixture is extra, duplicated or has the wrong role: %s", asset.Name)
		}
		seen[asset.Name] = true
		if err := validateAssetBytes(asset); err != nil {
			return err
		}
		if err := validateZipMembers(asset.Path); err != nil && !errors.Is(err, errMiSTerUnusableROMArchive) {
			return fmt.Errorf("validate MRA archive %s: %w", asset.Name, err)
		}
	}
	for _, requirement := range partsToCheck {
		if err := validateZipPartAcross(archives, requirement.candidates, requirement.part); err != nil {
			return fmt.Errorf("validate MRA part %s: %w", requirement.part.Name, err)
		}
	}
	return nil
}

type mraArchiveRead struct {
	part       mraPart
	candidates []string
}

// effectiveMRAArchiveReads matches Main's part read context: unnamed inline
// parts do not read a ZIP; named parts use their own zip attribute when set,
// otherwise they inherit the enclosing ROM's candidate list.
func effectiveMRAArchiveReads(m mraInventory) ([]mraArchiveRead, error) {
	var reads []mraArchiveRead
	for _, rom := range m.ROM {
		for _, part := range rom.AllParts() {
			if part.Name == "" {
				continue
			}
			candidates, err := effectiveMRAArchiveCandidates(rom, part)
			if err != nil {
				return nil, err
			}
			reads = append(reads, mraArchiveRead{part: part, candidates: candidates})
		}
	}
	return reads, nil
}

func effectiveMRAArchiveCandidates(rom mraROM, part mraPart) ([]string, error) {
	if part.Name == "" {
		return nil, nil
	}
	zipValue := rom.Zip
	for _, attr := range part.OtherAttrs {
		if strings.EqualFold(attr.Name.Local, "zip") {
			zipValue = attr.Value
			break
		}
	}
	if zipValue == "" {
		return nil, fmt.Errorf("MRA named part %q has no effective ZIP candidates", part.Name)
	}
	return mraArchiveNames(zipValue)
}

func readMRAArchivePart(archives []MiSTerAssetFile, zipName string, part mraPart) ([]byte, error) {
	candidates, err := mraArchiveNames(zipName)
	if err != nil {
		return nil, err
	}
	wantCRC, hasCRC, err := mraPartCRC(part)
	if err != nil {
		return nil, err
	}
	var candidateErrors []string
	// Main first searches the selected ZIP set for a nonzero CRC, then falls
	// back to the literal member name. Keep archive and member order stable.
	if hasCRC {
		for _, candidate := range candidates {
			for _, asset := range archives {
				if asset.Name != candidate {
					continue
				}
				archive, openErr := zip.OpenReader(asset.Path)
				if openErr != nil {
					if miSTerFatalROMIO(openErr) { return nil, openErr }
					candidateErrors = append(candidateErrors, fmt.Sprintf("%s: %v", candidate, openErr))
					continue
				}
				for _, entry := range archive.File {
					if entry.FileInfo().IsDir() || entry.CRC32 != wantCRC {
						continue
					}
					window, memberErr := readMRAEntryWindow(entry, part)
					closeErr := archive.Close()
					if closeErr != nil {
						return nil, closeErr
					}
					if memberErr == nil {
						return window, nil
					}
					if miSTerFatalROMIO(memberErr) { return nil, memberErr }
					candidateErrors = append(candidateErrors, fmt.Sprintf("%s member CRC candidate: %v", candidate, memberErr))
					archive = nil
					break
				}
				if archive != nil {
					if closeErr := archive.Close(); closeErr != nil {
						return nil, closeErr
					}
				}
			}
		}
	}
	for _, candidate := range candidates {
		for _, asset := range archives {
			if asset.Name != candidate {
				continue
			}
			archive, openErr := zip.OpenReader(asset.Path)
			if openErr != nil {
				if miSTerFatalROMIO(openErr) { return nil, openErr }
				candidateErrors = append(candidateErrors, fmt.Sprintf("%s: %v", candidate, openErr))
				continue
			}
			found := false
			for _, entry := range archive.File {
				if entry.Name != part.Name || entry.FileInfo().IsDir() {
					continue
				}
				found = true
				window, memberErr := readMRAEntryWindow(entry, part)
				if memberErr != nil {
					if miSTerFatalROMIO(memberErr) { _ = archive.Close(); return nil, memberErr }
					candidateErrors = append(candidateErrors, fmt.Sprintf("%s literal member: %v", candidate, memberErr))
					break
				}
				if closeErr := archive.Close(); closeErr != nil {
					return nil, closeErr
				}
				return window, nil
			}
			if closeErr := archive.Close(); closeErr != nil {
				return nil, closeErr
			}
			if !found {
				candidateErrors = append(candidateErrors, fmt.Sprintf("%s: literal member %q absent", candidate, part.Name))
			}
		}
	}
	if len(candidateErrors) != 0 {
		return nil, miSTerGameInputError(fmt.Errorf("MRA part %q is missing from candidate archives %q (%s)", part.Name, zipName, strings.Join(candidateErrors, "; ")))
	}
	return nil, miSTerGameInputError(fmt.Errorf("MRA part %q is missing from candidate archives %q", part.Name, zipName))
}

func miSTerFatalROMIO(err error) bool {
	var pathErr *os.PathError
	return errors.As(err, &pathErr) || errors.Is(err, syscall.EIO) || errors.Is(err, syscall.EACCES)
}

func readMRAEntryWindow(entry *zip.File, part mraPart) ([]byte, error) {
	data, err := readZipEntry(entry)
	if err != nil {
		return nil, err
	}
	return mraPartWindow(data, part)
}

func mraArchiveNames(value string) ([]string, error) {
	parts := strings.Split(value, "|")
	seen := make(map[string]bool, len(parts))
	for i, name := range parts {
		if !safeLogicalAssetName(name) || !strings.EqualFold(path.Ext(name), ".zip") || seen[name] {
			return nil, fmt.Errorf("MRA declares unsafe, duplicate or invalid ROM archive name %q", name)
		}
		seen[name] = true
		parts[i] = name
	}
	return parts, nil
}

func parseMRAUint(value, field string) (uint64, error) {
	if value == "" {
		return 0, nil
	}
	parsed, err := strconv.ParseUint(value, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("MRA part %s %q is not a valid base-0 unsigned integer", field, value)
	}
	return parsed, nil
}

func mraPartWindow(data []byte, part mraPart) ([]byte, error) {
	if want, hasCRC, err := mraPartCRC(part); err != nil {
		return nil, err
	} else if hasCRC && crc32.ChecksumIEEE(data) != want {
		return nil, fmt.Errorf("MRA part %q CRC mismatch", part.Name)
	}
	offset, err := parseMRAUint(part.Offset, "offset")
	if err != nil {
		return nil, err
	}
	length, err := parseMRAUint(part.Length, "length")
	if err != nil {
		return nil, err
	}
	if offset >= uint64(len(data)) {
		return nil, fmt.Errorf("MRA part %q offset %d is outside the %d-byte member", part.Name, offset, len(data))
	}
	remaining := uint64(len(data)) - offset
	if length == 0 || length > remaining {
		length = remaining
	}
	return data[offset : offset+length], nil
}

func mraPartCRC(part mraPart) (uint32, bool, error) {
	if part.CRC == "" {
		return 0, false, nil
	}
	want, err := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(part.CRC), "0x"), 16, 32)
	if err != nil {
		return 0, false, fmt.Errorf("MRA part %q CRC %q is invalid", part.Name, part.CRC)
	}
	// MiSTer treats zero as no CRC selector and falls back to the path.
	return uint32(want), want != 0, nil
}

func validateZipMembers(filename string) error {
	z, err := zip.OpenReader(filename)
	if err != nil {
		return fmt.Errorf("%w: %v", errMiSTerUnusableROMArchive, err)
	}
	defer z.Close()
	if len(z.File) == 0 {
		return fmt.Errorf("%w: archive is empty", errMiSTerUnusableROMArchive)
	}
	seen := map[string]bool{}
	for _, f := range z.File {
		if f.FileInfo().IsDir() {
			name := strings.TrimSuffix(f.Name, "/")
			if name == "" || !safeLogicalAssetName(name) {
				return fmt.Errorf("unsafe directory member name %q", f.Name)
			}
			continue
		}
		if !safeLogicalAssetName(f.Name) {
			return fmt.Errorf("unsafe member name %q", f.Name)
		}
		if seen[f.Name] {
			return fmt.Errorf("duplicate member %q", f.Name)
		}
		seen[f.Name] = true
	}
	return nil
}

func validateZipParts(filename string, required map[string]mraPart) error {
	z, err := zip.OpenReader(filename)
	if err != nil {
		return err
	}
	defer z.Close()
	found := map[string]*zip.File{}
	for _, f := range z.File {
		if !f.FileInfo().IsDir() {
			if found[f.Name] != nil {
				return fmt.Errorf("ambiguous member %q", f.Name)
			}
			found[f.Name] = f
		}
	}
	for name, part := range required {
		entry := found[name]
		if entry == nil {
			return fmt.Errorf("MRA-required member %q is missing", name)
		}
		reader, err := entry.Open()
		if err != nil {
			return err
		}
		hash := crc32.NewIEEE()
		size, readErr := io.Copy(hash, reader)
		closeErr := reader.Close()
		if readErr != nil {
			return readErr
		}
		if closeErr != nil {
			return closeErr
		}
		if want, hasCRC, crcErr := mraPartCRC(part); crcErr != nil {
			return crcErr
		} else if hasCRC && hash.Sum32() != want {
			return fmt.Errorf("MRA CRC for member %q does not match ZIP content", name)
		}
		if part.Length != "" {
			base := 10
			length := part.Length
			if strings.HasPrefix(strings.ToLower(length), "0x") {
				base = 16
				length = length[2:]
			}
			want, parseErr := strconv.ParseUint(length, base, 64)
			if parseErr != nil || size != int64(want) {
				return fmt.Errorf("MRA length for member %q does not match ZIP content", name)
			}
		}
	}
	return nil
}

func validateZipPartAcross(archives []MiSTerAssetFile, candidates []string, part mraPart) error {
	_, err := readMRAArchivePart(archives, strings.Join(candidates, "|"), part)
	return err
}

func validateROMAndRAMFixtures(fixtures []FixtureDigest, archives, ram []MiSTerAssetFile) error {
	want := make([]FixtureDigest, 0, len(archives)+len(ram))
	for _, asset := range archives {
		want = append(want, FixtureDigest{Role: FixtureROMArchive, SHA256: asset.SHA256})
	}
	seenNames := map[string]bool{}
	for _, asset := range ram {
		if asset.Role != FixtureDefaultRAM || !strings.EqualFold(path.Ext(asset.Name), ".RAM") || seenNames[asset.Name] {
			return fmt.Errorf("default RAM fixture has wrong role, name or duplicate logical name")
		}
		seenNames[asset.Name] = true
		if err := validateAssetBytes(asset); err != nil {
			return err
		}
		want = append(want, FixtureDigest{Role: FixtureDefaultRAM, SHA256: asset.SHA256})
	}
	got := append([]FixtureDigest(nil), fixtures...)
	sort.Slice(want, func(i, j int) bool {
		if want[i].Role == want[j].Role {
			return want[i].SHA256 < want[j].SHA256
		}
		return want[i].Role < want[j].Role
	})
	sort.Slice(got, func(i, j int) bool {
		if got[i].Role == got[j].Role {
			return got[i].SHA256 < got[j].SHA256
		}
		return got[i].Role < got[j].Role
	})
	if len(want) != len(got) {
		return fmt.Errorf("ROM/default RAM fixture count does not match prepared session")
	}
	for i := range want {
		if want[i] != got[i] {
			return fmt.Errorf("ROM/default RAM fixture roles or digests do not match prepared session")
		}
	}
	return nil
}

func validateNativeStatusProof(p MiSTerNativeStatusProof, core string) error {
	if !isSHA256Hex(p.MainSHA256) || p.ExpectedCoreName == "" || !manualComponent(p.ExpectedCoreName) || p.ExpectedCoreName != core || p.ConfigVersion > 99 {
		return fmt.Errorf("native-status proof does not match the qualified Main and selected core")
	}
	expected := miSTerNativeStatusPath(p.ExpectedCoreName, p.ConfigVersion)
	if filepath.Clean(p.NativeStatusPath) != expected || hasControl(p.NativeStatusPath) {
		return fmt.Errorf("native status path must be the exact selected set config %q", expected)
	}
	return nil
}

func isCommitSHA(value string) bool {
	if len(value) != 40 || strings.ToLower(value) != value {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}

func exportMiSTerCAB(ctx context.Context, candidate mame_candidate, packer, work string) (MameCabScript, []byte, error) {
	profile := candidate.profile
	var empty MameCabScript
	if profile.Video <= 0 || profile.Video > 0x7fffffff {
		return empty, nil, fmt.Errorf("profile video frame count is outside CAB exporter bounds")
	}
	for key := range profile.Options {
		if key != "dipsw" {
			return empty, nil, fmt.Errorf("unsupported MiSTer regression profile option %q", key)
		}
	}
	if packer == "" {
		return empty, nil, fmt.Errorf("CAB exporter is unavailable for selected inputs")
	}
	input := fmt.Sprintf("%d\n", profile.Video)
	if candidate.cab_source != "" {
		digest, err := file_sha256(candidate.cab_source)
		if err != nil || digest != candidate.cab_digest {
			return empty, nil, fmt.Errorf("selected CAB input changed after profile resolution")
		}
		data, err := os.ReadFile(candidate.cab_source)
		if err != nil {
			return empty, nil, fmt.Errorf("read selected CAB %s: %w", candidate.cab_source, err)
		}
		input = string(data)
	}
	if raw, ok := profile.Options["dipsw"]; ok {
		value := strings.TrimPrefix(strings.ToLower(fmt.Sprint(raw)), "0x")
		dipsw, err := strconv.ParseUint(value, 16, 32)
		if err != nil {
			return empty, nil, fmt.Errorf("profile dipsw must be a hexadecimal 32-bit value")
		}
		input = fmt.Sprintf("dipsw=%x\n", dipsw) + input
	}
	inputPath, outputPath := filepath.Join(work, "profile-inputs.cab"), filepath.Join(work, "profile-inputs.jtcab")
	if err := os.WriteFile(inputPath, []byte(input), 0600); err != nil {
		return empty, nil, err
	}
	command := exec.CommandContext(ctx, packer, inputPath, outputPath, "--frame-budget", strconv.Itoa(profile.Video))
	if output, err := command.CombinedOutput(); err != nil {
		return empty, nil, fmt.Errorf("export MiSTer CAB inputs: %w: %s", err, strings.TrimSpace(string(output)))
	}
	script, err := ReadMameCab(outputPath, profile.Video)
	if err != nil {
		return empty, nil, err
	}
	for _, run := range script.Runs {
		if run.Dump {
			return empty, nil, fmt.Errorf("CAB dump actions are unsupported by MiSTer capture")
		}
	}
	packedCAB, err := os.ReadFile(outputPath)
	if err != nil {
		return empty, nil, err
	}
	if _, err = inspectPackedCAB(packedCAB); err != nil {
		return empty, nil, fmt.Errorf("validate MiSTer CAB bytes: %w", err)
	}
	return script, packedCAB, nil
}

func decodePreparedCapturePlan(raw []byte, cab packedCABHeader, checkpoints []uint32) (CapturePlan, error) {
	var plan CapturePlan
	if len(raw) < capturePlanHeaderLen+capturePlanCRCLen || string(raw[:4]) != "JTCP" {
		return plan, fmt.Errorf("prepared JTCP is missing or malformed")
	}
	count := int(binary.LittleEndian.Uint16(raw[6:8]))
	if binary.LittleEndian.Uint16(raw[4:6]) != capturePlanVersion || count != len(checkpoints) || len(raw) != capturePlanHeaderLen+count*capturePlanEntryLen+capturePlanCRCLen {
		return plan, fmt.Errorf("prepared JTCP version or entry count differs from session")
	}
	if crc32.ChecksumIEEE(raw[:len(raw)-capturePlanCRCLen]) != binary.LittleEndian.Uint32(raw[len(raw)-capturePlanCRCLen:]) {
		return plan, fmt.Errorf("prepared JTCP checksum mismatch")
	}
	plan.PackedCABPayloadCRC32 = binary.LittleEndian.Uint32(raw[8:12])
	plan.TotalFrames = binary.LittleEndian.Uint32(raw[12:16])
	if plan.PackedCABPayloadCRC32 != cab.payloadCRC32 || plan.TotalFrames != cab.totalFrames {
		return plan, fmt.Errorf("prepared JTCP does not bind exact packed CAB")
	}
	for i := 0; i < count; i++ {
		off := capturePlanHeaderLen + i*capturePlanEntryLen
		entry := CapturePlanEntry{Checkpoint: binary.LittleEndian.Uint32(raw[off : off+4]), MaxHoldMS: binary.LittleEndian.Uint32(raw[off+4 : off+8])}
		if entry.Checkpoint != checkpoints[i] || entry.MaxHoldMS < capturePlanMinHoldMS || entry.MaxHoldMS > capturePlanMaxHoldMS {
			return plan, fmt.Errorf("prepared JTCP schedule differs from session checkpoints")
		}
		plan.Entries = append(plan.Entries, entry)
	}
	return plan, nil
}

var _ = io.EOF

/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strings"
)

// ErrCaptureNotStarted means the driver rejected an attempt before it
// acquired board ownership. Coordinators may retry after repairing the
// preflight condition without creating an unknown-ownership record.
var ErrCaptureNotStarted = errors.New("capture did not acquire board ownership")

// CaptureConvention identifies the physical framebuffer interpretation used
// by the session. The initial MiSTer regression contract captures progressive
// native, non-rotated RGB888 pixels; vertical content remains native vertical.
type CaptureConvention string

const (
	CaptureNativeNonRotatedRGB888 CaptureConvention = "native-non-rotated-rgb888-v1"
	MaxSessionEvents                                = 128
	MaxSessionEventFields                           = 16
	MaxSessionEventBytes                            = 4096
)

// FixtureRole gives a content hash a stable semantic role. Paths are kept in
// SessionPaths and never participate in portable input identity.
type FixtureRole string

const (
	FixtureOriginalMRA           FixtureRole = "original-mra"
	FixtureLaunchMRA             FixtureRole = "launch-mra"
	FixtureROMArchive            FixtureRole = "rom-archive"
	FixtureDefaultRAM            FixtureRole = "default-ram"
	FixtureNativeVideoStatusSeed FixtureRole = "native-video-status-seed"
	FixtureRBF                   FixtureRole = "rbf"
	FixtureCABSource             FixtureRole = "cab-source"
	FixtureCABEffective          FixtureRole = "cab-effective"
	FixtureCABPacked             FixtureRole = "cab-packed"
)

// FixtureDigest identifies immutable bytes by role, independent of where they
// happen to be staged for a particular board attempt.
type FixtureDigest struct {
	Role   FixtureRole `json:"role"`
	SHA256 string      `json:"sha256"`
}

// CABIdentity pins the input, effective script, packed CAB and exporter.
type CABIdentity struct {
	SourceSHA256    string `json:"source_sha256,omitempty"`
	EffectiveSHA256 string `json:"effective_sha256"`
	PackedSHA256    string `json:"packed_sha256"`
	PayloadCRC32    uint32 `json:"payload_crc32"`
	ExporterVersion string `json:"exporter_version"`
	TotalFrames     uint32 `json:"total_frames"`
}

// CanonicalNativeVideoStatusSeed is the 16-byte, display-only native-video
// seed used for capture mode. It is distinct from game DIP/CAB inputs and
// user-owned configuration backups. Its bytes are stable across boards.
func CanonicalNativeVideoStatusSeed() [16]byte {
	return [16]byte{0x04}
}

func NativeVideoStatusSeedFixture() FixtureDigest {
	seed := CanonicalNativeVideoStatusSeed()
	digest := sha256.Sum256(seed[:])
	return FixtureDigest{Role: FixtureNativeVideoStatusSeed, SHA256: hex.EncodeToString(digest[:])}
}

// SessionPaths contains attempt-local paths. These values are deliberately
// excluded from PortableIdentity so a board's staging root or launch pathname
// does not make otherwise equivalent prepared inputs appear different.
type SessionPaths struct {
	OriginalMRA string `json:"original_mra,omitempty"`
	LaunchMRA   string `json:"launch_mra,omitempty"`
	StagingDir  string `json:"staging_dir,omitempty"`
}

// PreparedSession is an immutable handoff from preparation to a board worker.
// Slices and maps are caller-owned at construction; use Clone before handing
// the value to a worker. Workers must treat their copy as read-only and must
// not mutate coordinator-owned values.
type PreparedSession struct {
	Core                  string            `json:"core"`
	Setname               string            `json:"setname"`
	FrameRateMilliHz      uint32            `json:"frame_rate_millihz,omitempty"`
	FrameRateSource       string            `json:"frame_rate_source,omitempty"`
	Profile               Profile           `json:"profile"`
	OriginalMRA           FixtureDigest     `json:"original_mra"`
	LaunchMRA             FixtureDigest     `json:"launch_mra"`
	Fixtures              []FixtureDigest   `json:"fixtures"`
	RBF                   FixtureDigest     `json:"rbf"`
	NativeVideoStatusSeed FixtureDigest     `json:"native_video_status_seed"`
	CAB                   CABIdentity       `json:"cab"`
	Checkpoints           []uint32          `json:"checkpoints"`
	Generation            string            `json:"capture_generation"`
	Convention            CaptureConvention `json:"capture_convention"`
	Paths                 SessionPaths      `json:"paths,omitempty"`
}

// Clone returns a deep copy suitable for transferring to a worker. In
// particular, Profile.Options may contain nested maps, slices and arrays.
func (p PreparedSession) Clone() PreparedSession {
	p.Profile = cloneProfile(p.Profile)
	p.Fixtures = append([]FixtureDigest(nil), p.Fixtures...)
	p.Checkpoints = append([]uint32(nil), p.Checkpoints...)
	return p
}

// Validate checks the immutable inputs before a worker receives this session.
// File paths are validated by the staging/transport layer, not here.
func (p PreparedSession) Validate() error {
	if strings.TrimSpace(p.Core) == "" || strings.TrimSpace(p.Setname) == "" {
		return fmt.Errorf("prepared session requires core and setname")
	}
	if p.Profile.Setname != p.Setname || p.Profile.Video <= 0 || p.Profile.Video > misterCABMaxFrames || p.Profile.Startup < 0 || p.Profile.Startup >= p.Profile.Video {
		return fmt.Errorf("prepared session profile does not match setname or valid frame bounds")
	}
	if p.FrameRateMilliHz != 0 || p.FrameRateSource != "" {
		if p.FrameRateMilliHz == 0 || (p.FrameRateSource != "JTFRAME_RATE" && p.FrameRateSource != "doc/mame.xml") || uint64(p.Profile.Video)*1000 > uint64(p.FrameRateMilliHz)*300 {
			return fmt.Errorf("prepared session frame budget exceeds the 300-second estimate or has invalid rate metadata")
		}
	}
	if _, err := canonicalIdentityMap(p.Profile.Options); err != nil {
		return fmt.Errorf("prepared session profile options are not portable: %w", err)
	}
	for _, fixture := range []FixtureDigest{p.OriginalMRA, p.LaunchMRA, p.RBF} {
		if err := validateFixtureDigest(fixture); err != nil {
			return err
		}
	}
	if p.OriginalMRA.Role != FixtureOriginalMRA || p.LaunchMRA.Role != FixtureLaunchMRA || p.RBF.Role != FixtureRBF {
		return fmt.Errorf("prepared session MRA/RBF fixture roles are inconsistent")
	}
	if p.NativeVideoStatusSeed != NativeVideoStatusSeedFixture() {
		return fmt.Errorf("prepared session native video status seed is not the canonical 16-byte seed")
	}
	for _, fixture := range p.Fixtures {
		if err := validateFixtureDigest(fixture); err != nil {
			return err
		}
		if fixture.Role != FixtureROMArchive && fixture.Role != FixtureDefaultRAM {
			return fmt.Errorf("prepared session additional fixture role %q is not canonical", fixture.Role)
		}
	}
	if p.CAB.EffectiveSHA256 == "" || p.CAB.PackedSHA256 == "" || p.CAB.ExporterVersion == "" || p.CAB.TotalFrames != uint32(p.Profile.Video) {
		return fmt.Errorf("prepared session CAB identity is incomplete or has a different frame budget")
	}
	for _, digest := range []string{p.CAB.EffectiveSHA256, p.CAB.PackedSHA256} {
		if !isSHA256Hex(digest) {
			return fmt.Errorf("prepared session CAB identity has invalid SHA256 %q", digest)
		}
	}
	if p.CAB.SourceSHA256 != "" && !isSHA256Hex(p.CAB.SourceSHA256) {
		return fmt.Errorf("prepared session CAB source has invalid SHA256 %q", p.CAB.SourceSHA256)
	}
	if p.Generation == "" || p.Convention != CaptureNativeNonRotatedRGB888 {
		return fmt.Errorf("prepared session requires a capture generation and supported native RGB888 convention")
	}
	if len(p.Checkpoints) == 0 || len(p.Checkpoints) > capturePlanMaxEntries {
		return fmt.Errorf("prepared session checkpoint count must be in 1..%d", capturePlanMaxEntries)
	}
	var previous uint32
	for _, checkpoint := range p.Checkpoints {
		if checkpoint == 0 || checkpoint <= previous || checkpoint > p.CAB.TotalFrames {
			return fmt.Errorf("prepared session checkpoints must increase within 1..%d", p.CAB.TotalFrames)
		}
		previous = checkpoint
	}
	return nil
}

func validateFixtureDigest(fixture FixtureDigest) error {
	if fixture.Role == "" || !isSHA256Hex(fixture.SHA256) {
		return fmt.Errorf("fixture has an empty role or invalid SHA256")
	}
	return nil
}

func isSHA256Hex(value string) bool {
	if len(value) != 64 || strings.ToLower(value) != value {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}

func cloneProfile(profile Profile) Profile {
	profile.Options = cloneMap(profile.Options)
	return profile
}

func cloneMap(values map[string]interface{}) map[string]interface{} {
	if values == nil {
		return nil
	}
	copy := make(map[string]interface{}, len(values))
	for key, value := range values {
		copy[key] = cloneValue(value)
	}
	return copy
}

func cloneValue(value interface{}) interface{} {
	if value == nil {
		return value
	}
	original := reflect.ValueOf(value)
	switch original.Kind() {
	case reflect.Map:
		if original.IsNil() {
			return reflect.Zero(original.Type()).Interface()
		}
		copy := reflect.MakeMapWithSize(original.Type(), original.Len())
		iterator := original.MapRange()
		for iterator.Next() {
			copy.SetMapIndex(iterator.Key(), cloneReflectValue(iterator.Value(), original.Type().Elem()))
		}
		return copy.Interface()
	case reflect.Slice:
		if original.IsNil() {
			return reflect.Zero(original.Type()).Interface()
		}
		copy := reflect.MakeSlice(original.Type(), original.Len(), original.Len())
		for index := 0; index < original.Len(); index++ {
			copy.Index(index).Set(cloneReflectValue(original.Index(index), original.Type().Elem()))
		}
		return copy.Interface()
	case reflect.Array:
		copy := reflect.New(original.Type()).Elem()
		for index := 0; index < original.Len(); index++ {
			copy.Index(index).Set(cloneReflectValue(original.Index(index), original.Type().Elem()))
		}
		return copy.Interface()
	default:
		return value
	}
}

func cloneReflectValue(value reflect.Value, target reflect.Type) reflect.Value {
	if !value.IsValid() {
		return reflect.Zero(target)
	}
	cloned := reflect.ValueOf(cloneValue(value.Interface()))
	if !cloned.IsValid() {
		return reflect.Zero(target)
	}
	if cloned.Type().AssignableTo(target) || target.Kind() == reflect.Interface && cloned.Type().Implements(target) {
		return cloned
	}
	return value
}

// PortableIdentity returns a stable SHA256 over portable input facts only.
// Board, attempt, staging and source-path values are intentionally excluded.
func (p PreparedSession) PortableIdentity() (string, error) {
	fixtures := append([]FixtureDigest(nil), p.Fixtures...)
	// LaunchMRA is an attempt-local derivative whose only permitted changes
	// are staging references. Its exact digest remains in PreparedSession for
	// provenance, while canonical game/config inputs are bound by OriginalMRA,
	// Profile, RBF and the other fixture digests below.
	fixtures = append(fixtures, p.OriginalMRA, p.RBF,
		p.NativeVideoStatusSeed,
		FixtureDigest{Role: FixtureCABSource, SHA256: p.CAB.SourceSHA256},
		FixtureDigest{Role: FixtureCABEffective, SHA256: p.CAB.EffectiveSHA256},
		FixtureDigest{Role: FixtureCABPacked, SHA256: p.CAB.PackedSHA256})
	sort.Slice(fixtures, func(i, j int) bool {
		if fixtures[i].Role == fixtures[j].Role {
			return fixtures[i].SHA256 < fixtures[j].SHA256
		}
		return fixtures[i].Role < fixtures[j].Role
	})
	profile := cloneProfile(p.Profile)
	profile.Inputs = "" // source path is covered by CAB content hashes, not portability.
	options, err := canonicalIdentityMap(profile.Options)
	if err != nil {
		return "", fmt.Errorf("canonicalize prepared profile options: %w", err)
	}
	profile.Options = options
	identity := struct {
		Core             string            `json:"core"`
		Setname          string            `json:"setname"`
		FrameRateMilliHz uint32            `json:"frame_rate_millihz,omitempty"`
		FrameRateSource  string            `json:"frame_rate_source,omitempty"`
		Profile          Profile           `json:"profile"`
		Fixtures         []FixtureDigest   `json:"fixtures"`
		CAB              CABIdentity       `json:"cab"`
		Checkpoints      []uint32          `json:"checkpoints"`
		Generation       string            `json:"capture_generation"`
		Convention       CaptureConvention `json:"capture_convention"`
	}{p.Core, p.Setname, p.FrameRateMilliHz, p.FrameRateSource, profile, fixtures, p.CAB,
		append([]uint32(nil), p.Checkpoints...), p.Generation, p.Convention}
	data, err := json.Marshal(identity)
	if err != nil {
		return "", fmt.Errorf("encode prepared session identity: %w", err)
	}
	digest := sha256.Sum256(data)
	return hex.EncodeToString(digest[:]), nil
}

func canonicalIdentityMap(values map[string]interface{}) (map[string]interface{}, error) {
	if values == nil {
		return nil, nil
	}
	result := make(map[string]interface{}, len(values))
	for key, value := range values {
		canonical, err := canonicalIdentityValue(value)
		if err != nil {
			return nil, fmt.Errorf("option %q: %w", key, err)
		}
		result[key] = canonical
	}
	return result, nil
}

func canonicalIdentityValue(value interface{}) (interface{}, error) {
	if value == nil {
		return nil, nil
	}
	original := reflect.ValueOf(value)
	switch original.Kind() {
	case reflect.Map:
		if original.IsNil() {
			return map[string]interface{}(nil), nil
		}
		result := make(map[string]interface{}, original.Len())
		iterator := original.MapRange()
		for iterator.Next() {
			keyValue := iterator.Key()
			for keyValue.Kind() == reflect.Interface {
				if keyValue.IsNil() {
					return nil, fmt.Errorf("nil map key cannot be canonicalized")
				}
				keyValue = keyValue.Elem()
			}
			switch keyValue.Kind() {
			case reflect.String, reflect.Bool,
				reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
				reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
			default:
				return nil, fmt.Errorf("unsupported map key type %s", keyValue.Type())
			}
			key := fmt.Sprint(keyValue.Interface())
			if _, duplicate := result[key]; duplicate {
				return nil, fmt.Errorf("duplicate canonical map key %q", key)
			}
			item, err := canonicalIdentityValue(iterator.Value().Interface())
			if err != nil {
				return nil, fmt.Errorf("map key %q: %w", key, err)
			}
			result[key] = item
		}
		return result, nil
	case reflect.Slice, reflect.Array:
		result := make([]interface{}, original.Len())
		for index := 0; index < original.Len(); index++ {
			item, err := canonicalIdentityValue(original.Index(index).Interface())
			if err != nil {
				return nil, fmt.Errorf("item %d: %w", index, err)
			}
			result[index] = item
		}
		return result, nil
	default:
		switch original.Kind() {
		case reflect.Bool, reflect.String,
			reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
			reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr,
			reflect.Float32, reflect.Float64:
			return value, nil
		default:
			return nil, fmt.Errorf("unsupported mutable/profile option type %s", original.Type())
		}
	}
}

// BoardKey is a stable configured-board identity; it is separate from the
// portable content identity of a PreparedSession.
type BoardKey string

// AttemptKey identifies one invocation on one board. Nonce prevents a delayed
// worker result from being mistaken for a later retry of the same session.
type AttemptKey struct {
	Board     BoardKey `json:"board"`
	SessionID string   `json:"session_id"`
	Nonce     string   `json:"nonce"`
}

type SessionEvent struct {
	AtUnixNano int64             `json:"at_unix_ns"`
	Stage      string            `json:"stage"`
	Message    string            `json:"message,omitempty"`
	Fields     map[string]string `json:"fields,omitempty"`
}

type SessionCleanup struct {
	Confirmed bool   `json:"confirmed"`
	Required  bool   `json:"required"`
	Message   string `json:"message,omitempty"`
}

// SessionCapture is private worker output. PNG paths and workspaces remain
// attempt-owned until the coordinator validates and finalizes the result.
type SessionCapture struct {
	Key           AttemptKey     `json:"key"`
	HostName      string         `json:"host_name,omitempty"`
	Workspace     string         `json:"workspace"`
	WorkspaceRoot string         `json:"workspace_root,omitempty"`
	Receipt       CaptureReceipt `json:"receipt"`
	PNGPaths      []string       `json:"png_paths"`
	Events        []SessionEvent `json:"events,omitempty"`
	Cleanup       SessionCleanup `json:"cleanup"`
}

// Clone detaches a result from any worker-owned slices/maps before the
// coordinator stores it or begins finalization.
func (c SessionCapture) Clone() SessionCapture {
	c.PNGPaths = append([]string(nil), c.PNGPaths...)
	c.Receipt.Images = append([]ImageReceipt(nil), c.Receipt.Images...)
	c.Events = append([]SessionEvent(nil), c.Events...)
	for index := range c.Events {
		if c.Events[index].Fields != nil {
			fields := make(map[string]string, len(c.Events[index].Fields))
			for key, value := range c.Events[index].Fields {
				fields[key] = value
			}
			c.Events[index].Fields = fields
		}
	}
	return c
}

// ValidateEnvelope checks bounded worker output and binds it to the assigned
// attempt. Transport-specific receipt validation happens before this summary
// is constructed.
func (c SessionCapture) ValidateEnvelope(expected AttemptKey) error {
	if c.Key != expected {
		return fmt.Errorf("capture result attempt key does not match assignment")
	}
	if c.Receipt.SessionID != expected.SessionID {
		return fmt.Errorf("capture receipt session id does not match assignment")
	}
	if len(c.PNGPaths) > capturePlanMaxEntries || len(c.Receipt.Images) > capturePlanMaxEntries {
		return fmt.Errorf("capture result exceeds %d image entries", capturePlanMaxEntries)
	}
	if len(c.Events) > MaxSessionEvents {
		return fmt.Errorf("capture result exceeds %d events", MaxSessionEvents)
	}
	for _, event := range c.Events {
		if len(event.Fields) > MaxSessionEventFields {
			return fmt.Errorf("capture event exceeds %d fields", MaxSessionEventFields)
		}
		bytes := len(event.Stage) + len(event.Message)
		for key, value := range event.Fields {
			bytes += len(key) + len(value)
		}
		if bytes > MaxSessionEventBytes {
			return fmt.Errorf("capture event exceeds %d bytes", MaxSessionEventBytes)
		}
	}
	return nil
}

// SessionDriver owns one board and returns worker-private results. It must not
// receive coordinator logs, progress maps, result roots or publication hooks.
type SessionDriver interface {
	Capture(context.Context, AttemptKey, PreparedSession) (SessionCapture, error)
	Cancel(context.Context, AttemptKey) error
	Reconcile(context.Context, AttemptKey) (SessionCleanup, error)
	Healthy(context.Context) error
}

// CaptureReceipt is the typed summary handed to the coordinator after the
// transport-specific receipt validator has checked the full Main manifest.
// The complete wire/document structures remain in the worker's private files.
type CaptureReceipt struct {
	SessionID         string            `json:"session_id"`
	Generation        string            `json:"generation"`
	CaptureConvention CaptureConvention `json:"capture_convention"`
	CaptureProtocol   string            `json:"capture_protocol,omitempty"`
	Epoch             uint32            `json:"epoch,omitempty"`
	PlanSHA256        string            `json:"plan_sha256"`
	CABPayloadCRC32   uint32            `json:"cab_payload_crc32"`
	Images            []ImageReceipt    `json:"images"`
}

type ImageReceipt struct {
	Sequence        uint32 `json:"sequence,omitempty"`
	RequestedFrame  uint32 `json:"requested_frame"`
	ActualFrame     uint32 `json:"actual_frame"`
	Checkpoint      uint32 `json:"checkpoint"`
	Width           uint32 `json:"width"`
	Height          uint32 `json:"height"`
	Pitch           uint32 `json:"pitch"`
	Slot            uint32 `json:"slot"`
	Mode            uint32 `json:"mode"`
	DescriptorCRC32 uint32 `json:"descriptor_crc32"`
	Released        bool   `json:"released"`
	PNGPath         string `json:"png_path"`
	PNGBytes        int64  `json:"png_bytes"`
	PNGComplete     bool   `json:"png_complete"`
}

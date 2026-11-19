/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const captureTargetMarkerName = ".capture-target.json"

type captureTargetMarker struct {
	Target string `json:"target"`
}

func requireLegacySiDi128(config Config) error {
	if config.Target != "" && config.Target != "sidi128" {
		return fmt.Errorf("legacy regression requires config target=sidi128")
	}
	if !config.LegacySiDi128 {
		return fmt.Errorf("legacy SiDi128 capture requires explicit --legacy-sidi128")
	}
	return nil
}

// GuardCaptureTarget claims a previously empty result archive or verifies its
// immutable owner. Callers that can write must hold the shared regression lock.
func GuardCaptureTarget(root, target string) error {
	if target != "sidi128" && target != "mister" {
		return fmt.Errorf("capture target must be sidi128 or mister")
	}
	info, err := os.Lstat(root)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("regression root is not a real directory")
	}
	markerPath := filepath.Join(root, captureTargetMarkerName)
	markerInfo, err := os.Lstat(markerPath)
	if err == nil {
		if !markerInfo.Mode().IsRegular() {
			return fmt.Errorf("capture target marker is not a regular file")
		}
		return RequireCaptureTarget(root, target)
	}
	if !os.IsNotExist(err) {
		return err
	}
	if err = requireEmptyCaptureArchive(root); err != nil {
		return err
	}
	data, err := json.Marshal(captureTargetMarker{Target: target})
	if err != nil {
		return err
	}
	data = append(data, '\n')
	tmp, err := os.CreateTemp(root, ".capture-target-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err = tmp.Chmod(0640); err == nil {
		_, err = tmp.Write(data)
	}
	if err == nil {
		err = tmp.Sync()
	}
	closeErr := tmp.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if err = os.Link(tmpName, markerPath); err != nil {
		if os.IsExist(err) {
			return GuardCaptureTarget(root, target)
		}
		return err
	}
	dir, err := os.Open(root)
	if err != nil {
		return err
	}
	err = dir.Sync()
	closeErr = dir.Close()
	if err != nil {
		return err
	}
	return closeErr
}

// AdoptLegacySiDi128 marks an existing, unmarked archive only after the caller
// has obtained explicit target confirmation and holds the shared archive lock.
// It never changes existing archive data and refuses recognizable MiSTer
// provenance before writing the immutable target marker.
func AdoptLegacySiDi128(root, confirmation string) error {
	if confirmation != "sidi128" {
		return fmt.Errorf("legacy archive adoption requires --confirm-legacy-sidi128 sidi128")
	}
	info, err := os.Lstat(root)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("regression root is not a real directory")
	}
	markerPath := filepath.Join(root, captureTargetMarkerName)
	if _, err = os.Lstat(markerPath); err == nil {
		return fmt.Errorf("archive already has a capture target marker; adoption is only for unmarked archives")
	} else if !os.IsNotExist(err) {
		return err
	}
	if err = validateLegacyArchiveShape(root); err != nil {
		return err
	}
	if err = rejectMiSTerArchiveData(root); err != nil {
		return err
	}
	data, err := json.Marshal(captureTargetMarker{Target: "sidi128"})
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(root, ".capture-target-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err = tmp.Chmod(0640); err == nil {
		_, err = tmp.Write(append(data, '\n'))
	}
	if err == nil {
		err = tmp.Sync()
	}
	closeErr := tmp.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if err = os.Link(tmpName, markerPath); err != nil {
		if os.IsExist(err) {
			return fmt.Errorf("archive target marker appeared during legacy adoption")
		}
		return err
	}
	dir, err := os.Open(root)
	if err != nil {
		return err
	}
	err = dir.Sync()
	closeErr = dir.Close()
	if err != nil {
		return err
	}
	return closeErr
}

func validateLegacyArchiveShape(root string) error {
	entries, err := os.ReadDir(root)
	if err != nil {
		return err
	}
	cores := 0
	for _, entry := range entries {
		if entry.Name() == "log" {
			if entry.Type()&os.ModeSymlink != 0 || !entry.IsDir() {
				return fmt.Errorf("legacy archive log path is not a real directory")
			}
			continue
		}
		if !manualComponent(entry.Name()) || entry.Type()&os.ModeSymlink != 0 || !entry.IsDir() {
			return fmt.Errorf("unmarked archive contains data outside the legacy SiDi128 directory layout")
		}
		cores++
	}
	if cores == 0 {
		return fmt.Errorf("legacy archive adoption requires existing core result directories")
	}
	return nil
}

func rejectMiSTerArchiveData(root string) error {
	return filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("unmarked archive contains a symlink; refusing legacy adoption")
		}
		if entry.IsDir() {
			if strings.EqualFold(entry.Name(), "mister") || strings.HasPrefix(strings.ToLower(entry.Name()), ".mister-") {
				return fmt.Errorf("archive contains MiSTer-specific data; refusing SiDi128 adoption")
			}
			return nil
		}
		if entry.Name() == "reference-provenance.json" {
			return fmt.Errorf("archive contains MiSTer reference provenance; refusing SiDi128 adoption")
		}
		if !strings.HasSuffix(strings.ToLower(entry.Name()), ".json") {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var progress Progress
		if json.Unmarshal(data, &progress) != nil {
			return nil
		}
		for _, lane := range progress.CaptureRuns {
			if lane.Target == "mister" || lane.FinalizationKind == miSTerSerialResultsKind {
				return fmt.Errorf("archive contains MiSTer capture provenance; refusing SiDi128 adoption")
			}
		}
		return nil
	})
}

// RequireCaptureTarget validates an existing immutable archive owner without
// creating or changing the marker. Callers that can write hold the shared lock.
func RequireCaptureTarget(root, target string) error {
	if target != "sidi128" && target != "mister" {
		return fmt.Errorf("capture target must be sidi128 or mister")
	}
	markerPath := filepath.Join(root, captureTargetMarkerName)
	info, err := os.Lstat(markerPath)
	if err != nil {
		return fmt.Errorf("regression archive has no capture target marker: %w", err)
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("capture target marker is not a regular file")
	}
	data, err := os.ReadFile(markerPath)
	if err != nil {
		return err
	}
	var marker captureTargetMarker
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&marker); err != nil {
		return fmt.Errorf("invalid capture target marker: %w", err)
	}
	var trailing any
	if err = decoder.Decode(&trailing); err != io.EOF {
		return fmt.Errorf("invalid capture target marker trailing data")
	}
	if marker.Target != "sidi128" && marker.Target != "mister" {
		return fmt.Errorf("invalid capture target marker target %q", marker.Target)
	}
	if marker.Target != target {
		return fmt.Errorf("regression archive belongs to target=%s, requested target=%s", marker.Target, target)
	}
	return nil
}

// ReadCaptureTarget reports the immutable owner when present. A missing marker
// is distinct from a malformed marker so historical archives can be read
// without making an ownership claim.
func ReadCaptureTarget(root string) (string, bool, error) {
	markerPath := filepath.Join(root, captureTargetMarkerName)
	info, err := os.Lstat(markerPath)
	if os.IsNotExist(err) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	if !info.Mode().IsRegular() {
		return "", false, fmt.Errorf("capture target marker is not a regular file")
	}
	data, err := os.ReadFile(markerPath)
	if err != nil {
		return "", false, err
	}
	var marker captureTargetMarker
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&marker); err != nil {
		return "", false, fmt.Errorf("invalid capture target marker: %w", err)
	}
	var trailing any
	if err = decoder.Decode(&trailing); err != io.EOF {
		return "", false, fmt.Errorf("invalid capture target marker trailing data")
	}
	if marker.Target != "sidi128" && marker.Target != "mister" {
		return "", false, fmt.Errorf("invalid capture target marker target %q", marker.Target)
	}
	return marker.Target, true, nil
}

func requireEmptyCaptureArchive(root string) error {
	entries, err := os.ReadDir(root)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.Name() != "log" || entry.Type()&os.ModeSymlink != 0 || !entry.IsDir() {
			return fmt.Errorf("unmarked regression archive contains prior data; refusing to claim target")
		}
		logDir := filepath.Join(root, "log")
		logEntries, readErr := os.ReadDir(logDir)
		if readErr != nil {
			return readErr
		}
		for _, logEntry := range logEntries {
			if logEntry.Name() != "lock" && logEntry.Name() != "README.md" {
				return fmt.Errorf("unmarked regression archive contains prior data; refusing to claim target")
			}
			logInfo, statErr := os.Lstat(filepath.Join(logDir, logEntry.Name()))
			if statErr != nil {
				return statErr
			}
			if !logInfo.Mode().IsRegular() {
				return fmt.Errorf("unmarked regression archive contains non-structural log data")
			}
		}
	}
	return nil
}

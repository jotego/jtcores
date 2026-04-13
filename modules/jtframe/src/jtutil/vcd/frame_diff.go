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

    Author: Jose Tejada Gomez. Twitter: @topapate */

package vcd

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type FrameDiffOptions struct {
	InputFile string
	Scope     string
	Ref       uint64
	Frames    string
	Keep      bool
	Verbose   bool
}

type frameRow struct {
	idx    int
	values []uint64
}

type frameData struct {
	frame uint64
	rows  []frameRow
}

type frameRange struct {
	start uint64
	end   uint64
	open  bool
}

func RunFrameDiff(opt FrameDiffOptions) error {
	inputFile, cleanupInput, err := resolveFrameDiffInput(opt)
	if err != nil {
		return err
	}
	defer cleanupInput()

	ln, signals := LoadVCD(inputFile)
	defer ln.Close()

	frameSignal := findFrameCountSignal(signals)
	if frameSignal == nil {
		return errors.New("frame_cnt signal not found in VCD")
	}

	scopeRoot, err := resolveFrameDiffScope(signals, opt.Scope)
	if err != nil {
		return err
	}

	selected, err := selectFrameDiffSignals(signals, scopeRoot, opt.Scope)
	if err != nil {
		return err
	}
	if len(selected) == 0 {
		return fmt.Errorf("no signals match %q", opt.Scope)
	}

	frames, err := collectFrameDiffData(ln, signals, frameSignal, selected)
	if err != nil {
		return err
	}

	refFrame, ok := frames[opt.Ref]
	if !ok {
		return fmt.Errorf("reference frame %d is incomplete or not present", opt.Ref)
	}

	ranges, err := parseFrameDiffRanges(opt.Frames, opt.Ref)
	if err != nil {
		return err
	}
	targetFrames := selectFrameDiffFrames(frames, ranges, opt.Ref)
	if len(targetFrames) == 0 {
		return errors.New("no complete comparison frames found")
	}

	colNames := frameDiffColumnNames(selected, scopeRoot)
	refPath := "ref-frame.vcd"
	comparePath := ""
	if err := writeFrameDiffCSV(refPath, colNames, selected, refFrame); err != nil {
		return err
	}
	if !opt.Keep {
		defer os.Remove(refPath)
	}

	var lastCompare string
	for _, frame := range targetFrames {
		if frame == opt.Ref {
			continue
		}
		data, ok := frames[frame]
		if !ok {
			continue
		}
		if comparePath != "" {
			_ = os.Remove(comparePath)
		}
		comparePath = fmt.Sprintf("frame-%d.vcd", frame)
		if err := writeFrameDiffCSV(comparePath, colNames, selected, data); err != nil {
			return err
		}
		lastCompare = comparePath

		out, diffFound, err := runSdiff(refPath, comparePath)
		if err != nil {
			return err
		}
		if len(out) != 0 {
			fmt.Print(limitFrameDiffOutput(out, opt.Verbose))
		}
		if diffFound {
			printFrameDiffMismatch(opt.Ref, frame, colNames, selected, refFrame, data)
			break
		}
	}

	if opt.Keep {
		if lastCompare != "" {
			fmt.Printf("Keeping %s and %s\n", refPath, lastCompare)
		} else {
			fmt.Printf("Keeping %s\n", refPath)
		}
	} else if comparePath != "" {
		defer os.Remove(comparePath)
	}

	return nil
}

func resolveFrameDiffInput(opt FrameDiffOptions) (string, func(), error) {
	input := opt.InputFile
	if input == "" {
		input = "test.fst"
	}
	ext := strings.ToLower(filepath.Ext(input))
	switch ext {
	case ".vcd":
		return input, func() {}, nil
	case ".fst":
		output := strings.TrimSuffix(input, ext) + ".vcd"
		inputInfo, err := os.Stat(input)
		if err != nil {
			return "", nil, err
		}
		if outputInfo, err := os.Stat(output); err == nil && !inputInfo.ModTime().After(outputInfo.ModTime()) {
			return output, func() {}, nil
		}
		if opt.Verbose {
			fmt.Printf("Starting vcd2fst conversion: %s -> %s\n", input, output)
		}
		cmd := exec.Command("fst2vcd", "-o", output, input)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return "", nil, err
		}
		return output, func() {}, nil
	default:
		return "", nil, fmt.Errorf("unsupported input type %q", input)
	}
}

func findFrameCountSignal(ss VCDData) *VCDSignal {
	all := ss.GetAll("frame_cnt", false)
	if len(all) == 0 {
		return nil
	}
	if len(all) == 1 {
		return all[0]
	}
	for _, each := range all {
		if strings.Contains(each.Scope, "game_test") {
			return each
		}
	}
	sort.Slice(all, func(i, j int) bool {
		return strings.Compare(all[i].FullName(), all[j].FullName()) < 0
	})
	return all[0]
}

func resolveFrameDiffScope(ss VCDData, scope string) (string, error) {
	scopePattern, _, err := splitFrameDiffPattern(scope)
	if err != nil {
		return "", err
	}
	if scopePattern == "" {
		return "", errors.New("scope pattern is required")
	}
	candidates := frameDiffScopeCandidates(ss, scopePattern)
	if len(candidates) == 0 {
		return "", fmt.Errorf("cannot find any instance matching %q", scopePattern)
	}
	if len(candidates) > 1 {
		fmt.Printf("More than one instance matches %q:\n", scopePattern)
		for _, each := range candidates {
			fmt.Printf("  %s\n", each)
		}
		return "", fmt.Errorf("scope pattern %q is ambiguous", scopePattern)
	}
	return candidates[0], nil
}

func frameDiffScopeCandidates(ss VCDData, scope string) []string {
	pattern := splitFrameDiffScopePattern(scope)
	if len(pattern) == 0 {
		return nil
	}
	candidates := make(map[string]bool)
	for _, sig := range ss {
		segments := strings.Split(sig.Scope, ".")
		for idx := range segments {
			if idx+len(pattern) > len(segments) {
				break
			}
			matched := true
			for off, token := range pattern {
				if segments[idx+off] != token {
					matched = false
					break
				}
			}
			if matched {
				candidate := strings.Join(segments[:idx+len(pattern)], ".")
				candidates[candidate] = true
			}
		}
	}
	out := make([]string, 0, len(candidates))
	for candidate := range candidates {
		out = append(out, candidate)
	}
	sort.Slice(out, func(i, j int) bool {
		return strings.Compare(out[i], out[j]) < 0
	})
	return out
}

func splitFrameDiffScopePattern(scope string) []string {
	parts := strings.FieldsFunc(scope, func(r rune) bool {
		return r == '/' || r == '.'
	})
	filtered := parts[:0]
	for _, part := range parts {
		if part != "" {
			filtered = append(filtered, part)
		}
	}
	return filtered
}

func selectFrameDiffSignals(ss VCDData, scopeRoot string, scopeArg string) ([]*VCDSignal, error) {
	_, signalPattern, err := splitFrameDiffPattern(scopeArg)
	if err != nil {
		return nil, err
	}
	patterns := expandFrameDiffBraces(signalPattern)
	matches := make([]*VCDSignal, 0, len(ss))
	for _, sig := range ss {
		if sig.Name == "frame_cnt" {
			continue
		}
		if scopeRoot != "" {
			if sig.Scope != scopeRoot && !strings.HasPrefix(sig.Scope, scopeRoot+".") {
				continue
			}
		}
		for _, pat := range patterns {
			ok, err := filepath.Match(pat, sig.Name)
			if err != nil {
				return nil, err
			}
			if ok {
				matches = append(matches, sig)
				break
			}
		}
	}
	sort.Slice(matches, func(i, j int) bool {
		return strings.Compare(matches[i].FullName(), matches[j].FullName()) < 0
	})
	return matches, nil
}

func splitFrameDiffPattern(pattern string) (string, string, error) {
	first := strings.Index(pattern, "/")
	if first == -1 {
		return pattern, "*", nil
	}
	if strings.LastIndex(pattern, "/") != first {
		return "", "", fmt.Errorf("scope %q may contain at most one / separator", pattern)
	}
	return pattern[:first], pattern[first+1:], nil
}

func expandFrameDiffBraces(pattern string) []string {
	if pattern == "" {
		return []string{pattern}
	}
	start := -1
	depth := 0
	for i, r := range pattern {
		switch r {
		case '{':
			if depth == 0 && start == -1 {
				start = i
			}
			depth++
		case '}':
			if depth == 0 {
				return []string{pattern}
			}
			depth--
			if depth == 0 && start != -1 {
				prefix := pattern[:start]
				body := pattern[start+1 : i]
				suffix := pattern[i+1:]
				parts := splitFrameDiffBraceItems(body)
				out := make([]string, 0, len(parts))
				for _, part := range parts {
					out = append(out, expandFrameDiffBraces(prefix+part+suffix)...)
				}
				return out
			}
		}
	}
	return []string{pattern}
}

func splitFrameDiffBraceItems(body string) []string {
	if body == "" {
		return []string{""}
	}
	depth := 0
	start := 0
	items := make([]string, 0, 2)
	for i, r := range body {
		switch r {
		case '{':
			depth++
		case '}':
			if depth > 0 {
				depth--
			}
		case ',':
			if depth == 0 {
				items = append(items, body[start:i])
				start = i + 1
			}
		}
	}
	items = append(items, body[start:])
	return items
}

func collectFrameDiffData(file *LnFile, ss VCDData, frameSig *VCDSignal, selected []*VCDSignal) (map[uint64]*frameData, error) {
	frameRows := make(map[uint64]*frameData)
	currentFrame := frameSig.Value
	current := newFrameDiffFrameData(currentFrame, selected)
	lastValues := frameDiffSnapshot(selected)

	for file.NextVCD(ss) {
		values := frameDiffSnapshot(selected)
		nextFrame := frameSig.Value
		if nextFrame != currentFrame {
			frameRows[currentFrame] = current
			currentFrame = nextFrame
			current = newFrameDiffFrameData(currentFrame, selected)
			lastValues = values
			continue
		}
		if !frameDiffValuesEqual(lastValues, values) {
			current.rows = append(current.rows, frameRow{
				idx:    len(current.rows),
				values: values,
			})
			lastValues = values
		}
	}
	return frameRows, nil
}

func newFrameDiffFrameData(frame uint64, selected []*VCDSignal) *frameData {
	return &frameData{
		frame: frame,
		rows: []frameRow{
			{
				idx:    0,
				values: frameDiffSnapshot(selected),
			},
		},
	}
}

func frameDiffSnapshot(selected []*VCDSignal) []uint64 {
	values := make([]uint64, len(selected))
	for i, sig := range selected {
		values[i] = sig.FullValue()
	}
	return values
}

func frameDiffValuesEqual(a, b []uint64) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func parseFrameDiffRanges(spec string, ref uint64) ([]frameRange, error) {
	if strings.TrimSpace(spec) == "" {
		next := ref + 1
		return []frameRange{{start: next, end: next}}, nil
	}
	parts := strings.Split(spec, ",")
	ranges := make([]frameRange, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if !strings.Contains(part, "-") {
			value, err := strconv.ParseUint(part, 10, 64)
			if err != nil {
				return nil, err
			}
			ranges = append(ranges, frameRange{start: value, end: value})
			continue
		}
		tokens := strings.SplitN(part, "-", 2)
		start, err := strconv.ParseUint(strings.TrimSpace(tokens[0]), 10, 64)
		if err != nil {
			return nil, err
		}
		r := frameRange{start: start}
		if strings.TrimSpace(tokens[1]) == "" {
			r.open = true
		} else {
			end, err := strconv.ParseUint(strings.TrimSpace(tokens[1]), 10, 64)
			if err != nil {
				return nil, err
			}
			if end < start {
				return nil, fmt.Errorf("invalid frame range %q", part)
			}
			r.end = end
		}
		ranges = append(ranges, r)
	}
	if len(ranges) == 0 {
		next := ref + 1
		return []frameRange{{start: next, end: next}}, nil
	}
	return ranges, nil
}

func selectFrameDiffFrames(frames map[uint64]*frameData, ranges []frameRange, ref uint64) []uint64 {
	available := make([]uint64, 0, len(frames))
	for frame := range frames {
		available = append(available, frame)
	}
	sort.Slice(available, func(i, j int) bool { return available[i] < available[j] })

	if len(ranges) == 0 {
		next := ref + 1
		ranges = []frameRange{{start: next, end: next}}
	}

	selected := make(map[uint64]bool)
	for _, rg := range ranges {
		for _, frame := range available {
			if frame < rg.start {
				continue
			}
			if !rg.open && frame > rg.end {
				continue
			}
			selected[frame] = true
		}
	}
	out := make([]uint64, 0, len(selected))
	for frame := range selected {
		if frame != ref {
			out = append(out, frame)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

func frameDiffColumnNames(selected []*VCDSignal, scopeRoot string) []string {
	raw := make([]string, len(selected))
	counts := make(map[string]int)
	for i, sig := range selected {
		raw[i] = frameDiffDisplayName(sig, scopeRoot)
		counts[raw[i]]++
	}
	names := make([]string, len(selected))
	for i, sig := range selected {
		name := raw[i]
		if counts[name] == 1 {
			names[i] = name
			continue
		}
		rel := strings.TrimPrefix(sig.Scope, scopeRoot)
		rel = strings.TrimPrefix(rel, ".")
		if rel != "" {
			names[i] = strings.ReplaceAll(rel, ".", "/") + "/" + sig.Name
			continue
		}
		names[i] = fmt.Sprintf("%s_%d", name, i)
	}
	return names
}

func frameDiffDisplayName(sig *VCDSignal, scopeRoot string) string {
	name := sig.Name
	if scopeRoot == "" {
		return name
	}
	if sig.Scope == scopeRoot {
		return name
	}
	rel := strings.TrimPrefix(sig.Scope, scopeRoot+".")
	if rel == "" {
		return name
	}
	return strings.ReplaceAll(rel, ".", "/") + "/" + sig.Name
}

func writeFrameDiffCSV(path string, headers []string, selected []*VCDSignal, data *frameData) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	if _, err := fmt.Fprint(f, "#"); err != nil {
		return err
	}
	for _, header := range headers {
		if _, err := fmt.Fprintf(f, ",%s", header); err != nil {
			return err
		}
	}
	if _, err := fmt.Fprintln(f); err != nil {
		return err
	}
	for _, row := range data.rows {
		if _, err := fmt.Fprintf(f, "%d", row.idx); err != nil {
			return err
		}
		for i, value := range row.values {
			width := frameDiffSignalDigits(selected[i])
			if _, err := fmt.Fprintf(f, ",%0*X", width, value); err != nil {
				return err
			}
		}
		if _, err := fmt.Fprintln(f); err != nil {
			return err
		}
	}
	return nil
}

func frameDiffSignalDigits(sig *VCDSignal) int {
	bits := sig.MSB - sig.LSB + 1
	if bits <= 0 {
		return 1
	}
	digits := (bits + 3) / 4
	if digits < 1 {
		digits = 1
	}
	return digits
}

func runSdiff(refPath, comparePath string) (string, bool, error) {
	cmd := exec.Command("sdiff", "-s", refPath, comparePath)
	out, err := cmd.CombinedOutput()
	if err == nil {
		return string(out), false, nil
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		if exitErr.ExitCode() == 1 {
			return string(out), true, nil
		}
	}
	return string(out), false, err
}

func limitFrameDiffOutput(out string, verbose bool) string {
	if verbose {
		return out
	}
	lines := strings.Split(strings.TrimRight(out, "\n"), "\n")
	if len(lines) <= 10 {
		return out
	}
	var sb strings.Builder
	for i := 0; i < 10; i++ {
		sb.WriteString(lines[i])
		sb.WriteByte('\n')
	}
	sb.WriteString("...\n")
	return sb.String()
}

func printFrameDiffMismatch(refFrame, compareFrame uint64, headers []string, selected []*VCDSignal, ref, compare *frameData) {
	idx, refRow, cmpRow, ok := findFirstFrameDiffRow(ref, compare)
	if !ok {
		return
	}
	fmt.Printf("Frame   #")
	for _, header := range headers {
		fmt.Printf("    %s", header)
	}
	fmt.Println()
	printFrameDiffRow(refFrame, idx, headers, selected, refRow)
	printFrameDiffRow(compareFrame, idx, headers, selected, cmpRow)
}

func findFirstFrameDiffRow(ref, compare *frameData) (int, []uint64, []uint64, bool) {
	limit := len(ref.rows)
	if len(compare.rows) < limit {
		limit = len(compare.rows)
	}
	for i := 0; i < limit; i++ {
		if !frameDiffValuesEqual(ref.rows[i].values, compare.rows[i].values) {
			return i, ref.rows[i].values, compare.rows[i].values, true
		}
	}
	if len(ref.rows) != len(compare.rows) {
		if len(ref.rows) > len(compare.rows) {
			return len(compare.rows), ref.rows[len(compare.rows)].values, nil, true
		}
		return len(ref.rows), nil, compare.rows[len(ref.rows)].values, true
	}
	return 0, nil, nil, false
}

func printFrameDiffRow(frame uint64, idx int, headers []string, selected []*VCDSignal, values []uint64) {
	fmt.Printf("%-7d %-4d", frame, idx)
	for i, header := range headers {
		if values == nil || i >= len(values) {
			fmt.Printf(" %-*s", len(header), "-")
			continue
		}
		raw := fmt.Sprintf("%0*X", frameDiffSignalDigits(selected[i]), values[i])
		fmt.Printf(" %-*s", maxInt(len(header), len(raw)), raw)
	}
	fmt.Println()
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

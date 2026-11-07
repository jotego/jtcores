// Fixed EG observation frontend. Raw transport and conditioning audits remain separate.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
)

func main() {
	geometryFile := flag.String("geometries", "", "optional exact five-geometry catalog; default built-in frozen preset")
	geometryName := flag.String("geometry", "", "exact catalog geometry")
	profile := flag.String("profile", "", "carrier, attack, or live")
	input := flag.String("input", "", "whole original public linear CSV")
	output := flag.String("output", "", "new exclusive report")
	curve := flag.String("curve", "", "new exclusive whole-trace projection CSV")
	exportGeometry := flag.String("export-geometries", "", "exclusive metadata-only export of the frozen five-geometry catalog")
	flag.Parse()
	if *exportGeometry != "" {
		if *geometryFile!="" || *geometryName!="" || *profile!="" || *input!="" || *output!="" || *curve!="" || flag.NArg()!=0 { fmt.Fprintln(os.Stderr,"metadata export accepts only -export-geometries");os.Exit(1) }
		f,e:=os.OpenFile(*exportGeometry,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if e!=nil{fmt.Fprintln(os.Stderr,e);os.Exit(1)};_,e=f.WriteString(eg_geometry_json);closeError:=f.Close();if e!=nil||closeError!=nil{fmt.Fprintln(os.Stderr,"geometry export failed",e,closeError);os.Exit(1)};return
	}
	if err := physical_features(*geometryFile, *geometryName, *profile, *input, *output, *curve); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func physical_features(geometryFile, geometryName, profile, input, output, curve string) error {
	if flag.NArg() != 0 || geometryName == "" || input == "" || output == "" || curve == "" || (profile != "carrier" && profile != "attack" && profile != "live") {
		return fmt.Errorf("exact geometry, profile, input, output and curve required")
	}
	if output == curve || input == output || input == curve {
		return fmt.Errorf("distinct input/output/curve required")
	}
	for _, p := range []string{output, curve} {
		if _, e := os.Lstat(p); !os.IsNotExist(e) {
			return fmt.Errorf("output already exists or cannot be inspected: %s", p)
		}
	}
	catalog:=[]byte(eg_geometry_json)
	var e error
	if geometryFile!="" { catalog,e=os.ReadFile(geometryFile);if e!=nil{return e} }
	if fmt.Sprintf("%x", sha256.Sum256(catalog)) != "0c2a75b519f377da97295ee10011961e7f1470d7f6ae38ea3345d6f094a4b42c" {
		return fmt.Errorf("frozen geometry catalog SHA differs")
	}
	var gs []geometry
	if e = json.Unmarshal(catalog, &gs); e != nil {
		return e
	}
	var g geometry
	found := false
	for _, v := range gs {
		if v.Name == geometryName {
			g = v
			found = true
		}
	}
	if len(gs) != 5 || !found {
		return fmt.Errorf("unknown frozen geometry")
	}
	raw, e := os.ReadFile(input)
	if e != nil {
		return e
	}
	values, e := physical_read_csv(raw)
	if e != nil {
		return e
	}
	if len(values) != g.Frames {
		return fmt.Errorf("wrong frame count for geometry")
	}
	low, high := math.Inf(1), math.Inf(-1)
	for _, v := range values {
		low = math.Min(low, v)
		high = math.Max(high, v)
	}
	envelope, e := measure_envelope(values, g.Recorded, g.Fs, g.Window, g.Hop)
	if e != nil {
		return e
	}
	observation := map[string]interface{}{"envelope": envelope}
	// These call original methods directly; no generic truth/error/projection() path.
	if profile == "carrier" {
		carrierObservation, _ := carrier(fixture{Values: values, Low: low, High: high}, g)
		observation["carrier"] = carrierObservation
	}
	if profile == "live" || profile == "carrier" {
		decay, e := measure_decay(decay_points(envelope), g.Fs, g.Window, amp, false)
		if e != nil {
			return e
		}
		observation["decay"] = decay
	}
	support := g.Window + 3*g.Hop
	silent := true
	for _, v := range values[:support] {
		if v != 0 {
			silent = false
		}
	}
	// Quality fields on early-return results remain descriptive; never infer quality from zero defaults.
	plateauEvaluated := envelope.Plateau >= 32 && (envelope.State == "measured" || envelope.State == "no_pretrigger" || envelope.State == "no_attack_crossings")
	plateauAbsolute := plateauEvaluated && math.Abs(envelope.Plateau/amp-1) <= .01
	result := map[string]interface{}{"state": "original_methods_observations_no_chip_conformance", "input": input, "input_sha256": fmt.Sprintf("%x", sha256.Sum256(raw)), "geometry": g, "profile": profile, "whole_original_trace": true, "minimum_pcm": low, "maximum_pcm": high, "exactzero": low == 0 && high == 0, "initial_support_samples": support, "initial_support_exactzero": silent, "initial_support_bipolar": physical_bipolar(values[:support]), "plateau_quality_evaluated": plateauEvaluated, "absolute_plateau_within_one_percent": plateauAbsolute, "observation": observation, "no_generic_truth_or_signal_error": true}
	if e = write_envelope(curve, envelope.points); e != nil {
		return e
	}
	result["curve"] = curve
	curveRaw, e := os.ReadFile(curve)
	if e != nil {
		return e
	}
	result["curve_sha256"] = fmt.Sprintf("%x", sha256.Sum256(curveRaw))
	f, e := os.OpenFile(output, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if e != nil {
		return e
	}
	enc := json.NewEncoder(f)
	enc.SetIndent("", "  ")
	e = enc.Encode(result)
	closeError := f.Close()
	if e != nil {
		return e
	}
	if closeError != nil {
		return closeError
	}
	fmt.Println(filepath.Clean(output))
	return nil
}

func physical_bipolar(v []float64) bool {
	negative, positive := false, false
	for _, x := range v {
		negative = negative || x < 0
		positive = positive || x > 0
	}
	return negative && positive
}

func physical_read_csv(raw []byte) ([]float64, error) {
	rows, e := csv.NewReader(bytes.NewReader(raw)).ReadAll()
	if e != nil {
		return nil, e
	}
	if len(rows) < 2 {
		return nil, fmt.Errorf("empty CSV")
	}
	headers := rows[0]
	linear := 1
	if len(headers) == 2 && headers[0] == "sample" && headers[1] == "linear" {
	} else if len(headers) == 3 && headers[0] == "sample" && headers[1] == "raw16_hex" && headers[2] == "linear" {
		linear = 2
	} else {
		return nil, fmt.Errorf("strict sample,[raw16_hex,]linear CSV required")
	}
	values := make([]float64, 0, len(rows)-1)
	for i, row := range rows[1:] {
		if len(row) != len(headers) {
			return nil, fmt.Errorf("row width")
		}
		index, e := strconv.Atoi(row[0])
		if e != nil || index != i {
			return nil, fmt.Errorf("consecutive retained index required")
		}
		v, e := strconv.ParseInt(row[linear], 10, 32)
		if e != nil {
			return nil, fmt.Errorf("integral PCM required")
		}
		if linear == 2 {
			if _, e := strconv.ParseUint(row[1], 16, 16); e != nil {
				return nil, fmt.Errorf("raw16 syntax")
			}
		}
		values = append(values, float64(v))
	}
	return values, nil
}

// Metadata only: identical bytes/SHA to the qualified five-geometry catalog.
const eg_geometry_json=`[
  {
    "name": "native-kc3e-mul8",
    "kc": 62,
    "mul": 8,
    "native_increment": 39232,
    "stride": 1,
    "frames": 16384,
    "window": 64,
    "hop": 8,
    "pretrigger_count": 256,
    "carrier_guard": "phase_rounded_expected_and_rms_lt_.01",
    "recorded_increment": 39232,
    "sample_rate_hz": 55937.5,
    "native_frames": 16384,
    "nominal_record_seconds": 0.2928983240223464,
    "window_ms": 1.1441340782122906,
    "nominal_cycles_per_window": 2.39453125,
    "first_four_projection_support_end": 88
  },
  {
    "name": "native-kc40-mul8",
    "kc": 64,
    "mul": 8,
    "native_increment": 41568,
    "stride": 1,
    "frames": 16384,
    "window": 64,
    "hop": 8,
    "pretrigger_count": 256,
    "carrier_guard": "phase_rounded_expected_and_rms_lt_.01",
    "recorded_increment": 41568,
    "sample_rate_hz": 55937.5,
    "native_frames": 16384,
    "nominal_record_seconds": 0.2928983240223464,
    "window_ms": 1.1441340782122906,
    "nominal_cycles_per_window": 2.537109375,
    "first_four_projection_support_end": 88
  },
  {
    "name": "native-kc41-mul8",
    "kc": 65,
    "mul": 8,
    "native_increment": 44032,
    "stride": 1,
    "frames": 16384,
    "window": 64,
    "hop": 8,
    "pretrigger_count": 256,
    "carrier_guard": "phase_rounded_expected_and_rms_lt_.01",
    "recorded_increment": 44032,
    "sample_rate_hz": 55937.5,
    "native_frames": 16384,
    "nominal_record_seconds": 0.2928983240223464,
    "window_ms": 1.1441340782122906,
    "nominal_cycles_per_window": 2.6875,
    "first_four_projection_support_end": 88
  },
  {
    "name": "stride16-kc40-mul0",
    "kc": 64,
    "mul": 0,
    "native_increment": 2598,
    "stride": 16,
    "frames": 4096,
    "window": 64,
    "hop": 8,
    "pretrigger_count": 4096,
    "carrier_guard": "phase_rounded_expected_and_rms_lt_.01",
    "recorded_increment": 41568,
    "sample_rate_hz": 3496.09375,
    "native_frames": 65536,
    "nominal_record_seconds": 1.1715932960893856,
    "window_ms": 18.30614525139665,
    "nominal_cycles_per_window": 2.537109375,
    "first_four_projection_support_end": 88
  },
  {
    "name": "stride64-kc40-mul0",
    "kc": 64,
    "mul": 0,
    "native_increment": 2598,
    "stride": 64,
    "frames": 16384,
    "window": 32,
    "hop": 8,
    "pretrigger_count": 8192,
    "carrier_guard": "free_sine_abs_increment_error_lt_.1_relativePCM_RMS_lt_.003_and_integer_crossing_bracket",
    "recorded_increment": 166272,
    "sample_rate_hz": 874.0234375,
    "native_frames": 1048576,
    "nominal_record_seconds": 18.74549273743017,
    "window_ms": 36.6122905027933,
    "nominal_cycles_per_window": 5.07421875,
    "first_four_projection_support_end": 56
  }
]
`

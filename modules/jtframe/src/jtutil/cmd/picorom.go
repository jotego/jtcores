/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package cmd

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"os/signal"
	"syscall"
	"text/tabwriter"
	"time"

	"github.com/spf13/cobra"
	"golang.org/x/term"
	"jtutil/picorom"
	"jtutil/picorom/bustest"
)

var picorom_args struct {
	json, yes, dry_run, bench, xgecu bool
	lab, size, out, run              string
	units                            []string
	timeout, stall, seconds, every   time.Duration
	length                           int
}

// Exit codes: 0 done, 1 error, 3 the PCB run did not complete
const picorom_incomplete = 3

var picoromCmd = &cobra.Command{
	Use:   "picorom",
	Short: "PicoROM-based PCB work: load, verify, probe, power and bus tests",
	Long: man_blurb("jtutil-picorom", `PicoROM-based PCB work. Lab settings (units, power switch, programmer)
come from $JOTEGO/picorom.yaml; per-core tests from cores/<core>/cfg/picorom.yaml.
Every command accepts --json for machine-readable output.`),
	Example: `  jtutil picorom units
  jtutil picorom load unit1=even.bin unit2=odd.bin --size 64k
  jtutil picorom power status
  jtutil picorom bustest show riders glfgreat
  jtutil picorom bustest sim riders glfgreat
  jtutil picorom bustest run riders glfgreat`,
}

func init() {
	rootCmd.AddCommand(picoromCmd)
	pf := picoromCmd.PersistentFlags()
	pf.BoolVar(&picorom_args.json, "json", false, "machine-readable output")
	pf.StringVar(&picorom_args.lab, "lab", "", "lab configuration (default $JOTEGO/picorom.yaml)")
	add_picorom_cmd(&cobra.Command{Use: "units", Short: "List connected PicoROMs and what the lab knows about them",
		Args: cobra.NoArgs, RunE: run_picorom_units})
	load := add_picorom_cmd(&cobra.Command{Use: "load NAME=IMAGE...", Short: "Load images and verify them with a full readback",
		Long: `Load images into PicoROM units and read every byte back over USB.
The PCB must be off: with a power switch in the lab file, this is checked.`,
		Example: "  jtutil picorom load unit1=even_lane.bin unit2=odd_lane.bin --size 64k",
		Args: cobra.MinimumNArgs(1), RunE: run_picorom_load})
	load.Flags().StringVar(&picorom_args.size, "size", "128k", "ROM window: "+picorom.SizeNames())
	load.Flags().BoolVar(&picorom_args.xgecu, "xgecu", false, "also read the unit through the XGecu programmer socket (one unit)")
	load.Flags().BoolVar(&picorom_args.bench, "bench", false, "skip the power check: no unit is plugged into a PCB")
	load.Flags().BoolVar(&picorom_args.yes, "yes", false, "confirm that the PCB is off when power cannot be checked")
	load.Flags().StringVar(&picorom_args.out, "out", "", "report folder (default picorom-load-<utc>)")
	read := add_picorom_cmd(&cobra.Command{Use: "read NAME FILE", Short: "Save the unit's current image",
		Args: cobra.ExactArgs(2), RunE: run_picorom_read})
	read.Flags().IntVar(&picorom_args.length, "length", 0, "bytes to read (default: the unit's address window)")
	add_picorom_cmd(&cobra.Command{Use: "rename OLD NEW", Short: "Rename a unit (kept in its flash; it reconnects to USB)",
		Args: cobra.ExactArgs(2), RunE: run_picorom_rename})
	probe := add_picorom_cmd(&cobra.Command{Use: "probe NAME", Short: "Power the PCB briefly and sample the unit's pins",
		Long: `Power the PCB for a bounded time and sample the address, /CE and /OE pins of
a unit with the diagnostic firmware. Use it when a test sees no markers.`,
		Args: cobra.ExactArgs(1), RunE: run_picorom_probe})
	probe.Flags().DurationVar(&picorom_args.seconds, "seconds", 8*time.Second, "powered time (1s-10s)")
	probe.Flags().DurationVar(&picorom_args.every, "interval", 50*time.Millisecond, "sampling interval")
	probe.Flags().StringVar(&picorom_args.out, "out", "", "also write the samples to this JSON file")
	add_picorom_cmd(&cobra.Command{Use: "power status|on|off", Short: "Read or switch the PCB power",
		Args: cobra.ExactArgs(1), ValidArgs: []string{"status", "on", "off"}, RunE: run_picorom_power})
	add_bustest_cmds()
}

func add_picorom_cmd(c *cobra.Command) *cobra.Command {
	c.SilenceUsage = true
	picoromCmd.AddCommand(c)
	return c
}

func add_bustest_cmds() {
	bt := &cobra.Command{Use: "bustest", Short: "Time CPU bus accesses on a PCB and in jtsim with the same program",
		Long: `Bus timing tests. The test for <core> <set> is defined in cores/<core>/cfg/picorom.yaml
and its files go to cores/<core>/ver/<set>_bustest/ (ignored by Git).
Typical order: show, gen, sim, run, report.`}
	picoromCmd.AddCommand(bt)
	sub := func(c *cobra.Command) *cobra.Command {
		c.Args, c.SilenceUsage = cobra.RangeArgs(1, 2), true
		bt.AddCommand(c)
		return c
	}
	sub(&cobra.Command{Use: "show <core> [set]", Short: "Describe the test (or list the core's sets)", RunE: run_bustest_show})
	sub(&cobra.Command{Use: "gen <core> <set>", Short: "Generate the program and ROM images", RunE: run_bustest_gen})
	sub(&cobra.Command{Use: "sim <core> <set>", Short: "Run the program in jtsim", RunE: run_bustest_sim})
	run := sub(&cobra.Command{Use: "run <core> <set>", Short: "Run the program on the PCB",
		Long: `Run the test on the PCB. The plan and checklist are printed first and must be
confirmed at the terminal, or with --yes once the board is ready.`, RunE: run_bustest_run})
	run.Flags().BoolVar(&picorom_args.yes, "yes", false, "the board is set up as printed: do not ask")
	run.Flags().BoolVar(&picorom_args.dry_run, "dry-run", false, "print the plan only")
	run.Flags().DurationVar(&picorom_args.timeout, "timeout", 30*time.Second, "maximum powered time")
	run.Flags().DurationVar(&picorom_args.stall, "stall-probe", 2*time.Second, "sample the recorder pins when markers stop for this long (0: off)")
	run.Flags().StringSliceVar(&picorom_args.units, "unit", nil, "lane=NAME: use this unit for a lane (even, odd or rom)")
	rep := sub(&cobra.Command{Use: "report <core> <set>", Short: "Compare the latest PCB run with jtsim", RunE: run_bustest_report})
	rep.Flags().StringVar(&picorom_args.run, "run", "", "PCB run folder (default: the latest)")
}

func load_lab() (*picorom.Lab, error) {
	path := picorom_args.lab
	if path == "" {
		var e error
		path, e = picorom.DefaultLabPath(); if e != nil { return nil, e }
	}
	return picorom.LoadLab(path)
}

func load_lab_power() (*picorom.Lab, picorom.Power, error) {
	lab, e := load_lab(); if e != nil { return nil, nil, e }
	p, e := picorom.NewPower(lab)
	return lab, p, e
}

func print_json(v any) error {
	js, e := json.MarshalIndent(v, "", "  "); if e != nil { return e }
	fmt.Println(string(js))
	return nil
}

func run_picorom_units(cmd *cobra.Command, args []string) error {
	lab, e := load_lab(); if e != nil { return e }
	units, e := picorom.Units(lab); if e != nil { return e }
	if picorom_args.json { return print_json(units) }
	if len(units) == 0 { fmt.Println("No PicoROM connected"); return nil }
	w := tabwriter.NewWriter(os.Stdout, 0, 2, 2, ' ', 0)
	fmt.Fprintln(w, "NAME\tSERIAL\tBUILD\tDIAG\tMASK\tRECORDER\tLAB")
	for _, u := range units {
		note := "not in the lab file"
		if u.Lab != nil {
			note = u.Lab.Note
			if u.Lab.Disabled != "" { note = "DISABLED: " + u.Lab.Disabled }
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%v\t%s\n", u.Name, u.Serial, u.BuildConfig, dash(u.Diag), u.AddrMask, u.Recorder, note)
	}
	return w.Flush()
}

func dash(s string) string {
	if s == "" { return "-" }
	return s
}

func run_picorom_load(cmd *cobra.Command, args []string) error {
	lab, power, e := load_lab_power(); if e != nil { return e }
	if !picorom_args.bench {
		e = require_off(power); if e != nil { return e }
	}
	var jobs []picorom.LoadJob
	for _, a := range args {
		name, path, ok := strings.Cut(a, "="); if !ok { return fmt.Errorf("expected NAME=IMAGE, got %q", a) }
		jobs = append(jobs, picorom.LoadJob{Name: name, Path: path})
	}
	out := picorom_args.out
	if out == "" { out = "picorom-load-" + time.Now().UTC().Format("20060102T150405Z") }
	rep, e := picorom.LoadImages(lab, jobs, picorom_args.size, out, picorom_args.xgecu); if e != nil { return e }
	if picorom_args.json { print_json(rep) } else {
		for _, r := range rep.Units {
			x := ""
			if r.XgecuMismatch != nil { x = fmt.Sprintf("  xgecu %d bytes differ", *r.XgecuMismatch) }
			fmt.Printf("%s: image %.12s  usb %s%s\n", r.Name, r.ImageSha, ok_str(r.UsbMatch), x)
		}
		fmt.Println("Report:", filepath.Join(out, "report.json"))
	}
	if !rep.Ok { return errors.New("verification failed") }
	return nil
}

func ok_str(ok bool) string {
	if ok { return "OK" }
	return "MISMATCH"
}

// require_off checks the PCB is off, or asks when power cannot be read
func require_off(power picorom.Power) error {
	st, e := power.Status(); if e != nil { return e }
	if st.On != nil {
		if *st.On { return fmt.Errorf("PCB power is on (%s): switch it off first", power.Describe()) }
		return nil
	}
	if picorom_args.yes { return nil }
	return confirm("PCB power cannot be checked. Is the PCB off?")
}

func confirm(question string) error {
	if !term.IsTerminal(int(os.Stdin.Fd())) { return fmt.Errorf("%s Answer with --yes (no terminal to ask)", question) }
	fmt.Fprintf(os.Stderr, "%s Type yes to continue: ", question)
	line, _ := bufio.NewReader(os.Stdin).ReadString('\n')
	if strings.TrimSpace(line) != "yes" { return errors.New("cancelled") }
	return nil
}

func run_picorom_read(cmd *cobra.Command, args []string) error {
	lab, e := load_lab(); if e != nil { return e }
	n := picorom_args.length
	if n == 0 {
		u, e := picorom.FindUnit(lab, args[0]); if e != nil { return e }
		var mask int
		fmt.Sscanf(u.AddrMask, "0x%x", &mask)
		n = mask + 1
	}
	data, e := picorom.Download(args[0], n); if e != nil { return e }
	e = os.WriteFile(args[1], data, 0o664); if e != nil { return e }
	if picorom_args.json { return print_json(map[string]any{"file": args[1], "bytes": len(data), "sha256": picorom.Sha(data)}) }
	fmt.Printf("%s: %d bytes, sha256 %s\n", args[1], len(data), picorom.Sha(data))
	return nil
}

func run_picorom_rename(cmd *cobra.Command, args []string) error {
	e := picorom.Rename(args[0], args[1]); if e != nil { return e }
	if picorom_args.json { return print_json(map[string]string{"old": args[0], "new": args[1]}) }
	fmt.Printf("Renamed %s to %s. If it does not reappear on USB, replug its cable.\n", args[0], args[1])
	return nil
}

func run_picorom_probe(cmd *cobra.Command, args []string) error {
	if picorom_args.seconds < time.Second || picorom_args.seconds > 10*time.Second { return errors.New("--seconds must be 1s-10s") }
	lab, power, e := load_lab_power(); if e != nil { return e }
	ctx, stop := interrupt_ctx()
	defer stop()
	res, e := picorom.Probe(ctx, lab, power, args[0], picorom_args.seconds, picorom_args.every)
	if res != nil && picorom_args.out != "" {
		js, _ := json.MarshalIndent(res, "", " ")
		os.WriteFile(picorom_args.out, js, 0o664)
	}
	if e != nil { return e }
	if picorom_args.json { return print_json(res) }
	fmt.Printf("%d pin samples, %d with the socket selected, %d distinct addresses\n", res.Pins, res.Selected, res.Distinct)
	for _, t := range res.Top { fmt.Printf("  %s x%d\n", t.Address, t.Count) }
	fmt.Println(res.Verdict)
	return nil
}

func run_picorom_power(cmd *cobra.Command, args []string) error {
	_, power, e := load_lab_power(); if e != nil { return e }
	var st picorom.PowerState
	switch args[0] {
	case "status": st, e = power.Status()
	case "on": st, e = power.Set(true)
	case "off": st, e = power.Set(false)
	default: return fmt.Errorf("use status, on or off")
	}
	if e != nil { return e }
	if picorom_args.json { return print_json(st) }
	state := "unknown (manual switch)"
	if st.On != nil { state = map[bool]string{true: "on", false: "off"}[*st.On] }
	watts := ""
	if st.Watts != nil { watts = fmt.Sprintf(", %.1f W", *st.Watts) }
	fmt.Printf("PCB power %s%s (%s)\n", state, watts, power.Describe())
	return nil
}

func bustest_test(args []string) (*bustest.Test, error) {
	if len(args) != 2 { return nil, errors.New("give <core> <set>") }
	s, e := bustest.LoadSpec(args[0], args[1]); if e != nil { return nil, e }
	return bustest.NewTest(s)
}

func run_bustest_show(cmd *cobra.Command, args []string) error {
	if len(args) == 1 {
		sets, e := bustest.Sets(args[0]); if e != nil { return e }
		if picorom_args.json { return print_json(sets) }
		fmt.Println(strings.Join(sets, "\n"))
		return nil
	}
	t, e := bustest_test(args); if e != nil { return e }
	if picorom_args.json { return print_json(t.Spec) }
	fmt.Print(t.Show())
	return nil
}

func run_bustest_gen(cmd *cobra.Command, args []string) error {
	t, e := bustest_test(args); if e != nil { return e }
	m, e := t.Generate(t.OutDir()); if e != nil { return e }
	if picorom_args.json { return print_json(m) }
	fmt.Printf("%s: %d bytes of code, %d events expected, files in %s\n", m.Set, m.CodeBytes, m.Expected, t.OutDir())
	for _, n := range sorted_str_keys(m.Sha256) { fmt.Printf("  %-14s %s\n", n, m.Sha256[n]) }
	return nil
}

func sorted_str_keys(m map[string]string) []string {
	var k []string
	for n := range m { k = append(k, n) }
	sort.Strings(k)
	return k
}

func run_bustest_sim(cmd *cobra.Command, args []string) error {
	t, e := bustest_test(args); if e != nil { return e }
	res, e := bustest.NewSimulation(t).Run(); if e != nil { return e }
	if picorom_args.json { return print_json(res) }
	fmt.Printf("%s: jtsim rc %d, %d markers, start %v, end %v, fatal %v (%s)\n", t.Set, res.Rc, res.Events,
		res.StartSeen, res.EndSeen, res.FatalSeen, filepath.Join(t.OutDir(), "sim_result.json"))
	print_cycles(res.Brackets)
	if !res.EndSeen { return errors.New("the simulation did not reach the end marker: see jtsim.log") }
	return nil
}

func print_cycles(br []bustest.BracketResult) {
	var order []string
	vals := map[string][]string{}
	for _, b := range br {
		k := b.Case + " " + b.Access
		if _, ok := vals[k]; !ok { order = append(order, k) }
		v := "n/a"
		if b.Cycles != nil { v = fmt.Sprintf("%.2f", *b.Cycles) }
		vals[k] = append(vals[k], v)
	}
	for _, k := range order { fmt.Printf("  %-22s %s\n", k, strings.Join(vals[k], " / ")) }
}

func run_bustest_run(cmd *cobra.Command, args []string) error {
	t, e := bustest_test(args); if e != nil { return e }
	lab, power, e := load_lab_power(); if e != nil { return e }
	units := map[string]string{}
	for _, u := range picorom_args.units {
		lane, name, ok := strings.Cut(u, "="); if !ok { return fmt.Errorf("--unit expects lane=NAME, got %q", u) }
		units[lane] = name
	}
	ctx, stop := interrupt_ctx()
	defer stop()
	opt := bustest.RunOptions{Ctx: ctx, Units: units, Timeout: picorom_args.timeout, StallProbe: picorom_args.stall,
		DryRun: picorom_args.dry_run, Confirm: func(plan string) error {
			fmt.Fprint(os.Stderr, plan)
			if picorom_args.yes { return nil }
			return confirm("Is the board set up as listed?")
		}}
	res, e := bustest.NewRunner(t, lab, power, opt).Run()
	if res == nil { return e }
	if picorom_args.json { print_json(res) } else {
		fmt.Printf("%s: %d markers, boots %d, complete %v (%s)\n", t.Set, len(res.Events), res.Boots, res.Complete, res.Dir)
		for _, w := range res.Warnings { fmt.Println("  warning:", w) }
		print_cycles(res.Brackets)
	}
	if e != nil { return e }
	if !res.Complete { os.Exit(picorom_incomplete) }
	return nil
}

func run_bustest_report(cmd *cobra.Command, args []string) error {
	t, e := bustest_test(args); if e != nil { return e }
	rep, e := bustest.NewReport(t, picorom_args.run); if e != nil { return e }
	if picorom_args.json { return print_json(rep) }
	fmt.Print(rep.Markdown())
	return nil
}

// interrupt_ctx is cancelled by Ctrl-C or SIGTERM, so commands that power the
// PCB can stop and switch it off instead of exiting at once
func interrupt_ctx() (context.Context, context.CancelFunc) {
	return signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
}

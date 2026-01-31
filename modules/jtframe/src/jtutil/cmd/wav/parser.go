package wav

import(
	"fmt"
	"os"
	"slices"
	"strings"

	"jtutil/vcd"
	"github.com/spf13/cobra"
)

type wav_parser_t struct{
	input_fname, signal_name, output_fname string
	lnfile *vcd.LnFile
	signal *vcd.VCDSignal
	ss vcd.VCDData
	wav_file *WavFile
	repeat float64
	skip_silence bool
}

func RunWavCmd(cmd *cobra.Command, args []string) {
	parser := wav_parser_t{
		lnfile: &vcd.LnFile{},
		input_fname: "test.vcd",
	}

	if len(args)>0 { parser.input_fname = args[0] }

	parser.signal_name,_  = cmd.Flags().GetString("signal")
	parser.skip_silence,_ = cmd.Flags().GetBool("skip")
	e := parser.Parse()
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func (w *wav_parser_t)Parse() error {
	w.lnfile.Open(w.input_fname)
	defer w.lnfile.Close()
	w.ss = vcd.GetSignals(w.lnfile)
	dumped := 0
	for _, w.signal = range w.ss {
		name := w.signal.Name
		if ! w.is_match(name) { continue }
		w.wav_file = MakeWav()
		w.lnfile.Reset()
		w.move_vcd_data_to_wav()
		e := w.wav_file.Dump(name+".wav")
		if e!=nil { return e }
		dumped++
	}
	if dumped==0 {
		return fmt.Errorf("No signals dumped")
	}
	return nil
}

func (w *wav_parser_t)is_match(name string) bool {
	dont_filter := w.signal_name==""
	return strings.Contains(w.signal_name,name) || dont_filter
}

func (w *wav_parser_t)validate_signals() error {
	if len(w.ss)==0 {
		return fmt.Errorf("Empty VCD file")
	}
	return nil
}

func (w *wav_parser_t)collect_signal_names() string {
	names := make([]string,len(w.ss))
	k:=0
	for _, sgn := range w.ss {
		names[k] = sgn.FullName()
		k++
	}
	slices.Sort(names)
	return strings.Join(names,"\n")
}

func (w *wav_parser_t)find_signal() error {
	matches := make([]*vcd.VCDSignal,0,len(w.ss))
	for _,sgn := range w.ss {
		if strings.HasSuffix( sgn.FullName(), w.signal_name ) {
			matches=append(matches,sgn)
		}
	}
	switch len(matches) {
		case 0: return fmt.Errorf("Signal %s not found", w.signal_name)
		case 1: w.signal = matches[0]
		default: return fmt.Errorf("Too many matches for name %s", w.signal_name)
	}
	return nil
}

func (w *wav_parser_t)move_vcd_data_to_wav() {
	for {
		w.write_value_to_wav()
		if !w.next() { break }
	}
}

func (w *wav_parser_t)write_value_to_wav() {
	snd := w.get_16bit_value()
	if w.skip_silence==true && snd==0 { return }
	w.skip_silence = false
	for w.repeat>=1.0 {
		w.wav_file.append(snd)
		w.repeat -= 1.0
	}
}

func (w *wav_parser_t)get_16bit_value() int16 {
	if w.signal.MSB==15 { return int16(w.signal.Value) }
	if w.signal.MSB <15 { return int16(w.signal.Value<<(15-w.signal.MSB)) }
	// > 15
	return int16(w.signal.Value>>(w.signal.MSB-15))

}

func (w *wav_parser_t)next() bool {
	const period_48k_in_ps = 20833333
	tnow  := w.lnfile.Time()
	tnext := tnow + period_48k_in_ps
	is_new_data := w.lnfile.MoveTo(w.ss,tnext)
	if !is_new_data { return false }
	tnext = w.lnfile.Time()
	w.repeat += (float64(tnext)-float64(tnow))/float64(period_48k_in_ps)
	return true
}
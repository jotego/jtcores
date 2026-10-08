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
*/

package cmd

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"

	"github.com/spf13/cobra"
	"jotego/jtframe/macros"
)

type MP4 struct {
	path, output           string
	rate                   float64
	frames_dir, audio_file string
	tmp_dir, staged_frames string
	frames                 map[int]string
	prefix                 string
	width, first, last     int
	interrupt              chan os.Signal
}

var mp4_args MP4
var mp4_ffmpeg = "ffmpeg"
var mp4_frame_re = regexp.MustCompile(`^(frames?_)([0-9]+)\.png$`)

var mp4Cmd = &cobra.Command{
	Use:   "mp4",
	Short: "Create an MP4 video from simulation frames and test.wav",
	Long:  man_blurb("jtutil-mp4", "Create an MP4 video from simulation frames and test.wav."),
	RunE:  run_mp4,
	Args:  cobra.NoArgs,
}

func init() {
	rootCmd.AddCommand(mp4Cmd)
	default_rate := 60.0
	mp4 := MP4{path: "."}
	rate, e := mp4.default_rate()
	if e == nil {
		default_rate = rate
	}
	mp4Cmd.Flags().StringVarP(&mp4_args.path, "path", "p", ".", "Simulation folder containing frames and test.wav")
	mp4Cmd.Flags().StringVarP(&mp4_args.output, "output", "o", "test.mp4", "Output MP4 file name")
	mp4Cmd.Flags().Float64VarP(&mp4_args.rate, "rate", "r", default_rate, "Video frame rate in Hz")
}

func run_mp4(cmd *cobra.Command, args []string) error {
	if cmd.Flags().Changed("rate") && mp4_args.rate <= 0 {
		return fmt.Errorf("frame rate must be positive")
	}
	return mp4_args.run()
}

func (mp4 *MP4) run() error {
	mp4.interrupt = make(chan os.Signal, 1)
	signal.Notify(mp4.interrupt, os.Interrupt)
	defer signal.Stop(mp4.interrupt)
	done := make(chan struct{})
	defer close(done)
	go mp4.watch_interrupt(done)
	path, e := filepath.Abs(mp4.path)
	if e != nil {
		return e
	}
	mp4.path = path
	mp4.frames_dir = filepath.Join(mp4.path, "frames")
	mp4.audio_file = filepath.Join(mp4.path, "test.wav")
	_, e = os.Stat(mp4.audio_file)
	if e != nil {
		return fmt.Errorf("missing audio file %s", mp4.audio_file)
	}
	e = mp4.get_frames()
	if e != nil {
		return e
	}
	mp4.tmp_dir, e = os.MkdirTemp("/tmp", "jtutil-mp4-")
	if e != nil {
		return e
	}
	defer mp4.cleanup()
	mp4.staged_frames = filepath.Join(mp4.tmp_dir, "frames")
	e = os.Mkdir(mp4.staged_frames, 0755)
	if e != nil {
		return e
	}
	e = mp4.copy_folder(mp4.frames_dir, mp4.staged_frames)
	if e != nil {
		return e
	}
	e = mp4.fill_frames()
	if e != nil {
		return e
	}
	mp4.output, e = filepath.Abs(mp4.output)
	if e != nil {
		return e
	}
	return mp4.run_ffmpeg()
}

func (mp4 *MP4) run_ffmpeg() error {
	pattern := filepath.Join(mp4.staged_frames, fmt.Sprintf("%s%%0%dd.png", mp4.prefix, mp4.width))
	ffmpeg_args := []string{
		"-y", "-framerate", strconv.FormatFloat(mp4.rate, 'f', -1, 64),
		"-start_number", strconv.Itoa(mp4.first), "-i", pattern, "-i", mp4.audio_file,
		"-c:v", "libx264", "-crf", "0", "-pix_fmt", "yuv444p", "-c:a", "aac", "-b:a", "192k",
		"-movflags", "+faststart", mp4.output,
	}
	fmt.Printf("Frame rate: %.2f Hz\nOutput: %s\n", mp4.rate, mp4.output)
	ffmpeg := exec.Command(mp4_ffmpeg, ffmpeg_args...)
	ffmpeg.Stdout = os.Stdout
	ffmpeg.Stderr = os.Stderr
	return ffmpeg.Run()
}

func (mp4 *MP4) watch_interrupt(done <-chan struct{}) {
	select {
	case <-mp4.interrupt:
		mp4.cleanup()
		os.Exit(130)
	case <-done:
	}
}

func (mp4 *MP4) cleanup() {
	if mp4.tmp_dir != "" {
		os.RemoveAll(mp4.tmp_dir)
	}
}

func (mp4 *MP4) get_frames() error {
	entries, e := os.ReadDir(mp4.frames_dir)
	if e != nil {
		return e
	}
	mp4.frames = make(map[int]string)
	mp4.prefix, mp4.width, mp4.first, mp4.last = "", 0, -1, -1
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		match := mp4_frame_re.FindStringSubmatch(entry.Name())
		if match == nil {
			continue
		}
		if mp4.prefix != "" && mp4.prefix != match[1] {
			return fmt.Errorf("mixed frame prefixes in %s", mp4.frames_dir)
		}
		mp4.prefix = match[1]
		number, e := strconv.Atoi(match[2])
		if e != nil {
			return e
		}
		if _, exists := mp4.frames[number]; exists {
			return fmt.Errorf("duplicate frame %d", number)
		}
		mp4.frames[number] = filepath.Join(mp4.frames_dir, entry.Name())
		if len(match[2]) > mp4.width {
			mp4.width = len(match[2])
		}
		if mp4.first < 0 || number < mp4.first {
			mp4.first = number
		}
		if number > mp4.last {
			mp4.last = number
		}
	}
	if len(mp4.frames) == 0 {
		return fmt.Errorf("no PNG frames found in %s", mp4.frames_dir)
	}
	return nil
}

func (mp4 *MP4) copy_folder(source, dest string) error {
	entries, e := os.ReadDir(source)
	if e != nil {
		return e
	}
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".png" {
			continue
		}
		source_file := filepath.Join(source, entry.Name())
		dest_file := filepath.Join(dest, entry.Name())
		e = mp4.copy_file(source_file, dest_file)
		if e != nil {
			return e
		}
	}
	return nil
}

func (mp4 *MP4) fill_frames() error {
	previous := ""
	for number := mp4.first; number <= mp4.last; number++ {
		dest := filepath.Join(mp4.staged_frames, fmt.Sprintf("%s%0*d.png", mp4.prefix, mp4.width, number))
		if source, found := mp4.frames[number]; found {
			previous = source
		}
		if previous == "" {
			return fmt.Errorf("missing first frame %d", mp4.first)
		}
		e := mp4.copy_file(previous, dest)
		if e != nil {
			return e
		}
		previous = dest
	}
	return nil
}

func (mp4 *MP4) copy_file(source, dest string) error {
	in, e := os.Open(source)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.Create(dest)
	if e != nil {
		return e
	}
	_, e = io.Copy(out, in)
	close_e := out.Close()
	if e != nil {
		return e
	}
	return close_e
}

func (mp4 *MP4) default_rate() (float64, error) {
	core := mp4.get_corename()
	if core == "" {
		return 60, nil
	}
	target := os.Getenv("TARGET")
	if target == "" {
		target = "sidi128"
	}
	macros.MakeMacros(core, target)
	rate_str := macros.Get("JTFRAME_RATE")
	if rate_str == "" {
		return 60, nil
	}
	rate, e := strconv.ParseFloat(rate_str, 64)
	if e != nil || rate <= 0 {
		return 0, fmt.Errorf("invalid JTFRAME_RATE for %s", core)
	}
	return rate, nil
}

func (mp4 *MP4) get_corename() string {
	cores := filepath.Join(os.Getenv("JTROOT"), "cores")
	path := mp4.path
	for {
		if filepath.Dir(path) == cores {
			if _, e := os.Stat(filepath.Join(path, "cfg", "macros.def")); e == nil {
				return filepath.Base(path)
			}
			return ""
		}
		parent := filepath.Dir(path)
		if parent == path {
			return ""
		}
		path = parent
	}
}

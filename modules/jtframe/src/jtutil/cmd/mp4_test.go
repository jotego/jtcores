package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestMP4_fill_frames(t *testing.T) {
	source := t.TempDir()
	first := filepath.Join(source, "frame_0100.png")
	last := filepath.Join(source, "frame_0150.png")
	e := os.WriteFile(first, []byte("first"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	e = os.WriteFile(last, []byte("last"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	dest := t.TempDir()
	mp4 := MP4{frames_dir: source, staged_frames: dest}
	e = mp4.get_frames()
	if e != nil {
		t.Fatal(e)
	}
	e = mp4.fill_frames()
	if e != nil {
		t.Fatal(e)
	}
	data, e := os.ReadFile(filepath.Join(dest, "frame_0101.png"))
	if e != nil {
		t.Fatal(e)
	}
	if string(data) != "first" {
		t.Fatalf("gap was not filled from previous frame: %s", data)
	}
	data, e = os.ReadFile(filepath.Join(dest, "frame_0150.png"))
	if e != nil {
		t.Fatal(e)
	}
	if string(data) != "last" {
		t.Fatalf("last frame changed: %s", data)
	}
}

func TestMP4_default_rate(t *testing.T) {
	root := mp4_test_jtroot(t)
	t.Setenv("JTROOT", root)
	t.Setenv("JTFRAME", filepath.Join(root, "modules", "jtframe"))
	t.Setenv("CORES", filepath.Join(root, "cores"))
	t.Setenv("TARGET", "sidi128")
	mp4 := MP4{path: filepath.Join(root, "cores", "toki", "ver", "cabal")}
	rate, e := mp4.default_rate()
	if e != nil {
		t.Fatal(e)
	}
	if rate != 59.64 {
		t.Fatalf("unexpected rate %.2f", rate)
	}
}

func TestMP4_cleanup(t *testing.T) {
	mp4 := MP4{tmp_dir: t.TempDir()}
	mp4.cleanup()
	if _, e := os.Stat(mp4.tmp_dir); !os.IsNotExist(e) {
		t.Fatalf("temporary folder was not removed: %v", e)
	}
}

func TestMP4_copy_folder(t *testing.T) {
	source := t.TempDir()
	dest := t.TempDir()
	e := os.WriteFile(filepath.Join(source, "frame_0001.png"), []byte("frame"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	e = os.WriteFile(filepath.Join(source, "notes.txt"), []byte("notes"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	mp4 := MP4{}
	e = mp4.copy_folder(source, dest)
	if e != nil {
		t.Fatal(e)
	}
	if _, e = os.Stat(filepath.Join(dest, "frame_0001.png")); e != nil {
		t.Fatal(e)
	}
	if _, e = os.Stat(filepath.Join(dest, "notes.txt")); !os.IsNotExist(e) {
		t.Fatalf("non-PNG file was copied: %v", e)
	}
}

func mp4_test_jtroot(t *testing.T) string {
	path, e := os.Getwd()
	if e != nil {
		t.Fatal(e)
	}
	for {
		if _, e = os.Stat(filepath.Join(path, ".git")); e == nil {
			return path
		}
		parent := filepath.Dir(path)
		if parent == path {
			t.Fatal("could not find jtcores root")
		}
		path = parent
	}
}

func TestMP4_run(t *testing.T) {
	sim := t.TempDir()
	frames := filepath.Join(sim, "frames")
	e := os.Mkdir(frames, 0755)
	if e != nil {
		t.Fatal(e)
	}
	for _, name := range []string{"frame_0001.png", "frame_0003.png"} {
		e = os.WriteFile(filepath.Join(frames, name), []byte(name), 0644)
		if e != nil {
			t.Fatal(e)
		}
	}
	e = os.WriteFile(filepath.Join(sim, "test.wav"), []byte("audio"), 0644)
	if e != nil {
		t.Fatal(e)
	}
	args_file := filepath.Join(sim, "ffmpeg.args")
	fake_ffmpeg := filepath.Join(sim, "ffmpeg")
	script := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$MP4_ARGS\"\nfor arg; do output=$arg; done\ntouch \"$output\"\n"
	e = os.WriteFile(fake_ffmpeg, []byte(script), 0755)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("MP4_ARGS", args_file)
	original := mp4_ffmpeg
	mp4_ffmpeg = fake_ffmpeg
	defer func() { mp4_ffmpeg = original }()
	e = (&MP4{path: sim, output: filepath.Join(sim, "test.mp4"), rate: 55}).run()
	if e != nil {
		t.Fatal(e)
	}
	args, e := os.ReadFile(args_file)
	if e != nil {
		t.Fatal(e)
	}
	if !strings.Contains(string(args), "-framerate\n55\n") {
		t.Fatalf("frame rate was not passed to ffmpeg: %s", args)
	}
	if !strings.Contains(string(args), "frame_%04d.png") {
		t.Fatalf("image sequence was not passed to ffmpeg: %s", args)
	}
	if !strings.Contains(string(args), "-crf\n0\n") {
		t.Fatalf("high-quality video setting was not passed to ffmpeg: %s", args)
	}
	if !strings.Contains(string(args), "-pix_fmt\nyuv444p\n") {
		t.Fatalf("full-chroma video format was not passed to ffmpeg: %s", args)
	}
	if !strings.Contains(string(args), "-b:a\n192k\n") {
		t.Fatalf("high-quality audio bitrate was not passed to ffmpeg: %s", args)
	}
	if _, e = os.Stat(filepath.Join(sim, "test.mp4")); e != nil {
		t.Fatal(e)
	}
}

/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"image"
	"image/color"
	"image/png"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func write_test_png(t *testing.T, path string, c color.RGBA) {
	t.Helper()
	if e := os.MkdirAll(filepath.Dir(path), 0750); e != nil {
		t.Fatal(e)
	}
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	for i := range img.Pix {
		img.Pix[i] = []uint8{c.R, c.G, c.B, 255}[i%4]
	}
	f, e := os.Create(path)
	if e != nil {
		t.Fatal(e)
	}
	defer f.Close()
	if e = png.Encode(f, img); e != nil {
		t.Fatal(e)
	}
}

func TestRejectReplacesOlderRejected(t *testing.T) {
	root := t.TempDir()
	red, blue := color.RGBA{255, 0, 0, 255}, color.RGBA{0, 0, 255, 255}
	write_test_png(t, filepath.Join(root, "cps1", "sf2", "rejected", "frame_00000100.png"), red)
	write_test_png(t, filepath.Join(root, "cps1", "sf2", "new", "frame_00000200.png"), blue)
	if e := Reject(root, []string{"sf2"}, io.Discard); e != nil {
		t.Fatal(e)
	}
	if _, e := os.Stat(filepath.Join(root, "cps1", "sf2", "rejected", "frame_00000200.png")); e != nil {
		t.Error(e)
	}
	for _, path := range []string{"rejected/frame_00000100.png", "new"} {
		if _, e := os.Stat(filepath.Join(root, "cps1", "sf2", path)); e == nil {
			t.Errorf("%s is still there", path)
		}
	}
	if log, _ := os.ReadFile(filepath.Join(root, "cps1", "sf2", "log")); !strings.HasSuffix(string(log), " manual        REJECT      --------\n") {
		t.Errorf("log is %q", log)
	}
	if e := Reject(root, []string{"sf2"}, io.Discard); e == nil {
		t.Error("rejecting a game with nothing pending did not fail")
	}
}

func TestPublishSlotClearsRejected(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "cps1", "sf2")
	write_test_png(t, filepath.Join(game, "rejected", "frame_00000100.png"), color.RGBA{})
	src := t.TempDir()
	write_test_png(t, filepath.Join(src, "MiSTer.log"), color.RGBA{})
	r := &runner{}
	if e := r.publish_slot(game, "error", src); e != nil {
		t.Fatal(e)
	}
	if !is_dir(filepath.Join(game, "rejected")) {
		t.Error("an error removed rejected")
	}
	if e := r.publish_slot(game, "new", src); e != nil {
		t.Fatal(e)
	}
	if is_dir(filepath.Join(game, "rejected")) {
		t.Error("a new result kept rejected")
	}
}

func TestReviewPagesAndActions(t *testing.T) {
	root := t.TempDir()
	red, blue := color.RGBA{255, 0, 0, 255}, color.RGBA{0, 0, 255, 255}
	write_test_png(t, filepath.Join(root, "cps1", "ffight", "new", "frame_00000100.png"), red)
	write_test_png(t, filepath.Join(root, "cps1", "sf2", "ref", "frame_00000100.png"), red)
	write_test_png(t, filepath.Join(root, "cps1", "sf2", "fail", "frame_00000100.png"), blue)
	write_test_png(t, filepath.Join(root, "cps1", "sf2", "ref", "frame_00000200.png"), red)
	write_test_png(t, filepath.Join(root, "cps1", "sf2", "fail", "frame_00000200.png"), red)
	write_test_png(t, filepath.Join(root, "cps1", "kod", "new", "frame_00000100.png"), red)
	write_test_png(t, filepath.Join(root, "dd", "ddragon", "new", "frame_00000100.png"), red)
	server := httptest.NewServer(review_handler(root))
	defer server.Close()
	get := func(path string) (int, string) {
		r, e := http.Get(server.URL + path)
		if e != nil {
			t.Fatal(e)
		}
		defer r.Body.Close()
		body, _ := io.ReadAll(r.Body)
		return r.StatusCode, string(body)
	}
	post := func(path string, form url.Values, header bool) int {
		req, _ := http.NewRequest(http.MethodPost, server.URL+path, strings.NewReader(form.Encode()))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		if header {
			req.Header.Set("X-Review", "1")
		}
		r, e := http.DefaultClient.Do(req)
		if e != nil {
			t.Fatal(e)
		}
		r.Body.Close()
		return r.StatusCode
	}
	if code, body := get("/"); code != 200 || !strings.Contains(body, `href="/core/cps1"`) || !strings.Contains(body, `href="/core/dd"`) {
		t.Fatalf("index %d %s", code, body)
	}
	code, body := get("/core/cps1")
	if code != 200 || !strings.Contains(body, "1/2 frames differ") || !strings.Contains(body, "/diff/cps1/sf2/frame_00000100.png") || !strings.Contains(body, `next: <a href="/core/dd">`) {
		t.Fatalf("core page %d %s", code, body)
	}
	if strings.Contains(body, "/diff/cps1/sf2/frame_00000200.png") {
		t.Error("a matching frame has a difference image")
	}
	if code, _ := get("/diff/cps1/sf2/frame_00000100.png"); code != 200 {
		t.Errorf("diff image %d", code)
	}
	for _, path := range []string{"/file/cps1/sf2/../../x", "/file/log/x/new/a.png", "/core/.x", "/file/cps1/sf2/tmp/a.png"} {
		if code, _ := get(path); code == 200 {
			t.Errorf("%s was served", path)
		}
	}
	if code := post("/accept", url.Values{"core": {"cps1"}, "set": {"ffight", "kod"}}, false); code == 200 {
		t.Error("accepted without the review header")
	}
	if code := post("/accept", url.Values{"core": {"cps1"}, "set": {"../dd"}}, true); code == 200 {
		t.Error("accepted a path")
	}
	lock, e := lock_regression(root)
	if e != nil {
		t.Fatal(e)
	}
	if code := post("/accept", url.Values{"core": {"cps1"}, "set": {"ffight"}}, true); code != http.StatusConflict {
		t.Errorf("accepted during a regression: %d", code)
	}
	lock.Close()
	if code := post("/accept", url.Values{"core": {"cps1"}, "set": {"ffight", "kod"}}, true); code != 200 {
		t.Errorf("bulk accept %d", code)
	}
	if code := post("/reject", url.Values{"core": {"cps1"}, "set": {"sf2"}}, true); code != 200 {
		t.Errorf("reject %d", code)
	}
	for _, path := range []string{"cps1/ffight/ref", "cps1/kod/ref", "cps1/sf2/rejected", "cps1/sf2/ref"} {
		if !is_dir(filepath.Join(root, path)) {
			t.Errorf("%s is missing", path)
		}
	}
	if _, body = get("/core/cps1"); !strings.Contains(body, "Nothing waits for review") || !strings.Contains(body, "Rejected") {
		t.Errorf("core page after the actions: %s", body)
	}
}

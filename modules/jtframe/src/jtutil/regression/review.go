/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bufio"
	"fmt"
	"html/template"
	"image"
	"image/color"
	"image/png"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// Review serves web pages to look at the frames waiting in new/ and fail/ and
// accept or reject them. Accepting and rejecting take the regression lock, so
// they fail while a regression runs
func Review(root, addr string, out io.Writer) error {
	fmt.Fprintf(out, "Reviewing %s at http://%s/ (Ctrl+C to stop)\n", root, addr)
	return http.ListenAndServe(addr, review_handler(root))
}

type review_core struct {
	Name                       string
	New, Fail, Error, Rejected int
}

type review_game struct {
	Core, Set, Slot string
	Frames          []review_frame
	Differ          int
	Files           []string // the non-PNG files of the slot, like Main logs
	Log             []string // last lines of the game log
}

type review_frame struct {
	Name    string
	Frame   int
	Differs bool // fail/ only: the frame is not in ref or its pixels differ
	W, H    int
}

type review_page struct {
	Core     string
	Games    []review_game
	Errors   []review_game
	Rejected []review_game
	Next     string // next core with pending games
	Cores    []review_core
}

func review_handler(root string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		cores, e := review_cores(root)
		if e != nil {
			http.Error(w, e.Error(), http.StatusInternalServerError)
			return
		}
		review_render(w, review_index, review_page{Cores: cores})
	})
	mux.HandleFunc("/core/", func(w http.ResponseWriter, r *http.Request) {
		core := strings.TrimPrefix(r.URL.Path, "/core/")
		if !review_name(core) {
			http.NotFound(w, r)
			return
		}
		page, e := review_core_page(root, core)
		if e != nil {
			http.Error(w, e.Error(), http.StatusInternalServerError)
			return
		}
		review_render(w, review_core_tmpl, page)
	})
	mux.HandleFunc("/file/", func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/file/"), "/")
		if len(parts) != 4 || !review_name(parts[0]) || !review_name(parts[1]) || !review_slot(parts[2]) || !review_file(parts[3]) {
			http.NotFound(w, r)
			return
		}
		if !strings.HasSuffix(parts[3], ".png") {
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		}
		http.ServeFile(w, r, filepath.Join(root, parts[0], parts[1], parts[2], parts[3]))
	})
	mux.HandleFunc("/diff/", func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/diff/"), "/")
		if len(parts) != 3 || !review_name(parts[0]) || !review_name(parts[1]) || !review_file(parts[2]) || !strings.HasSuffix(parts[2], ".png") {
			http.NotFound(w, r)
			return
		}
		game := filepath.Join(root, parts[0], parts[1])
		img, e := diff_image(filepath.Join(game, "ref", parts[2]), filepath.Join(game, "fail", parts[2]))
		if e != nil {
			http.Error(w, e.Error(), http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "image/png")
		w.Header().Set("Cache-Control", "no-store")
		png.Encode(w, img)
	})
	action := func(name string, act func(string) (bool, error)) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			// a custom header cannot come from a plain cross-site form
			if r.Method != http.MethodPost || r.Header.Get("X-Review") != "1" {
				http.Error(w, "POST from the review page only", http.StatusMethodNotAllowed)
				return
			}
			if e := r.ParseForm(); e != nil {
				http.Error(w, e.Error(), http.StatusBadRequest)
				return
			}
			core, sets := r.PostForm.Get("core"), r.PostForm["set"]
			if !review_name(core) || len(sets) == 0 {
				http.Error(w, "missing core or set", http.StatusBadRequest)
				return
			}
			for _, set := range sets {
				if !review_name(set) {
					http.Error(w, "bad set name", http.StatusBadRequest)
					return
				}
			}
			lock, e := lock_regression(root)
			if e == errBusy {
				http.Error(w, "a regression is running: try again when it ends", http.StatusConflict)
				return
			}
			if e != nil {
				http.Error(w, e.Error(), http.StatusInternalServerError)
				return
			}
			defer lock.Close()
			var done []string
			for _, set := range sets {
				ok, e := act(filepath.Join(root, core, set))
				if e != nil {
					http.Error(w, fmt.Sprintf("%s/%s: %v (done: %s)", core, set, e, strings.Join(done, " ")), http.StatusInternalServerError)
					return
				}
				if ok {
					done = append(done, set)
				}
			}
			fmt.Fprintf(w, "%s: %s\n", name, strings.Join(done, " "))
		}
	}
	mux.HandleFunc("/accept", action("accepted", accept_game))
	mux.HandleFunc("/reject", action("rejected", reject_game))
	return mux
}

func review_render(w http.ResponseWriter, t *template.Template, page review_page) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if e := t.Execute(w, page); e != nil {
		fmt.Fprintf(w, "<p>%s</p>", template.HTMLEscapeString(e.Error()))
	}
}

func review_name(name string) bool {
	return name != "" && name != "log" && !strings.HasPrefix(name, ".") && safeComponent(name)
}

func review_slot(slot string) bool {
	return slot == "new" || slot == "fail" || slot == "ref" || slot == "error" || slot == "rejected"
}

func review_file(name string) bool {
	return name != "" && !strings.HasPrefix(name, ".") && !strings.ContainsAny(name, "/\\")
}

func review_dirs(dir string) []string {
	entries, _ := os.ReadDir(dir)
	var names []string
	for _, entry := range entries {
		if entry.IsDir() && review_name(entry.Name()) {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)
	return names
}

func is_dir(path string) bool {
	info, e := os.Stat(path)
	return e == nil && info.IsDir()
}

func review_cores(root string) ([]review_core, error) {
	if !is_dir(root) {
		return nil, fmt.Errorf("%s is not a folder", root)
	}
	var cores []review_core
	for _, core := range review_dirs(root) {
		c := review_core{Name: core}
		for _, set := range review_dirs(filepath.Join(root, core)) {
			game := filepath.Join(root, core, set)
			switch pending_slot(game) {
			case "new":
				c.New++
			case "fail":
				c.Fail++
			}
			if is_dir(filepath.Join(game, "error")) {
				c.Error++
			}
			if is_dir(filepath.Join(game, "rejected")) {
				c.Rejected++
			}
		}
		cores = append(cores, c)
	}
	return cores, nil
}

func review_core_page(root, core string) (review_page, error) {
	page := review_page{Core: core}
	for _, set := range review_dirs(filepath.Join(root, core)) {
		game := filepath.Join(root, core, set)
		if slot := pending_slot(game); slot != "" {
			g, e := review_read_game(game, core, set, slot)
			if e != nil {
				return page, e
			}
			page.Games = append(page.Games, g)
		}
		for _, slot := range []string{"error", "rejected"} {
			if !is_dir(filepath.Join(game, slot)) {
				continue
			}
			g, e := review_read_game(game, core, set, slot)
			if e != nil {
				return page, e
			}
			if slot == "error" {
				page.Errors = append(page.Errors, g)
			} else {
				page.Rejected = append(page.Rejected, g)
			}
		}
	}
	cores, e := review_cores(root)
	if e != nil {
		return page, e
	}
	for _, c := range cores {
		if c.Name > core && c.New+c.Fail > 0 {
			page.Next = c.Name
			break
		}
	}
	return page, nil
}

func review_read_game(game, core, set, slot string) (review_game, error) {
	g := review_game{Core: core, Set: set, Slot: slot}
	entries, e := os.ReadDir(filepath.Join(game, slot))
	if e != nil {
		return g, e
	}
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || !review_file(name) {
			continue
		}
		if !strings.HasSuffix(name, ".png") {
			g.Files = append(g.Files, name)
			continue
		}
		f := review_frame{Name: name, Frame: -1}
		if n, e := strconv.Atoi(strings.TrimSuffix(strings.TrimPrefix(name, "frame_"), ".png")); e == nil {
			f.Frame = n
		}
		f.W, f.H = png_size(filepath.Join(game, slot, name))
		if slot == "fail" {
			same, e := same_png(filepath.Join(game, "ref", name), filepath.Join(game, slot, name))
			f.Differs = e != nil || !same
			if f.Differs {
				g.Differ++
			}
		}
		g.Frames = append(g.Frames, f)
	}
	g.Log = review_log_tail(filepath.Join(game, "log"), 4)
	return g, nil
}

func png_size(path string) (int, int) {
	f, e := os.Open(path)
	if e != nil {
		return 0, 0
	}
	defer f.Close()
	config, e := png.DecodeConfig(f)
	if e != nil {
		return 0, 0
	}
	return config.Width, config.Height
}

func review_log_tail(path string, n int) []string {
	f, e := os.Open(path)
	if e != nil {
		return nil
	}
	defer f.Close()
	var lines []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
		if len(lines) > n {
			lines = lines[1:]
		}
	}
	return lines
}

// diff_image shows ref dimmed to gray, with the pixels that differ in fail in red
func diff_image(ref_path, fail_path string) (image.Image, error) {
	ref, e := decode_png(ref_path)
	if e != nil {
		return nil, e
	}
	got, e := decode_png(fail_path)
	if e != nil {
		return nil, e
	}
	if ref.Bounds() != got.Bounds() {
		return nil, fmt.Errorf("ref is %v, the capture is %v", ref.Bounds().Size(), got.Bounds().Size())
	}
	b := ref.Bounds()
	out := image.NewRGBA(b)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			r0, g0, b0, _ := ref.At(x, y).RGBA()
			r1, g1, b1, _ := got.At(x, y).RGBA()
			if r0 != r1 || g0 != g1 || b0 != b1 {
				out.Set(x, y, color.RGBA{255, 0, 0, 255})
				continue
			}
			gray := uint8((r0+g0+b0)/3>>8) / 2
			out.Set(x, y, color.RGBA{gray, gray, gray, 255})
		}
	}
	return out, nil
}

const review_style = `<style>
:root { --bg:#fafafa; --fg:#222; --muted:#777; --line:#ddd; --card:#fff; --bad:#c0392b; --accent:#2766c4; }
@media (prefers-color-scheme: dark) { :root { --bg:#181818; --fg:#ddd; --muted:#999; --line:#333; --card:#222; --bad:#e74c3c; --accent:#6aa0ff; } }
body { background:var(--bg); color:var(--fg); font:14px/1.4 system-ui,sans-serif; margin:0 16px 80px; }
a { color:var(--accent); }
table { border-collapse:collapse; } td,th { padding:3px 10px; border-bottom:1px solid var(--line); text-align:right; }
td:first-child,th:first-child { text-align:left; }
.game { background:var(--card); border:1px solid var(--line); border-radius:6px; margin:16px 0; padding:8px 12px; }
.game h2 { font-size:16px; margin:4px 0; display:flex; gap:12px; align-items:center; flex-wrap:wrap; }
.game.excluded { opacity:.55; }
.tag { font-size:12px; padding:1px 6px; border-radius:4px; border:1px solid var(--line); }
.tag.fail { color:var(--bad); border-color:var(--bad); }
.frames { zoom:var(--zoom,.5); display:flex; flex-wrap:wrap; gap:6px; }
.frame { font-size:calc(11px / var(--zoom,.5)); color:var(--muted); }
.frame img { display:block; image-rendering:pixelated; height:auto; }
.frame.differs { outline:2px solid var(--bad); padding:2px; }
.trio { display:flex; gap:2px; }
pre { font-size:12px; color:var(--muted); margin:4px 0; white-space:pre-wrap; }
button { font:inherit; padding:3px 12px; cursor:pointer; }
.bar { position:fixed; bottom:0; left:0; right:0; background:var(--card); border-top:1px solid var(--line); padding:10px 16px; display:flex; gap:16px; align-items:center; flex-wrap:wrap; }
</style>`

const review_script = `<script>
async function post(path, core, sets) {
	if (sets.length == 0) { alert('No game selected'); return; }
	const body = new URLSearchParams({core});
	for (const s of sets) body.append('set', s);
	const r = await fetch(path, {method:'POST', headers:{'X-Review':'1'}, body});
	const text = await r.text();
	if (!r.ok) { alert(text); }
	location.reload();
}
function toggle(box) { box.closest('.game').classList.toggle('excluded', box.checked); count(); }
function selected() { return [...document.querySelectorAll('.game[data-pending]')].filter(g => !g.querySelector('.exclude').checked).map(g => g.dataset.set); }
function zoom(z) { document.documentElement.style.setProperty('--zoom', z); try { localStorage.setItem('zoom', z); } catch (e) {} }
function count() { const n = document.getElementById('count'); if (n) n.textContent = selected().length; }
document.addEventListener('DOMContentLoaded', () => { try { const z = localStorage.getItem('zoom'); if (z) zoom(z); } catch (e) {} document.querySelectorAll('.exclude').forEach(b => b.closest('.game').classList.toggle('excluded', b.checked)); count(); });
</script>`

var review_index = template.Must(template.New("index").Parse(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Regression review</title>` + review_style + `</head><body>
<h1>Regression review</h1>
<table><tr><th>core</th><th>new</th><th>fail</th><th>error</th><th>rejected</th></tr>
{{range .Cores}}{{if or .New .Fail .Error .Rejected}}<tr><td><a href="/core/{{.Name}}">{{.Name}}</a></td>
<td>{{if .New}}{{.New}}{{end}}</td><td>{{if .Fail}}{{.Fail}}{{end}}</td><td>{{if .Error}}{{.Error}}{{end}}</td><td>{{if .Rejected}}{{.Rejected}}{{end}}</td></tr>{{end}}{{end}}
</table>
</body></html>`))

var review_core_tmpl = template.Must(template.New("core").Parse(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{.Core}} review</title>` + review_style + review_script + `</head><body>
<p><a href="/">all cores</a>{{if .Next}} · next: <a href="/core/{{.Next}}">{{.Next}}</a>{{end}}</p>
<h1>{{.Core}}</h1>
{{if not .Games}}<p>Nothing waits for review.</p>{{end}}
{{$core := .Core}}
{{range .Games}}<div class="game" data-pending data-set="{{.Set}}">
<h2><label><input type="checkbox" class="exclude" onchange="toggle(this)"{{if eq .Slot "fail"}} checked{{end}}> exclude</label>
{{.Set}} <span class="tag {{.Slot}}">{{.Slot}}{{if eq .Slot "fail"}} · {{.Differ}}/{{len .Frames}} frames differ{{end}}</span>
<button onclick="post('/accept','{{$core}}',['{{.Set}}'])">accept</button>
<button onclick="post('/reject','{{$core}}',['{{.Set}}'])">reject</button></h2>
{{if .Log}}<pre>{{range .Log}}{{.}}
{{end}}</pre>{{end}}
{{$g := .}}<div class="frames">{{range .Frames}}{{if .Differs}}<div class="frame differs"><div class="trio">
<a href="/file/{{$core}}/{{$g.Set}}/ref/{{.Name}}" target="_blank"><img loading="lazy" width="{{.W}}" height="{{.H}}" src="/file/{{$core}}/{{$g.Set}}/ref/{{.Name}}" title="ref"></a>
<a href="/file/{{$core}}/{{$g.Set}}/fail/{{.Name}}" target="_blank"><img loading="lazy" width="{{.W}}" height="{{.H}}" src="/file/{{$core}}/{{$g.Set}}/fail/{{.Name}}" title="capture"></a>
<a href="/diff/{{$core}}/{{$g.Set}}/{{.Name}}" target="_blank"><img loading="lazy" width="{{.W}}" height="{{.H}}" src="/diff/{{$core}}/{{$g.Set}}/{{.Name}}" title="differences"></a></div>
{{.Frame}}: ref · capture · differences</div>
{{else}}<div class="frame"><a href="/file/{{$core}}/{{$g.Set}}/{{$g.Slot}}/{{.Name}}" target="_blank"><img loading="lazy" width="{{.W}}" height="{{.H}}" src="/file/{{$core}}/{{$g.Set}}/{{$g.Slot}}/{{.Name}}"></a>{{.Frame}}</div>
{{end}}{{end}}</div>
{{if .Files}}<p>{{range .Files}}<a href="/file/{{$core}}/{{$g.Set}}/{{$g.Slot}}/{{.}}" target="_blank">{{.}}</a> {{end}}</p>{{end}}
</div>{{end}}
{{if .Errors}}<h2>Errors</h2>{{range .Errors}}{{$g := .}}<p>{{.Set}}: {{range .Files}}<a href="/file/{{$core}}/{{$g.Set}}/error/{{.}}" target="_blank">{{.}}</a> {{end}}</p>{{end}}{{end}}
{{if .Rejected}}<h2>Rejected</h2><p>{{range .Rejected}}{{.Set}} ({{len .Frames}} frames) {{end}}</p>{{end}}
{{if .Games}}<div class="bar"><button onclick="post('/accept','{{.Core}}',selected())">accept <span id="count"></span> games not excluded</button>
<span>Unticked games become the reference. fail games start excluded.</span>
<span>zoom <button onclick="zoom(.5)">½×</button><button onclick="zoom(1)">1×</button><button onclick="zoom(2)">2×</button></span></div>{{end}}
</body></html>`))

func safeComponent(value string) bool {
	return value != "" && !strings.ContainsAny(value, "/\\") && value != "." && value != ".."
}

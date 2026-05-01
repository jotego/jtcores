#!/usr/bin/env python3
"""framewatch - live viewer for Argus sim frames.

The sim writes frame_NNNNN images into
$JTCORES/cores/argus/ver/argus/frames/ as it runs. This script starts
a tiny HTTP server with live-follow, frame navigation, scrubber, and
playback controls so you can watch and inspect sim output in a browser.

Python stdlib only. Usage:

    python3 tools/framewatch.py                       # watch default dir
    python3 tools/framewatch.py --dir /other/frames   # override
    python3 tools/framewatch.py --port 9000 --poll 50 # tweak

Open the printed URL in any browser and leave it open across sim runs.
"""
import argparse
import http.server
import json
import os
import pathlib
import re
import sys
import urllib.parse

FRAME_RE = re.compile(r"frame_(\d+)\.(jpg|bmp|png)$")
CONTENT_TYPES = {
    "jpg": "image/jpeg",
    "bmp": "image/bmp",
    "png": "image/png",
}
DEFAULT_DIR = pathlib.Path(__file__).resolve().parents[1] / "ver/argus/frames"


def latest(frames_dir: pathlib.Path):
    # Pick the most-recently-modified frame rather than the highest-numbered
    # one. Old sim runs leave stale high-numbered files in this dir, so
    # filename-max would pin us to the previous run's final frame until the
    # current run overshoots it.
    best_n = -1
    best_name = None
    best_ext = None
    best_mtime = -1.0
    try:
        with os.scandir(frames_dir) as it:
            for ent in it:
                m = FRAME_RE.match(ent.name)
                if not m:
                    continue
                try:
                    mtime = ent.stat().st_mtime
                except OSError:
                    continue
                if mtime > best_mtime:
                    best_mtime = mtime
                    best_n = int(m.group(1))
                    best_name = ent.name
                    best_ext = m.group(2)
    except FileNotFoundError:
        pass
    return best_n, best_name, best_ext


def list_frames(frames_dir: pathlib.Path):
    # Return every frame_NNNNN number in the directory, sorted ascending.
    # Use a set so mixed image extensions do not duplicate the scrubber.
    out = set()
    try:
        with os.scandir(frames_dir) as it:
            for ent in it:
                m = FRAME_RE.match(ent.name)
                if m:
                    out.add(int(m.group(1)))
    except FileNotFoundError:
        pass
    return sorted(out)


def build_html(poll_ms: int) -> bytes:
    return f"""<!doctype html>
<html><head><meta charset=utf-8><title>argus sim frames</title>
<style>
  html,body{{margin:0;padding:0;background:#000;color:#eee;
           font:12px/1.3 ui-monospace,Menlo,monospace;}}
  #hud{{padding:6px 10px;background:#111;display:flex;gap:10px;
      align-items:center;flex-wrap:wrap;position:sticky;top:0;z-index:2;}}
  #hud b{{color:#6cf;}}
  #hud .sep{{opacity:0.4;}}
  #scrubrow{{padding:4px 10px;background:#111;display:flex;gap:10px;
           align-items:center;border-top:1px solid #222;}}
  #scrub{{flex:1;}}
  #wrap{{display:flex;align-items:center;justify-content:center;
       height:calc(100vh - 64px);overflow:auto;}}
  /* Preserve the sim image aspect ratio. Argus is a vertical cabinet, so
     rotated frame dumps are portrait 224x256 rather than OpWolf's landscape. */
  img{{image-rendering:pixelated;width:auto;height:auto;
     max-width:100%;max-height:100%;background:#200;}}
  button{{background:#222;color:#eee;border:1px solid #444;
        padding:2px 8px;font:inherit;cursor:pointer;}}
  button.on{{background:#2a4;color:#000;}}
  input[type=number]{{background:#222;color:#eee;border:1px solid #444;
                    padding:2px 4px;font:inherit;width:70px;}}
  input[type=range]{{accent-color:#6cf;}}
  select{{background:#222;color:#eee;border:1px solid #444;
        padding:2px 4px;font:inherit;}}
</style></head>
<body>
<div id=hud>
  <span>latest <b id=n>-</b></span>
  <span class=sep>|</span>
  <span>status <b id=s>starting</b></span>
  <span class=sep>|</span>
  <button id=pause>pause poll</button>
  <button id=follow class=on>follow-latest</button>
  <span class=sep>|</span>
  <button id=prev>&laquo; prev</button>
  <button id=play>play &#9654;</button>
  <button id=next>next &raquo;</button>
  <span>@ <b>fps</b> <select id=fps>
      <option value=60>60</option>
      <option value=30 selected>30</option>
      <option value=15>15</option>
      <option value=10>10</option>
      <option value=5>5</option>
      <option value=1>1</option>
    </select></span>
  <span class=sep>|</span>
  <span>jump <input id=jump type=number min=0 step=1 placeholder="frame"><button id=gojump>go</button></span>
  <span class=sep>|</span>
  <span>showing <b id=shown>-</b> / <b id=total>-</b> frames</span>
</div>
<div id=scrubrow>
  <span><b id=srange_lo>-</b></span>
  <input id=scrub type=range min=0 max=0 value=0 step=1>
  <span><b id=srange_hi>-</b></span>
</div>
<div id=wrap><img id=f alt="waiting for frames..."></div>
<script>
  const poll = {poll_ms};
  const img = document.getElementById('f');
  const nEl = document.getElementById('n');
  const sEl = document.getElementById('s');
  const shownEl = document.getElementById('shown');
  const totalEl = document.getElementById('total');
  const pauseBtn = document.getElementById('pause');
  const followBtn = document.getElementById('follow');
  const prevBtn = document.getElementById('prev');
  const playBtn = document.getElementById('play');
  const nextBtn = document.getElementById('next');
  const fpsSel = document.getElementById('fps');
  const jumpIn = document.getElementById('jump');
  const goBtn = document.getElementById('gojump');
  const scrub = document.getElementById('scrub');
  const srLo = document.getElementById('srange_lo');
  const srHi = document.getElementById('srange_hi');
  let paused = false, follow = true, latest = -1, shown = -1;
  let frames = [];
  let playing = false, playTimer = null;

  function idxOf(n) {{
    let lo = 0, hi = frames.length - 1;
    while (lo <= hi) {{
      const mid = (lo + hi) >> 1;
      if (frames[mid] === n) return mid;
      if (frames[mid] < n) lo = mid + 1; else hi = mid - 1;
    }}
    return -1;
  }}

  function nearestIdx(n) {{
    let lo = 0, hi = frames.length;
    while (lo < hi) {{
      const mid = (lo + hi) >> 1;
      if (frames[mid] < n) lo = mid + 1; else hi = mid;
    }}
    if (lo === 0) return 0;
    if (lo === frames.length) return frames.length - 1;
    return (frames[lo] - n) < (n - frames[lo - 1]) ? lo : lo - 1;
  }}

  function show(n) {{
    if (frames.length === 0) return;
    const i = idxOf(n);
    const realN = (i >= 0) ? n : frames[nearestIdx(n)];
    img.src = '/frame/' + realN + '?t=' + Date.now();
    shown = realN;
    shownEl.textContent = realN;
    const si = idxOf(realN);
    if (si >= 0) scrub.value = si;
  }}

  function stopPlay() {{
    if (playTimer) {{ clearInterval(playTimer); playTimer = null; }}
    playing = false;
    playBtn.classList.remove('on');
    playBtn.innerHTML = 'play &#9654;';
  }}

  function startPlay() {{
    if (frames.length === 0) return;
    follow = false; followBtn.classList.remove('on');
    playing = true;
    playBtn.classList.add('on');
    playBtn.innerHTML = 'stop &#9632;';
    const interval = Math.max(15, Math.round(1000 / Number(fpsSel.value)));
    if (playTimer) clearInterval(playTimer);
    playTimer = setInterval(() => {{
      if (shown < 0) {{ show(frames[0]); return; }}
      let i = idxOf(shown);
      if (i < 0) i = nearestIdx(shown);
      if (i >= frames.length - 1) {{ stopPlay(); return; }}
      show(frames[i + 1]);
    }}, interval);
  }}

  async function pollLatest() {{
    if (paused) return;
    try {{
      const r = await fetch('/latest?t=' + Date.now());
      const j = await r.json();
      latest = j.frame;
      nEl.textContent = latest >= 0 ? latest : '-';
      sEl.textContent = 'live';
      if (follow && latest >= 0 && latest !== shown) show(latest);
    }} catch (e) {{ sEl.textContent = 'err'; }}
  }}

  async function pollFrames() {{
    try {{
      const r = await fetch('/frames?t=' + Date.now());
      frames = await r.json();
      totalEl.textContent = frames.length;
      if (frames.length > 0) {{
        scrub.min = 0;
        scrub.max = frames.length - 1;
        srLo.textContent = frames[0];
        srHi.textContent = frames[frames.length - 1];
        if (jumpIn.min === '' || Number(jumpIn.min) > frames[0]) jumpIn.min = frames[0];
        if (jumpIn.max === '' || Number(jumpIn.max) < frames[frames.length - 1]) jumpIn.max = frames[frames.length - 1];
        if (shown >= 0) {{
          const si = idxOf(shown);
          if (si >= 0) scrub.value = si;
        }}
      }}
    }} catch (e) {{}}
  }}

  pauseBtn.onclick = () => {{
    paused = !paused;
    pauseBtn.classList.toggle('on', paused);
    pauseBtn.textContent = paused ? 'resume poll' : 'pause poll';
  }};

  followBtn.onclick = () => {{
    follow = !follow;
    followBtn.classList.toggle('on', follow);
    if (follow) {{ stopPlay(); if (latest >= 0) show(latest); }}
  }};

  prevBtn.onclick = () => {{
    follow = false; followBtn.classList.remove('on'); stopPlay();
    if (frames.length === 0) return;
    let i = idxOf(shown);
    if (i < 0) i = nearestIdx(shown);
    if (i > 0) show(frames[i - 1]);
  }};

  nextBtn.onclick = () => {{
    follow = false; followBtn.classList.remove('on'); stopPlay();
    if (frames.length === 0) return;
    let i = idxOf(shown);
    if (i < 0) i = nearestIdx(shown);
    if (i < frames.length - 1) show(frames[i + 1]);
  }};

  playBtn.onclick = () => {{
    if (playing) stopPlay(); else startPlay();
  }};

  fpsSel.onchange = () => {{
    if (playing) {{ stopPlay(); startPlay(); }}
  }};

  const jumpTo = () => {{
    const n = Number(jumpIn.value);
    if (!Number.isFinite(n) || frames.length === 0) return;
    follow = false; followBtn.classList.remove('on'); stopPlay();
    show(frames[nearestIdx(n)]);
  }};

  goBtn.onclick = jumpTo;
  jumpIn.addEventListener('keydown', (e) => {{ if (e.key === 'Enter') jumpTo(); }});
  scrub.oninput = () => {{
    if (frames.length === 0) return;
    follow = false; followBtn.classList.remove('on'); stopPlay();
    const i = Number(scrub.value);
    if (i >= 0 && i < frames.length) show(frames[i]);
  }};

  document.addEventListener('keydown', (e) => {{
    if (e.target === jumpIn) return;
    if (e.key === ' ') {{ e.preventDefault(); playBtn.click(); }}
    else if (e.key === 'ArrowLeft') prevBtn.click();
    else if (e.key === 'ArrowRight') nextBtn.click();
    else if (e.key === 'f' || e.key === 'F') followBtn.click();
    else if (e.key === 'g' || e.key === 'G') {{ e.preventDefault(); jumpIn.focus(); }}
  }});

  setInterval(pollLatest, poll);
  setInterval(pollFrames, Math.max(500, poll * 5));
  pollFrames().then(pollLatest);
</script></body></html>
""".encode("utf-8")


def make_handler(frames_dir: pathlib.Path, html: bytes):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a, **k):
            return

        def _send(self, status, ctype, body, *, cache=False):
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            if not cache:
                self.send_header("Cache-Control", "no-store")
            self.end_headers()
            if body:
                self.wfile.write(body)

        def do_GET(self):
            path = urllib.parse.urlparse(self.path).path
            if path in ("/", "/index.html"):
                return self._send(200, "text/html; charset=utf-8", html)
            if path == "/latest":
                n, name, ext = latest(frames_dir)
                body = json.dumps({"frame": n, "name": name, "ext": ext}).encode()
                return self._send(200, "application/json", body)
            if path == "/frames":
                body = json.dumps(list_frames(frames_dir)).encode()
                return self._send(200, "application/json", body)
            if path.startswith("/frame/"):
                token = path[len("/frame/"):]
                try:
                    n = int(token)
                except ValueError:
                    return self._send(404, "text/plain", b"bad frame id")
                for ext in ("bmp", "jpg", "png"):
                    fpath = frames_dir / f"frame_{n:05d}.{ext}"
                    if fpath.is_file():
                        try:
                            data = fpath.read_bytes()
                        except OSError:
                            return self._send(500, "text/plain", b"read error")
                        return self._send(200, CONTENT_TYPES[ext], data)
                return self._send(404, "text/plain", b"no such frame")
            return self._send(404, "text/plain", b"not found")

    return H


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--dir",
        default=str(DEFAULT_DIR),
        help=f"frames directory (default: {DEFAULT_DIR})",
    )
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8766)
    ap.add_argument(
        "--poll",
        type=int,
        default=100,
        help="browser poll interval in ms (default: 100)",
    )
    args = ap.parse_args()

    frames_dir = pathlib.Path(args.dir).expanduser().resolve()
    if not frames_dir.exists():
        print(
            f"warning: {frames_dir} does not exist yet; will serve 404s "
            "until the sim creates it",
            file=sys.stderr,
        )

    html = build_html(args.poll)
    handler = make_handler(frames_dir, html)
    server = http.server.ThreadingHTTPServer((args.host, args.port), handler)
    url = f"http://{args.host}:{args.port}/"
    print(f"framewatch: {frames_dir}", file=sys.stderr)
    print(f"            {url}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbye", file=sys.stderr)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

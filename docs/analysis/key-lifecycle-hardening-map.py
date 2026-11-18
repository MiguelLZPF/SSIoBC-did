#!/usr/bin/env python3
"""Generator for key-lifecycle-hardening-map.html (standard library only).

Run: python3 key-lifecycle-hardening-map.py
Writes the HTML next to this file. Edit layout here, never in the HTML.
Style: AMOLED card gallery. Surfaces are pure #000, separation by white-alpha
outlines, hue only as rings, glows and text.
"""
import html
import os

W = 720
CH = 6.7  # estimated px per character at 12 px


def esc(s):
    return html.escape(s, quote=True)


def wrap(text, width_px, size=12):
    per = CH * size / 12.0
    maxc = max(8, int(width_px / per))
    out, cur = [], ""
    for w in text.split(" "):
        if cur and len(cur) + 1 + len(w) > maxc:
            out.append(cur)
            cur = w
        else:
            cur = (cur + " " + w) if cur else w
    if cur:
        out.append(cur)
    return out


class Fig:
    def __init__(self, label):
        self.label = label
        self.parts = []
        self.h = 0

    def add(self, s):
        self.parts.append(s)

    def text(self, x, y, s, cls="bs", anchor="start"):
        self.add('<text x="%.1f" y="%.1f" class="%s" text-anchor="%s">%s</text>' % (x, y, cls, anchor, esc(s)))

    def line(self, x1, y1, x2, y2, cls="ln", marker=None):
        m = ' marker-end="url(#ar-%s)"' % marker if marker else ""
        self.add('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" class="%s"%s/>' % (x1, y1, x2, y2, cls, m))

    def path(self, d, cls="ln", marker=None):
        m = ' marker-end="url(#ar-%s)"' % marker if marker else ""
        self.add('<path d="%s" fill="none" class="%s"%s/>' % (d, cls, m))

    def rect(self, x, y, w, h, cls):
        self.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="10" class="%s"/>' % (x, y, w, h, cls))

    def box_h(self, w, title, lines):
        n = 0
        for l in lines:
            n += len(wrap(l[0] if isinstance(l, tuple) else l, w - 24))
        return 14 + (18 if title else 0) + 16 * n + 8

    def box(self, x, y, w, title, lines, hue, dash=False, h=None, glow=False):
        bh = self.box_h(w, title, lines)
        if h is None:
            h = bh
        cls = "box %s%s" % (hue, " dash" if dash else "")
        if glow:
            self.add('<g filter="url(#gl-%s)">' % hue)
        self.rect(x, y, w, h, cls)
        if glow:
            self.add("</g>")
        ty = y + 22
        if title:
            self.text(x + 12, ty, title, "bt tx-" + hue)
            ty += 18
        for l in lines:
            t, c = (l if isinstance(l, tuple) else (l, "bs2"))
            for seg in wrap(t, w - 24):
                self.text(x + 12, ty, seg, c)
                ty += 16
        return h

    def svg(self):
        defs = (
            "<defs>"
            + "".join(
                '<filter id="gl-%s" x="-15%%" y="-40%%" width="130%%" height="180%%"><feGaussianBlur in="SourceAlpha" '
                'stdDeviation="5" result="b"/><feFlood flood-color="rgb(%s)" flood-opacity=".5"/>'
                '<feComposite in2="b" operator="in" result="g"/><feMerge><feMergeNode in="g"/>'
                '<feMergeNode in="SourceGraphic"/></feMerge></filter>' % (k, v)
                for k, v in HUES.items()
            )
            + "".join(
                '<marker id="ar-%s" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" '
                'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="rgb(%s)"/></marker>' % (k, v)
                for k, v in HUES.items()
            )
            + '<marker id="ar-w" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" '
            'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="rgba(255,255,255,.8)"/></marker>'
            "</defs>"
        )
        return '<div class="figwrap"><svg viewBox="0 0 %d %.0f" role="img" aria-label="%s" class="fig">%s%s</svg></div>' % (
            W, self.h, esc(self.label), defs, "".join(self.parts))


HUES = {"ok": "0,200,120", "warn": "255,140,0", "red": "244,67,54", "nyx": "120,110,255", "grid": "0,200,255", "pv": "255,209,0"}


# ---------------------------------------------------------------- figure 1
def fig_states():
    f = Fig("State diagram of a key bound to an address in v1.9.0")
    bw = 150
    xs = [16, 276, 536]
    y0 = 56
    items = [
        ("Pending", ["stored 0", "named, not consented"], "warn"),
        ("Live", ["at most 365 days", "validated by its own address"], "ok"),
        ("Expired", ["by expireVm", "or by time"], "red"),
    ]
    wd = ("Withdrawn", ["stored 1", "never active, never validated"], "pv")
    note = [
        ("New edge. Before v1.9.0, expireVm on a pending key reverted VmAlreadyExpired.", "bs2"),
        ("A withdrawn key stays at stored 1: validateVm and a second expireVm both revert.", "bs"),
    ]
    h = max(f.box_h(bw, t, l) for t, l, _ in items + [wd])
    h1 = max(h, f.box_h(410, "", note))
    for x, (t, l, hue) in zip(xs, items):
        f.box(x, y0, bw, t, l, hue, h=h, glow=(hue == "ok"))
    ya = y0 + h / 2
    for i, txt in enumerate(["validateVm, called by the key's own address", "expireVm, or the time passes"]):
        cx = xs[i] + bw + 55
        ls = wrap(txt, 100)
        for j, s in enumerate(ls):
            f.text(cx, ya - 10 - 16 * (len(ls) - 1 - j), s, "bs", "middle")
        f.line(xs[i] + bw + 4, ya, xs[i + 1] - 5, ya, "ln ok" if i == 0 else "ln no", "ok" if i == 0 else "red")
    y1 = y0 + h + 96
    f.box(xs[0], y1, bw, wd[0], wd[1], "pv", dash=True, h=h1, glow=True)
    f.line(xs[0] + bw / 2, y0 + h + 4, xs[0] + bw / 2, y1 - 5, "ln new", "pv")
    f.text(xs[0] + bw / 2 + 12, y0 + h + 40, "expireVm on a pending key", "bs tx-pv")
    f.text(xs[0] + bw / 2 + 12, y0 + h + 58, "NEW in v1.9.0 (C1)", "bs tx-pv tx-b")
    f.box(xs[1], y1, 410, "", note, "pv", dash=True, h=h1)
    y2 = y1 + h1 + 24
    f.text(16, y2, "Also in v1.9.0: validateVm needs an active DID (C2) and stores at most 365 days (C3).", "bs")
    f.h = y2 + 14
    return f


# ---------------------------------------------------------------- figure 2
def fig_limits():
    f = Fig("Three limits of v1.8.0 and the change that closes each")
    lx, rx, cw = 16, 372, 332
    y = 14
    rows = [
        ("L3  Pending key stuck", ["expireVm on a pending key reverts VmAlreadyExpired. There is no way to take a naming back."],
         "C1  expireVm withdraws it", ["The key is marked withdrawn (stored 1). Its address can never validate it."]),
        ("L2  Validate on a dead DID", ["A pending key can be validated on a deactivated DID, and then reactivate it."],
         "C2  Active DID required", ["validateVm reverts DidExpired when the DID is deactivated or lapsed."]),
        ("L1  Any lifetime", ["The validator chooses any lifetime, up to the largest 88-bit value."],
         "C3  365 days at most", ["A request above 365 days, or 0, is stored as 365 days, without an error."]),
    ]
    f.text(lx, y + 10, "Before (v1.8.0)", "gate")
    f.text(rx, y + 10, "After (v1.9.0, planned)", "gate")
    y += 22
    for lt, ll, rt, rl in rows:
        h = max(f.box_h(cw, lt, ll), f.box_h(cw, rt, rl))
        f.box(lx, y, cw, lt, ll, "red", dash=True, h=h)
        f.box(rx, y, cw, rt, rl, "ok", h=h, glow=True)
        f.line(lx + cw + 4, y + h / 2, rx - 5, y + h / 2, "ln ok", "ok")
        y += h + 12
    f.h = y + 2
    return f


# ---------------------------------------------------------------- figure 3
def fig_cost():
    f = Fig("What each change costs")
    cw, gap = 224, 12
    cards = [
        ("C1  withdraw", "ok", [("+39 gas", "num big tx-ok"), ("on the success path", "bs"), ("no new revert", "bs2"), ("one revert is removed", "bs")]),
        ("C2  active DID", "warn", [("+2,300 gas", "num big tx-warn"), ("per validation", "bs"), ("one new revert: DidExpired", "bs2"),
                                     ("owner decision, against the recommendation", "bs")]),
        ("C3  cap", "ok", [("no new revert", "num big tx-ok"), ("silent clamp to 365 days", "bs2"), ("gas inside the C2 measure, not measured alone", "bs")]),
    ]
    y = 14
    h = max(f.box_h(cw, t, l) for t, _, l in cards)
    for i, (t, hue, l) in enumerate(cards):
        f.box(16 + i * (cw + gap), y, cw, t, l, hue, h=h, glow=True)
    y += h + 14
    tot = [("+100 B (Full) and +109 B (Native) per manager, all three together (with the withdrawal marker).", "num big tx-nyx"),
           ("ABI identical to v1.8.0: no function, event or error added, removed or re-typed.", "bs2")]
    th = f.box_h(688, "All three together", tot)
    f.box(16, y, 688, "All three together", tot, "nyx", h=th)
    f.h = y + th + 14
    return f


# ---------------------------------------------------------------- figure 4
def fig_remains():
    f = Fig("What remains after v1.9.0")
    cw = 338
    cells = [
        ("Late open-call key", ["A contract key validated late by a stranger can outlive the owner's first key by up to a year."]),
        ("Spoiled key", ["A validator can still choose a past expiration. It harms one key id only."]),
        ("Undo by any live key", ["Any live authentication key can still undo a deactivation (decision D5 of v1.8.0)."]),
        ("No way back", ["A deactivated DID with no live key and no controller cannot come back."]),
    ]
    y = 14
    for r in range(2):
        a, b = cells[2 * r], cells[2 * r + 1]
        h = max(f.box_h(cw, a[0], a[1]), f.box_h(cw, b[0], b[1]))
        f.box(16, y, cw, a[0], a[1], "warn", dash=True, h=h)
        f.box(16 + cw + 12, y, cw, b[0], b[1], "warn", dash=True, h=h)
        y += h + 12
    f.h = y + 2
    return f


CSS = """
:root{--bg:#000;--fg:#fff;--sec:rgba(255,255,255,.72);--card-line:rgba(255,255,255,.24);--outline:rgba(255,255,255,.16);--hair:rgba(255,255,255,.14);
--ok:0,200,120;--warn:255,140,0;--red:244,67,54;--nyx:120,110,255;--nyxt:150,140,255;--grid:0,200,255;--pv:255,209,0;color-scheme:dark}
*{box-sizing:border-box}
html{background:#000}
body{background:#000;color:#fff;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;font-size:15px;line-height:1.55;margin:0;padding:28px 16px 48px}
main{max-width:760px;margin:0 auto;display:grid;grid-template-columns:minmax(0,1fr);gap:30px}
section,header{min-width:0}
h1{font-size:2rem;font-weight:800;margin:0;letter-spacing:-.01em;line-height:1.2}
h2{font-size:1.2rem;font-weight:800;margin:0 0 4px}
.lede{color:var(--sec);margin:6px 0 0}
.status{display:inline-block;font-size:.76rem;font-weight:700;padding:3px 10px;border-radius:999px;background:#000;border:2px solid rgba(var(--warn),.6);color:rgb(var(--warn));box-shadow:0 0 16px -4px rgba(var(--warn),.75);margin-top:10px}
.cap{color:var(--sec);font-size:.9rem;margin:2px 0 10px}
.figwrap{background:#000;border:2px solid var(--card-line);border-radius:14px;padding:8px;overflow-x:auto}
.fig{width:100%;min-width:640px;height:auto;display:block;background:#000}
.hint{display:none;color:var(--sec);font-size:.78rem;margin:0 0 6px}
@media (max-width:640px){.hint{display:block}}
.fig text{font-family:system-ui,-apple-system,"Segoe UI",sans-serif;fill:#fff}
.fig .bt{font-weight:800;font-size:14px}.fig .bs{font-size:12px;fill:rgba(255,255,255,.72)}.fig .bs2{font-size:12px;fill:#fff}
.fig .num{font-family:ui-monospace,Menlo,monospace;font-size:12px;fill:rgba(255,255,255,.72)}
.fig .num.big{font-weight:800;font-variant-numeric:tabular-nums}
.fig .gate{font-size:13px;font-weight:800;fill:rgb(var(--warn))}
.fig .tx-ok{fill:rgb(var(--ok))}.fig .tx-warn{fill:rgb(var(--warn))}.fig .tx-red{fill:rgb(var(--red))}.fig .tx-nyx{fill:rgb(var(--nyxt))}.fig .tx-grid{fill:rgb(var(--grid))}.fig .tx-pv{fill:rgb(var(--pv))}
.ln{stroke:rgba(255,255,255,.55);stroke-width:1.6}.ln.no{stroke:rgb(var(--red));stroke-dasharray:5 4;stroke-width:2}.ln.ok{stroke:rgb(var(--ok));stroke-width:2}
.hair{stroke:rgba(255,255,255,.14);stroke-width:1}
.box{fill:#000;stroke-width:2}.box.dash{stroke-dasharray:6 4}
.box.ok{stroke:rgba(var(--ok),.7)}.box.warn{stroke:rgba(var(--warn),.7)}.box.red{stroke:rgba(var(--red),.7)}.box.nyx{stroke:rgba(var(--nyx),.7)}.box.grid{stroke:rgba(var(--grid),.7)}.box.pv{stroke:rgba(var(--pv),.7)}.box.rack{stroke:rgba(255,255,255,.4)}
.bar{fill:#000;stroke-width:2}.bar.ok{stroke:rgb(var(--ok))}.bar.warn{stroke:rgb(var(--warn))}
.ln.new{stroke:rgb(var(--pv));stroke-width:2.5}
.fig .tx-b{font-weight:800}
code{font-family:ui-monospace,Menlo,monospace;font-size:.85em;color:#fff}
.phases{list-style:none;padding:0;margin:0;display:grid;gap:8px}
.phases li{padding:8px 12px;border-radius:12px;border:2px dashed rgba(var(--nyx),.7);background:#000;font-size:.92rem}
.phases li b{font-weight:800;color:rgb(var(--nyxt));margin-right:8px;font-variant-numeric:tabular-nums}
.phases li i{font-style:normal;font-weight:800;color:rgb(var(--warn));margin-left:6px;font-size:.8rem}
ul.plain{margin:0;padding-left:18px}ul.plain li{margin:6px 0}
.cards{display:grid;gap:12px}
.card{border:2px dashed rgba(var(--warn),.75);border-radius:14px;padding:10px 14px;background:#000}
.card h3{margin:0 0 4px;font-size:1rem;font-weight:800;color:rgb(var(--warn))}
.card p{margin:0;color:var(--sec);font-size:.92rem}
.card p b{color:#fff}
.panel{border:2px solid var(--card-line);border-radius:14px;padding:10px 14px;background:#000}
"""


def section(title, cap, fig):
    return '<section><h2>%s</h2><p class="cap">%s</p><p class="hint">Swipe the figure sideways to read it.</p>%s</section>' % (esc(title), cap, fig.svg())


def build():
    out = []
    out.append('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
    out.append("<title>Key Lifecycle Hardening: visual map (v1.9.0, planned)</title><style>%s</style></head><body><main>" % CSS)
    out.append(
        '<header><h1>Key Lifecycle Hardening</h1>'
        '<p class="lede">Three changes to the life of a key bound to an address, decided for v1.9.0: withdraw a pending key, validate only on an active DID, cap the lifetime at 365 days. '
        'Visual summary of <code>key-lifecycle-hardening-design.md</code>.</p>'
        '<span class="status">planned for v1.9.0, not built yet</span></header>'
    )
    out.append(section("1. The life of an address-bound key",
                       "One new edge: a pending key can be withdrawn by expireVm and can never be validated.", fig_states()))
    out.append(section("2. Three limits and their change",
                       "Each limit found after v1.8.0 has one change that closes or narrows it.", fig_limits()))
    out.append(section("3. What each change costs",
                       "Only C2 adds a revert and a per-call gas cost; together the three add about 100 B and 109 B per manager.", fig_cost()))
    out.append(section("4. What remains after v1.9.0",
                       "Four limits are not closed by this design.", fig_remains()))
    phases = [("Task 0", "Baseline"), ("Task 1", "Withdraw a pending key"), ("Task 2", "Active-DID rule"), ("Task 3", "Lifetime cap"),
              ("Task 4", "Property tests and mutation proof"), ("Task 5", "Code review and freeze"), ("Task 6", "Docs"),
              ("Task 7", "Metrics"), ("Task 8", "Final gate"), ("Task 9", "Release preparation, stops before the tag")]
    out.append('<section><h2>5. Phases</h2><p class="cap">Ten tasks, none started.</p><ol class="phases">%s</ol></section>' %
               "".join("<li><b>%s</b>%s<i>planned</i></li>" % (esc(a), esc(b)) for a, b in phases))
    out.append(
        '<section><h2>6. Who is affected</h2><p class="cap">Read from the sibling repositories on 2026-11-18; none is edited from here.</p><div class="cards">'
        '<div class="card"><h3>SSIoBC-vclaim</h3><p><b>Nothing changes.</b> It validates with 0, on an active DID.</p></div>'
        '<div class="card"><h3>SSIoBC-trust</h3><p><b>Four integration tests change</b> when it moves its pin: '
        '<code>test_openCallerKey_outlivesTheKeyThatNamedIt</code>, <code>test_reactivateDid_longLivedKeyReactivates</code>, and '
        '<code>test_openCallerKey_stopsWhenTheDidLapses</code> (it keeps passing but tests nothing). The fourth is its test of reactivation by a key validated after the lapse (C2). Threat model rows T5 and T6 are rewritten.</p></div>'
        '<div class="card"><h3>Integrators of keys longer than a year</h3><p><b>Keys validated for more than a year</b> are now stored as 365 days. '
        'The clamp is silent: read the stored value with <code>getExpiration</code>.</p></div>'
        '</div></section>'
    )
    out.append("</main></body></html>")
    return "\n".join(out)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "key-lifecycle-hardening-map.html")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(build())
    print("wrote", path)

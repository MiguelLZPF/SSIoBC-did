#!/usr/bin/env python3
"""Generator for contract-vm-validation-map.html (standard library only).

Run: python3 contract-vm-validation-map.py
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
def fig_callers():
    f = Fig("Who may call what: the seven guarded writes and validateVm")

    def panel(y, ltitle, llines, otitle, olines, ntitle, nlines):
        lx, lw, rx, rw = 16, 290, 380, 324
        oh = f.box_h(rw, otitle, olines)
        nh = f.box_h(rw, ntitle, nlines)
        total = oh + 14 + nh
        lh = max(f.box_h(lw, ltitle, llines), 0)
        ly = y + (total - lh) / 2
        f.box(lx, ly, lw, ltitle, llines, "nyx", h=lh)
        f.box(rx, y, rw, otitle, olines, "ok", glow=True)
        f.box(rx, y + oh + 14, rw, ntitle, nlines, "red", dash=True)
        f.line(rx - 2, y + oh / 2, lx + lw + 4, ly + lh / 2 - 8, "ln ok", "ok")
        f.line(rx - 2, y + oh + 14 + nh / 2, lx + lw + 4, ly + lh / 2 + 8, "ln no", "red")
        return y + total

    y = 14
    y = panel(
        y,
        "7 guarded writes",
        [("createDid, createVm, expireVm,", "num"), ("deactivateDid, reactivateDid,", "num"), ("updateController, updateService", "num")],
        "accepted: the EOA that signed the tx",
        ["msg.sender == tx.origin (modifier onlyDirectEOA)"],
        "refused: any contract in the call chain",
        [("reverts DirectEOACallRequired", "bs2 tx-red")],
    )
    y += 22
    f.line(16, y - 11, W - 16, y - 11, "hair")
    y = panel(
        y,
        "validateVm",
        [("the VM's address consents to be a key of the DID", "bs")],
        "accepted: only the VM's own address",
        [
            "an EOA",
            "a deployed contract",
            "a contract inside its constructor",
            "an EIP-7702 account driven by a relayer",
        ],
        "refused: any other caller",
        [("reverts InvalidSignature", "bs2 tx-red")],
    )
    f.h = y + 14
    return f


# ---------------------------------------------------------------- figure 2
def fig_flow():
    f = Fig("Issuer contract flow from createVm to a claim, and the revocation")
    bw, gap, x0 = 206, 36, 16
    xs = [x0 + i * (bw + gap) for i in range(3)]
    steps = {
        1: ("1  Controller EOA", ["calls createVm(address = issuer, 0x02)"], ("VM state: pending", "tx-warn"), "nyx"),
        2: ("2  Issuer contract", ["calls validateVm; its admin triggers it"], ("VM state: active", "tx-ok"), "grid"),
        3: ("3  Issuer contract", ["calls VClaimManager.issueClaim"], None, "grid"),
        4: ("4  VClaimManager", ["asks isAuthorized(..., 0x02, msg.sender)"], None, "pv"),
        5: ("5  DidManager", ["answers true; the claim is issued"], ("authorized", "tx-ok"), "ok"),
        6: ("R1  Controller EOA", ["calls expireVm on the issuer's VM"], ("VM state: expired", "tx-red"), "red"),
        7: ("R2  DidManager", ["isAuthorized(..., 0x02, issuer) now returns false"], ("not authorized", "tx-red"), "red"),
    }

    def draw(n, x, y, dash=False):
        title, lines, chip, hue = steps[n]
        ls = list(lines)
        if chip:
            ls.append((chip[0], "bs " + chip[1]))
        return f.box(x, y, bw, title, ls, hue if hue != "ok" else "ok", dash=dash)

    hh = max(f.box_h(bw, "x", steps[n][1] + ([("c", "bs")] if steps[n][2] else [])) for n in steps)

    def row(y, ns, dash=False):
        for i, n in enumerate(ns):
            title, lines, chip, hue = steps[n]
            ls = list(lines) + ([(chip[0], "bs " + chip[1])] if chip else [])
            f.box(xs[i], y, bw, title, ls, hue, dash=dash, h=hh)
        for i in range(len(ns) - 1):
            cls, mk = ("ln no", "red") if dash else ("ln ok", "ok")
            f.line(xs[i] + bw + 3, y + hh / 2, xs[i + 1] - 4, y + hh / 2, cls, mk)

    y1 = 14
    row(y1, [1, 2, 3])
    y2 = y1 + hh + 46
    # elbow from step 3 down to step 4
    mid = y1 + hh + 23
    f.path("M %.1f %.1f L %.1f %.1f L %.1f %.1f L %.1f %.1f" % (
        xs[2] + bw / 2, y1 + hh + 3, xs[2] + bw / 2, mid, xs[0] + bw / 2, mid, xs[0] + bw / 2, y2 - 4), "ln ok", "ok")
    row(y2, [4, 5])
    f.text(xs[2], y2 + hh / 2 - 6, "Claims by this issuer", "bs tx-ok")
    f.text(xs[2], y2 + hh / 2 + 12, "pass until the VM is expired.", "bs tx-ok")
    y3 = y2 + hh + 40
    f.text(16, y3 - 12, "Revocation, any time later", "gate")
    row(y3, [6, 7], dash=True)
    f.h = y3 + hh + 14
    return f


# ---------------------------------------------------------------- figure 3
def fig_reach():
    f = Fig("Reach of a contract key by relationship bit")
    cols = [(16, 170, "relationship bit"), (186, 120, "DidManager"), (306, 200, "VClaimManager"), (506, 198, "TrustManager")]
    rows = [
        ("0x01", "authentication", ["views only"], ["none"], ["setTrust", "removeTrust"], "nyx"),
        ("0x02", "assertionMethod", ["views only"], ["issueClaim", "issueClaims", "revokeClaim", "revokeClaims"], ["none"], "grid"),
        ("0x04, 0x08, 0x10", "keyAgreement, capabilityInvocation, capabilityDelegation", ["views only"], ["none"], ["none"], "pv"),
    ]
    y = 14
    for x, w, t in cols:
        f.rect(x, y, w, 30, "box rack")
        f.text(x + 10, y + 20, t, "bt")
    y += 38
    for bit, sub, d, v, t, hue in rows:
        cells = [d, v, t]
        # height from content
        bit_lines = [bit] + wrap(sub, cols[0][1] - 20)
        h1 = 14 + 18 + 16 * (len(bit_lines) - 1) + 6
        h = max(h1, *[12 + 17 * len(c) + 4 for c in cells], 50)
        f.rect(cols[0][0], y, cols[0][1], h, "box " + hue)
        f.text(cols[0][0] + 10, y + 22, bit, "bt tx-" + hue)
        for i, s in enumerate(wrap(sub, cols[0][1] - 20)):
            f.text(cols[0][0] + 10, y + 40 + 15 * i, s, "bs")
        for ci, c in enumerate(cells, start=1):
            x, w, _ = cols[ci]
            none = c in (["none"], ["views only"])
            f.rect(x, y, w, h, "box " + ("rack" if none else "ok"))
            for i, s in enumerate(c):
                f.text(x + 10, y + 24 + 17 * i, s, "num" if none else "num big tx-ok")
        y += h + 8
    f.rect(16, y, 688, 46, "box red dash")
    f.text(28, y + 20, "DID document writes: none, for every bit", "bt tx-red")
    f.text(28, y + 37, "All seven are guarded by onlyDirectEOA, so a contract key never reaches them.", "bs")
    y += 54
    f.text(16, y + 12, "Views only = isAuthorized, isVmRelationship, isAuthorizedOffChainWithSigner.", "bs")
    f.h = y + 26
    return f


# ---------------------------------------------------------------- figure 4
def fig_react():
    f = Fig("reactivateDid before and after the fix")
    lx, rx, cw = 16, 372, 332
    y = 14
    bl = ["Self path checked only: the address is in a 0x01 VM."]
    al = ["Both paths need a live 0x01 key (_isAuthenticated); the controller rule stays on the controller path."]
    hh = max(f.box_h(cw, "x", bl), f.box_h(cw, "x", al))
    f.box(lx, y, cw, "Before (v1.0.2 to v1.7.0)", bl, "red", dash=True, h=hh)
    f.box(rx, y, cw, "After (v1.8.0)", al, "ok", h=hh, glow=True)
    y += hh + 16
    cases = [
        ("Key expired by the owner, DID deactivated, that key reactivates.", "succeeds", "reverts VmAlreadyExpired", True),
        ("Address named but never validated reactivates.", "succeeds", "reverts VmAlreadyExpired", True),
        ("A controller deactivated the DID; the DID's own key reactivates.", "succeeds", "still allowed while that key is live (owner decision D5)", False),
        ("No controller, deactivated, key lifetime passed: the owner reactivates.", "succeeds", "reverts VmAlreadyExpired", True),
    ]
    for c, b, a, wrong in cases:
        lines_l = [(c, "bs2"), (b + (" (wrongly)" if wrong else ""), "bs tx-red" if wrong else "bs tx-ok")]
        lines_r = [(a, "bs tx-ok")]
        lines_rr = [(c, "bs")] + lines_r
        h = max(f.box_h(cw, "", lines_l), f.box_h(cw, "", lines_rr) + 6)
        f.box(lx, y, cw, "", lines_l, "red" if wrong else "ok", h=h)
        f.box(rx, y, cw, "", lines_rr, "ok", h=h)
        f.line(lx + cw + 4, y + h / 2, rx - 5, y + h / 2, "ln ok", "ok")
        y += h + 10
    f.text(16, y + 12, "The _isVmOwner hook has no caller left and is deleted: 9 hooks become 8. No ABI change.", "bs")
    f.h = y + 26
    return f


# ---------------------------------------------------------------- figure 5
def fig_cost():
    f = Fig("Measured cost of the chosen mechanism against the rejected one")
    ax = 360
    y = 14

    def panel(y, title, unit, items, scale):
        f.text(16, y + 14, title, "bt")
        y += 30
        f.line(ax, y - 6, ax, y + len(items) * 54 - 10, "hair")
        for name, val, note, hue in items:
            f.text(16, y + 8, name, "bs")
            bw = abs(val) * scale
            x = ax if val >= 0 else ax - bw
            f.add('<g filter="url(#gl-%s)"><rect x="%.1f" y="%.1f" width="%.1f" height="18" rx="5" class="bar %s"/></g>' % (hue, x, y + 14, bw, hue))
            lab = "%+d %s" % (val, unit)
            if val >= 0:
                f.text(ax + bw + 8, y + 28, lab + note, "num big tx-" + hue)
            else:
                f.text(ax - bw - 8, y + 28, lab + note, "num big tx-" + hue, "end")
            y += 54
        return y + 6

    y = panel(y, "Runtime size per manager, Full variant (lower is better)", "B",
              [("chosen: guard removed from validateVm", -8, " (Native -8 B)", "ok"),
               ("rejected: owner() call", 101, " (Native +98 B)", "warn")], 1.7)
    y += 8
    f.line(16, y - 4, W - 16, y - 4, "hair")
    y += 10
    y = panel(y, "validateVm median gas, EOA path (lower is better)", "gas",
              [("chosen: guard removed from validateVm", -45, " (35,357 to 35,312)", "ok"),
               ("rejected: owner() call", 26, " (35,357 to 35,383)", "warn")], 3.2)
    f.h = y + 6
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
    out.append("<title>Contract Address as a Validated Verification Method: visual map (v1.8.0, implemented on the branch)</title><style>%s</style></head><body><main>" % CSS)
    out.append(
        '<header><h1>Contract Address as a Validated Verification Method</h1>'
        '<p class="lede">End state of v1.8.0. A deployed contract can be an active key of a DID, and still cannot change any DID document. '
        'Visual summary of <code>contract-vm-validation-design.md</code>.</p>'
        '<span class="status">implemented on the branch, not released</span></header>'
    )
    out.append(section("1. Who may call what",
                       "The seven writes accept only the EOA that signed the transaction; validateVm accepts only the VM's own address.",
                       fig_callers()))
    out.append(section("2. The issuer contract flow",
                       "A contract becomes an issuer key in three calls, and the controller can switch it off with one.",
                       fig_flow()))
    out.append(section("3. What a contract key can reach",
                       "A contract key reaches trust and claim functions by its bit, and never a DID document write.",
                       fig_reach()))
    out.append(section("4. reactivateDid, before and after",
                       "Three cases that wrongly succeeded now revert, because both paths need a live key. The fourth stays allowed by owner decision D5.",
                       fig_react()))
    out.append(section("5. What the chosen mechanism costs",
                       "Removing the guard on validateVm makes each manager 8 B smaller; the rejected owner() call adds about 100 B. Measured for v1.8.0: DidManager 12,766 B and DidManagerNative 11,897 B, 162 B and 244 B below v1.7.0 (docs/assets/data/sizes-v1.8.0.txt).",
                       fig_cost()))
    phases = [
        ("Task 0", "Baseline", "done"), ("Task 1", "validateVm", "done"), ("Task 2", "Property tests and mutation proof", "done"),
        ("Task 3", "Reactivation rule", "done"), ("Task 4", "Issuer integration test", "done"), ("Task 5", "Branch code review", "done"), ("Task 6", "Docs", "done"),
        ("Task 7", "Metrics", "done"), ("Task 8", "Final gate", "done"), ("Task 9", "Release preparation", "waits for the owner: push, pull request, tag"),
    ]
    out.append('<section><h2>6. Phases</h2><p class="cap">Ten tasks: 0 to 8 done; 9 (release preparation) waits for the owner: push, pull request, tag.</p><ol class="phases" style="list-style:none">%s</ol></section>' %
               "".join("<li><b>%s</b>%s<i>%s</i></li>" % (esc(a), esc(b), esc(c)) for a, b, c in phases))
    stays = [
        "The address is bound, not its code. A contract that changes its behaviour later keeps the key.",
        "A contract that executes arbitrary calls can be validated by anyone, once a controller names it.",
        "A DID must keep one EOA authentication key; the seven writes need one.",
        "A deactivated DID with no controller and no live key cannot come back.",
        "A controller's deactivation is not final while the DID has a live key of its own.",
    ]
    out.append('<section><h2>7. What stays true, what to watch</h2><p class="cap">Limits that remain after v1.8.0.</p><div class="panel"><ul class="plain">%s</ul></div></section>' %
               "".join("<li>%s</li>" % esc(s) for s in stays))
    out.append(
        '<section><h2>8. Decisions and not covered</h2><p class="cap">Both decisions are taken (owner, 2026-11-17).</p><div class="cards">'
        '<div class="card"><h3>D5 decided, B: the DID\'s own live key can reactivate</h3>'
        '<p>Decided: <b>B</b>. The self path checks a live key only; the controller rule applies on the controller path only. A controller\'s deactivation is not final while the DID has a live key of its own.</p></div>'
        '<div class="card"><h3>D6 decided, A: such a DID cannot come back</h3>'
        '<p>Decided: <b>A</b>. Accepted and documented: a deactivated DID with no controller whose keys have all expired is stuck. The alternative keeps a way back in, which is the behaviour being removed.</p></div>'
        '</div><p class="cap" style="margin-top:14px">Not covered by this design</p><div class="panel"><ul class="plain">'
        "<li>ERC-6492 (wallets not yet deployed): unchanged, not supported.</li>"
        "<li>Letting a contract perform DID writes: the seven document writes stay direct-EOA.</li>"
        "<li>A bound on the <code>expiration</code> argument of <code>validateVm</code>: existing behaviour, listed as a finding.</li>"
        "</ul></div></section>"
    )
    out.append("</main></body></html>")
    return "\n".join(out)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "contract-vm-validation-map.html")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(build())
    print("wrote", path)

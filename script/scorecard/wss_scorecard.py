"""
WSS scorecard generator — the grid card.

    python3 wss_scorecard.py --blank out.pdf [samples] [copies]   # the default card
    python3 wss_scorecard.py config.py out.pdf                    # a custom card

ONE PAGE. ONE GRID. A row per pour, a column per criterion, circles to fill in. People are
holding a drink — they will not fill in five scales and three note lines. They will fill in
a grid.

PRINT PALETTE, ALWAYS. Scorecards get printed once per taster and written on with a pen.
They are the one WSS artifact that must never use the dark slide background: white ground,
dark ink, no filled blocks. See reference/DESIGN.md.
"""
import sys, os
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor

INK   = HexColor("#2B2018")   # headings, body
INK_L = HexColor("#6A5A48")   # secondary
AMBER = HexColor("#C0692A")   # the accent — dark enough to read on white
RULE  = HexColor("#B9A88E")   # grid lines, write-on rules
FAINT = HexColor("#DCD2C0")   # circle outlines

_FD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts")
for tag, f in [("WSS", "CrimsonText-Regular"), ("WSS-B", "CrimsonText-Bold"),
               ("WSS-I", "CrimsonText-Italic"), ("WSS-SB", "CrimsonText-SemiBold")]:
    pdfmetrics.registerFont(TTFont(tag, os.path.join(_FD, f + ".ttf")))

W, H = LETTER
M = 0.6 * inch


def _rule(c, x1, y, x2, col=RULE, w=0.6):
    c.setStrokeColor(col); c.setLineWidth(w); c.line(x1, y, x2, y)


def card(c, cfg):
    samples = cfg["samples"]
    crit    = cfg.get("criteria", ["NOSE", "TASTE", "FINISH"])
    ticks   = cfg.get("ticks", 5)
    extras  = cfg.get("extras", ["EST. $", "BUY?"])
    top_n   = cfg.get("top_n", 3)

    # ---- masthead
    y = H - M
    c.setFont("WSS", 9); c.setFillColor(INK_L)
    c.drawString(M, y, "THE WHISKEY SHARE SOCIETY")
    y -= 26
    c.setFont("WSS-B", 22); c.setFillColor(INK)
    c.drawString(M, y, cfg["title"])
    y -= 15
    c.setFont("WSS-I", 10.5); c.setFillColor(AMBER)
    c.drawString(M, y, cfg["subtitle"])

    c.setFont("WSS-SB", 9); c.setFillColor(AMBER)
    c.drawString(W - M - 210, y + 15, "NAME")
    _rule(c, W - M - 168, y + 13, W - M)

    y -= 16
    _rule(c, M, y, W - M, AMBER, 1.2)
    y -= 15
    c.setFont("WSS-I", 9.5); c.setFillColor(INK_L)
    c.drawString(M, y, cfg["instruction"])

    # ---- grid geometry
    y -= 22
    label_w = cfg.get("label_w", 74)
    ex_w    = 52
    grid_w  = W - 2 * M
    crit_w  = (grid_w - label_w - ex_w * len(extras)) / len(crit)

    # header row
    hy = y
    c.setFont("WSS-SB", 8.5); c.setFillColor(AMBER)
    c.drawString(M + 2, hy, cfg.get("label_head", "SAMPLE"))
    for i, name in enumerate(crit):
        cx = M + label_w + i * crit_w
        c.drawString(cx + 4, hy, name.upper())
    for j, e in enumerate(extras):
        ex = M + label_w + len(crit) * crit_w + j * ex_w
        c.drawString(ex + 4, hy, e.upper())
    hy -= 4
    _rule(c, M, hy, W - M, INK, 0.9)

    # ---- rows
    rows_top = hy
    rh = cfg.get("row_h", 30)
    for r, s in enumerate(samples):
        ry = rows_top - 16 - r * rh
        c.setFont("WSS-B", 11 if len(str(s)) <= 2 else 9.5)
        c.setFillColor(INK)
        c.drawString(M + 2, ry - 4, str(s).upper())

        for i in range(len(crit)):
            cx = M + label_w + i * crit_w
            step = min(17, (crit_w - 14) / ticks)
            for t in range(ticks):
                tx = cx + 7 + t * step
                c.setStrokeColor(FAINT); c.setLineWidth(0.7)
                c.circle(tx, ry - 1, 6.2, fill=0, stroke=1)
                c.setFont("WSS", 6.5); c.setFillColor(FAINT)
                c.drawCentredString(tx, ry - 3.2, str(t + 1))

        for j in range(len(extras)):
            ex = M + label_w + len(crit) * crit_w + j * ex_w
            if extras[j].upper().startswith("BUY") or extras[j].upper().startswith("ORDER"):
                c.setFont("WSS", 9.5); c.setFillColor(INK_L)
                c.drawString(ex + 8, ry - 4, "Y      N")
            elif extras[j].upper().startswith("TOTAL"):
                c.setFont("WSS", 9.5); c.setFillColor(FAINT)
                c.drawString(ex + 10, ry - 4, "/ %d" % (ticks * len(crit)))
            else:
                c.setFont("WSS", 9.5); c.setFillColor(INK_L)
                c.drawString(ex + 4, ry - 4, "$")
                _rule(c, ex + 13, ry - 6, ex + ex_w - 6, FAINT)
        _rule(c, M, ry - rh + 14, W - M, FAINT, 0.5)

    y = rows_top - 16 - (len(samples) - 1) * rh - rh + 14

    # ---- notes (only when there's room: few samples)
    if cfg.get("note_lines"):
        y -= 20
        c.setFont("WSS-SB", 9); c.setFillColor(AMBER)
        c.drawString(M, y, cfg.get("note_head", "NOTES").upper())
        for i in range(cfg["note_lines"]):
            _rule(c, M, y - 16 - i * 17, W - M, FAINT, 0.5)
        y = y - 16 - (cfg["note_lines"] - 1) * 17

    # ---- closing questions
    y -= 26
    _rule(c, M, y + 14, W - M, AMBER, 1)
    for q in cfg["questions"]:
        c.setFont("WSS-SB", 9); c.setFillColor(INK)
        c.drawString(M, y, q.upper())
        qw = c.stringWidth(q.upper(), "WSS-SB", 9)
        if top_n and "TOP" in q.upper():
            x = M + qw + 12
            for k in range(top_n):
                c.setFont("WSS", 9.5); c.setFillColor(INK_L)
                c.drawString(x, y, "%d." % (k + 1))
                _rule(c, x + 12, y - 2, x + 110)
                x += 128
        else:
            _rule(c, M + qw + 12, y - 2, W - M)
        y -= 26

    # ---- epigram
    c.setFont("WSS-I", 9.5); c.setFillColor(INK_L)
    c.drawCentredString(W / 2, M - 12, cfg.get("epigram", ""))
    c.showPage()


BLANK = {
    "title": "Tasting Scorecard",
    "subtitle": "Session ______________________________     Date ______________",
    "instruction": "Rate each sample 1-5 (fill the circle). Note what it is, and whether you'd buy it.",
    "label_head": "SAMPLE",
    "samples": ["A", "B", "C", "D", "E", "F"],
    "criteria": ["NOSE", "TASTE", "FINISH"],
    "ticks": 5,
    "extras": ["TOTAL", "EST. $", "BUY?"],
    "note_lines": 3,
    "note_head": "What's in the glass? · Notes",
    "questions": ["My top three, by taste:", "Biggest surprise:"],
    "top_n": 3,
    "epigram": "“Write before you talk. The first note is the honest one.”",
}


def build(cfg, out, copies=12):
    c = canvas.Canvas(out, pagesize=LETTER)
    for _ in range(copies):
        card(c, cfg)
    c.save()
    return out


if __name__ == "__main__":
    if sys.argv[1] == "--blank":
        cfg = dict(BLANK)
        if len(sys.argv) > 3:
            cfg["samples"] = [chr(65 + i) for i in range(int(sys.argv[3]))]
        print("wrote", build(cfg, sys.argv[2], int(sys.argv[4]) if len(sys.argv) > 4 else 12))
    else:
        ns = {}
        exec(open(sys.argv[1]).read(), ns)
        print("wrote", build(ns["CONFIG"], sys.argv[2], ns.get("COPIES", 12)))

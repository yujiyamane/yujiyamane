"""Convert a text string to outlined SVG paths using fontTools.

Usage:
  python outline_text.py --font F.ttf --text "abc" --size 24 --x 10 --y 50 \
      --fill "#F4C86A" [--letter-spacing 0.18] [--vertical] [--id kicker]

Prints a single <g> SVG fragment to stdout. Glyphs are emitted as <path>
elements in font units inside a group that translates to (x, y) and scales
by size/unitsPerEm with a Y-flip (font coords are y-up, SVG is y-down).
Vertical mode stacks glyphs top-to-bottom (for tategaki hanko text).
"""
import argparse
import sys

from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True)
    ap.add_argument("--text", required=True)
    ap.add_argument("--size", type=float, required=True)
    ap.add_argument("--x", type=float, default=0)
    ap.add_argument("--y", type=float, default=0)
    ap.add_argument("--fill", default="#000000")
    ap.add_argument("--letter-spacing", type=float, default=0.0,
                    help="extra tracking in em")
    ap.add_argument("--vertical", action="store_true")
    ap.add_argument("--id", default=None)
    ap.add_argument("--measure", action="store_true",
                    help="print advance width in px instead of SVG")
    args = ap.parse_args()

    font = TTFont(args.font)
    upm = font["head"].unitsPerEm
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    scale = args.size / upm
    tracking = args.letter_spacing * upm  # font units

    paths = []
    pen_x = 0.0
    pen_y = 0.0
    for ch in args.text:
        gname = cmap.get(ord(ch))
        if gname is None:
            gname = ".notdef"
        pen = SVGPathPen(glyph_set)
        glyph_set[gname].draw(pen)
        d = pen.getCommands()
        adv = hmtx[gname][0]
        if d:
            paths.append(
                f'<path transform="translate({pen_x:.1f} {pen_y:.1f})" d="{d}"/>')
        if args.vertical:
            pen_y -= upm + tracking  # y-up before flip: next glyph lower
        else:
            pen_x += adv + tracking

    if args.measure:
        total = (pen_x - tracking) * scale if not args.vertical else args.size
        print(f"{total:.2f}")
        return

    gid = f' id="{args.id}"' if args.id else ""
    frag = (
        f'<g{gid} fill="{args.fill}" '
        f'transform="translate({args.x} {args.y}) scale({scale:.6f} {-scale:.6f})">'
        + "".join(paths) + "</g>"
    )
    sys.stdout.buffer.write(frag.encode("utf-8"))


if __name__ == "__main__":
    main()

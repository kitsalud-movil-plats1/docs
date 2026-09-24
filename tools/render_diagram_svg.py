#!/usr/bin/env python3
"""Renderiza diagrama-logico.lucid.json (Lucid Standard Import) a SVG.

Sirve para versionar una imagen del diagrama junto al documento. La fuente
oficial sigue siendo el documento en Lucidchart; este SVG es una copia fiel
generada a partir de la misma especificación.

Uso: python3 render_diagram_svg.py <entrada.lucid.json> <salida.svg>
"""
import html
import json
import re
import sys


def text_lines(raw):
    """Convierte el HTML simple de Lucid en [(texto, negrita_inicial, resto)]."""
    m = re.search(r"font-size:(\d+)px", raw or "")
    size = int(m.group(1)) if m else 12
    body = re.sub(r"</?p[^>]*>", "", raw or "")
    out = []
    for part in body.split("<br>"):
        b = re.match(r"\s*<b>(.*?)</b>(.*)", part)
        if b:
            out.append((html.unescape(b.group(1)), html.unescape(re.sub(r"<[^>]+>", "", b.group(2)))))
        else:
            out.append(("", html.unescape(re.sub(r"<[^>]+>", "", part))))
    return size, out


def esc(s):
    return html.escape(s, quote=True)


def render(doc):
    page = doc["pages"][0]
    shapes = {s["id"]: s for s in page["shapes"]}
    W = max(s["boundingBox"]["x"] + s["boundingBox"]["w"] for s in page["shapes"]) + 20
    H = max(s["boundingBox"]["y"] + s["boundingBox"]["h"] for s in page["shapes"]) + 20
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
         f'font-family="Liberation Sans, Arial, sans-serif">',
         f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>']
    for s in page["shapes"]:
        bb = s["boundingBox"]; x, y, w, h = bb["x"], bb["y"], bb["w"], bb["h"]
        st = s.get("style", {})
        fill = st.get("fill", {}).get("color", "#FFFFFF")
        stroke = st.get("stroke", {}).get("color", "#333333")
        sw = st.get("stroke", {}).get("width", 1)
        dash = ' stroke-dasharray="10,6"' if st.get("stroke", {}).get("style") == "dashed" else ""
        t = s["type"]
        if t == "cloud":
            o.append(f'<ellipse cx="{x+w/2}" cy="{y+h/2}" rx="{w/2}" ry="{h/2}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
        else:
            rx = 18 if t == "roundedRectangleContainer" else 6
            o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{dash}/>')
        if "containerTitle" in s:
            title = s["containerTitle"]["text"]
            tw = 9.2 * len(title) + 20
            o.append(f'<rect x="{x}" y="{y-38}" width="{tw}" height="30" rx="4" fill="{stroke}"/>')
            o.append(f'<text x="{x+10}" y="{y-17}" font-size="17" fill="#FFFFFF">{esc(title)}</text>')
        if s.get("text"):
            size, lines = text_lines(s["text"])
            lh = size * 1.35
            y0 = y + h / 2 - (len(lines) - 1) * lh / 2 + size * 0.35
            for i, (bold, rest) in enumerate(lines):
                o.append(f'<text x="{x+w/2}" y="{y0+i*lh}" font-size="{size}" text-anchor="middle" fill="#111111">'
                         + (f'<tspan font-weight="bold">{esc(bold)}</tspan>' if bold else "")
                         + esc(rest) + "</text>")
    for l in page["lines"]:
        pts = []
        for ep in (l["endpoint1"], l["endpoint2"]):
            bb = shapes[ep["shapeId"]]["boundingBox"]; p = ep.get("position", {"x": 0.5, "y": 0.5})
            pts.append((bb["x"] + p["x"] * bb["w"], bb["y"] + p["y"] * bb["h"]))
        (x1, y1), (x2, y2) = pts
        stc = l.get("stroke", {})
        o.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stc.get("color", "#333")}" stroke-width="{stc.get("width", 2)}"/>')
        for lt in l.get("text", []):
            label = re.sub(r"<[^>]+>", "", lt["text"]); pos = lt.get("position", 0.5)
            lx, ly = x1 + (x2 - x1) * pos, y1 + (y2 - y1) * pos
            lw = 7 * len(label) + 16
            o.append(f'<rect x="{lx-lw/2}" y="{ly-11}" width="{lw}" height="22" fill="#FFFFFF"/>')
            o.append(f'<text x="{lx}" y="{ly+4}" font-size="12" text-anchor="middle">{esc(label)}</text>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as f:
        svg = render(json.load(f))
    with open(dst, "w", encoding="utf-8") as f:
        f.write(svg)

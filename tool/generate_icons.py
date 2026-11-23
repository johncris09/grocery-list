"""Render the app icon PNGs (concept B "checklist card") with Pillow.

Outputs (1024x1024) into assets/icon/:
  icon.png             full-bleed icon for iOS and legacy Android
  icon_foreground.png  Android adaptive foreground (transparent, safe-zone scaled)
  icon_monochrome.png  Android 13+ themed-icon silhouette

Then run:  dart run flutter_launcher_icons
Geometry matches assets/icon/icon.svg (108-unit grid).
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"
SIZE = 1024
SS = 4  # supersampling factor

CREAM = (0xF4, 0xF3, 0xEE, 255)
GREEN = (0x2E, 0x6B, 0x4F, 255)
GREEN_DARK = (0x1F, 0x4D, 0x38, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

# Content bounding box in the 108 grid (card + leaf): x 30..82, y 20..84.
BBOX_CX, BBOX_CY = 56.0, 52.0


def cubic(p0, p1, p2, p3, n=48):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((
            u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
        ))
    return pts


LEAF = cubic((68, 30), (70, 22), (76, 19), (82, 20)) + cubic((82, 20), (82, 27), (77, 32), (68, 30))


def render(scale, bg, card, leaf, detail, mono=False):
    px = SIZE * SS / 108.0

    def m(x, y):  # grid -> pixels, recentred on canvas and scaled
        return ((54 + (x - BBOX_CX) * scale) * px, (54 + (y - BBOX_CY) * scale) * px)

    def r(v):
        return v * scale * px

    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), bg)
    d = ImageDraw.Draw(img)

    x0, y0 = m(30, 28)
    x1, y1 = m(78, 84)
    d.rounded_rectangle([x0, y0, x1, y1], radius=r(7), fill=card)
    d.polygon([m(*p) for p in LEAF], fill=leaf)

    def dot(cx, cy, rad):
        x, y = m(cx, cy)
        d.ellipse([x - r(rad), y - r(rad), x + r(rad), y + r(rad)], fill=detail)

    def ring(cx, cy, rad, w):
        x, y = m(cx, cy)
        o = rad + w / 2
        d.ellipse([x - r(o), y - r(o), x + r(o), y + r(o)], outline=detail, width=round(r(w)))

    def bar(xa, xb, y, w=4):
        (pa, py), (pb, _) = m(xa, y), m(xb, y)
        d.line([pa, py, pb, py], fill=detail, width=round(r(w)))
        for cx in (pa, pb):
            d.ellipse([cx - r(w / 2), py - r(w / 2), cx + r(w / 2), py + r(w / 2)], fill=detail)

    dot(41, 45, 4.5)
    dot(41, 57, 4.5)
    ring(41, 69, 4, 2.5)
    bar(50, 68, 45)
    bar(50, 68, 57)
    bar(50, 62, 69)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Full icon: same proportions as the approved concept.
    render(1.0, CREAM, GREEN, GREEN_DARK, CREAM).save(OUT / "icon.png")
    # Adaptive: launchers mask to a ~66dp circle/squircle, so shrink content to stay inside.
    render(0.78, CLEAR, GREEN, GREEN_DARK, CREAM).save(OUT / "icon_foreground.png")
    # Monochrome: single-colour silhouette with details cut out (system tints it).
    render(0.78, CLEAR, WHITE, WHITE, CLEAR).save(OUT / "icon_monochrome.png")
    print("Wrote", ", ".join(p.name for p in sorted(OUT.glob("*.png"))))


if __name__ == "__main__":
    main()

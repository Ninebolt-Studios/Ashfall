"""Draws the Declutter icon (a sparkle on a rounded square) as PNG + ICNS."""
import sys
from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
# vertical gradient background in a macOS-style rounded square
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
top, bot = (52, 211, 153), (14, 116, 144)
for y in range(S):
    t = y / (S - 1)
    gd.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)) + (255,))
mask = Image.new("L", (S, S), 0)
m = 100
ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], radius=185, fill=255)
img.paste(grad, (0, 0), mask)

d = ImageDraw.Draw(img)
def sparkle(cx, cy, r, w):
    pts = [(cx, cy - r), (cx + w, cy - w), (cx + r, cy), (cx + w, cy + w),
           (cx, cy + r), (cx - w, cy + w), (cx - r, cy), (cx - w, cy - w)]
    d.polygon(pts, fill=(255, 255, 255, 255))
sparkle(470, 560, 250, 52)
sparkle(700, 330, 110, 24)
sparkle(715, 735, 70, 15)

out = sys.argv[1]
img.save(out + ".png")
img.save(out + ".icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])

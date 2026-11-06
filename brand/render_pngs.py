"""Render Wasl logo PNGs from the same geometry as the SVG source files.
Icon: deep teal rounded tile, amber W-route, white store dot, amber destination dot.
Wordmark PNGs are English-only here: no Arabic-capable font is installed on this
machine, so the Arabic lockup (wasl-wordmark-ar.svg) stays SVG-only until a
designer renders it with IBM Plex Sans Arabic.
"""
import glob
from PIL import Image, ImageDraw, ImageFont

TEAL = (12, 74, 78, 255)
TEAL_DARK = (9, 58, 61, 255)
AMBER = (242, 168, 29, 255)
WHITE = (255, 255, 255, 255)
OUT = "/home/hatch/workspace/your_files/wasl-logo"

W_PTS = [(56, 84), (90, 164), (120, 104), (150, 164), (184, 84)]


def draw_icon(draw, s):
    """Draw the icon mark into a 240-unit space scaled by s."""
    draw.rounded_rectangle([8 * s, 8 * s, 232 * s, 232 * s], radius=56 * s, fill=TEAL)
    pts = [(x * s, y * s) for x, y in W_PTS]
    draw.line(pts, fill=AMBER, width=max(1, round(17 * s)), joint="curve")
    r = 10 * s
    draw.ellipse([56 * s - r, 84 * s - r, 56 * s + r, 84 * s + r], fill=WHITE)
    r = 15 * s
    draw.ellipse([184 * s - r, 84 * s - r, 184 * s + r, 84 * s + r], fill=AMBER)
    draw.ellipse([184 * s - r, 84 * s - r, 184 * s + r, 84 * s + r],
                 outline=TEAL, width=max(1, round(5 * s)))


for size in (1024, 512, 192):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_icon(ImageDraw.Draw(img), size / 240)
    img.save(f"{OUT}/wasl-icon-{size}.png")
    print("wrote", f"wasl-icon-{size}.png")

# Wordmark PNGs (English text only; see module docstring about Arabic).
DEJAVU_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
AR_FONTS = (glob.glob("/usr/share/fonts/**/ *Arabic*.ttf", recursive=True)
            + glob.glob("/usr/share/fonts/**/*Naskh*.ttf", recursive=True)
            + glob.glob("/usr/share/fonts/**/*Amiri*.ttf", recursive=True))
print("arabic fonts found:", AR_FONTS)


AR_BOLD = "/usr/share/fonts/truetype/noto/NotoNaskhArabic-Bold.ttf"


def wordmark_png(filename, text_color):
    img = Image.new("RGBA", (1680, 720), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_icon(d, 3)  # 240-unit icon at 3x = 720px tall
    font = ImageFont.truetype(DEJAVU_BOLD, 276)
    d.text((804, 200), "Wasl", font=font, fill=text_color)
    ar = ImageFont.truetype(AR_BOLD, 150)
    d.text((808, 500), "وصل", font=ar, fill=AMBER)
    img.save(f"{OUT}/{filename}")
    print("wrote", filename)


def wordmark_ar_png(filename, text_color):
    img = Image.new("RGBA", (1680, 720), (0, 0, 0, 0))
    tile = Image.new("RGBA", (720, 720), (0, 0, 0, 0))
    draw_icon(ImageDraw.Draw(tile), 3)
    img.paste(tile, (960, 0), tile)
    d = ImageDraw.Draw(img)
    ar = ImageFont.truetype(AR_BOLD, 276)
    d.text((936, 200), "وصل", font=ar, fill=text_color, anchor="ra")
    font = ImageFont.truetype(DEJAVU_BOLD, 138)
    d.text((936, 500), "Wasl", font=font, fill=AMBER, anchor="ra")
    img.save(f"{OUT}/{filename}")
    print("wrote", filename)


wordmark_png("wasl-wordmark.png", TEAL)
wordmark_png("wasl-wordmark-light.png", WHITE)
wordmark_ar_png("wasl-wordmark-ar.png", TEAL)
wordmark_ar_png("wasl-wordmark-ar-light.png", WHITE)

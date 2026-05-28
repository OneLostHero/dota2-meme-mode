"""Generate placeholder logos for Dota 2 - Meme Mode.

Creates two transparent PNGs in the addon's panorama images folder:
  - meme_mode_logo.png          (main loading-screen logo, wide)
  - meme_mode_logo_outline.png  (square variant used by the DVD-bounce effect)

These are simple text placeholders (Impact font, classic meme caption styling).
Replace them with real artwork whenever you like, then keep the same filenames.

Run from repo root:  python tools/make_placeholder_logo.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[1]
IMG_DIR = REPO / "content/dota_addons/dota2_meme_mode/panorama/images/custom_game"

# Prefer Impact (the meme font); fall back to Arial Bold, then PIL default.
_FONT_CANDIDATES = ["C:/Windows/Fonts/impact.ttf", "C:/Windows/Fonts/arialbd.ttf"]


def _font(size):
    for path in _FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _draw_centered(draw, cx, y, text, font, fill, stroke):
    box = draw.textbbox((0, 0), text, font=font, stroke_width=stroke)
    w = box[2] - box[0]
    draw.text(
        (cx - w / 2 - box[0], y), text, font=font, fill=fill,
        stroke_width=stroke, stroke_fill=(0, 0, 0, 255),
    )
    return box[3] - box[1]


def make_wide(path):
    W, H = 1024, 600
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _draw_centered(d, W / 2, 40, "DOTA 2", _font(110), (255, 200, 40, 255), 6)
    _draw_centered(d, W / 2, 190, "MEME", _font(150), (255, 255, 255, 255), 9)
    _draw_centered(d, W / 2, 380, "MODE", _font(150), (255, 255, 255, 255), 9)
    img.save(path)


def make_outline(path):
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _draw_centered(d, S / 2, 120, "MEME", _font(140), (255, 255, 255, 255), 9)
    _draw_centered(d, S / 2, 280, "MODE", _font(140), (255, 255, 255, 255), 9)
    img.save(path)


def main():
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    make_wide(IMG_DIR / "meme_mode_logo.png")
    make_outline(IMG_DIR / "meme_mode_logo_outline.png")
    print(f"wrote meme_mode_logo.png and meme_mode_logo_outline.png to {IMG_DIR}")


if __name__ == "__main__":
    main()

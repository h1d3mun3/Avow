#!/usr/bin/env python3
"""Generate Avow's app icon and menu bar images from one design.

Usage:
    python3 scripts/gen_avow_icon.py [app source directory]

    The directory defaults to Avow, so running the script from the
    repository root regenerates the files the app target uses.

Output:
    <app source directory>/Resources/Avow.icon/   Icon Composer bundle (.icon)
        icon.json              manifest (background, groups, layers, dark appearance)
        Assets/now.svg         the "now" point (amber)
        Assets/arc-major.svg   the longest recorded segment
        Assets/arc-mid.svg     the middle segment
        Assets/arc-minor.svg   the shortest segment
    <app source directory>/Assets.xcassets/
        MenuBarIdle.imageset/      template image: the arc, nothing recording
        MenuBarTracking.imageset/  template image: the arc and the "now" point

Design: recorded time is an arc that grows clockwise from twelve o'clock,
split into segments the way a look back splits it into kinds of work. The
arc stays neutral and its segments differ only in strength, so the icon
still reads when the system strips hue in the tinted and clear appearances.
The only colored element is the point in the open gap: the task being
recorded now.

Note: Apple has not published a specification for icon.json, so the
structure written here, including the dark-appearance specializations, is
inferred rather than taken from a specification. Open the bundle in Icon
Composer after regenerating it to check every appearance.
"""
import json
import math
import shutil
import sys
from pathlib import Path

# ---- Design (edit these values and rerun to regenerate) ----
APPEARANCES = {
    "light": {
        "background": "#F2F2F5",  # paper
        "glyph": "#262A31",       # graphite
        "now": "#E58A12",         # amber
    },
    "dark": {
        "background": "#262A31",  # graphite, shared with tiro
        "glyph": "#F4F4F6",
        "now": "#FFB340",         # amber, lifted for dark backgrounds
    },
}

# Angles are clockwise degrees from twelve o'clock. Each segment's strength
# is how much of the glyph color it carries over the background (1 = all).
SEGMENTS = [
    {"name": "arc-major", "start": 0, "end": 120, "strength": 1.0},
    {"name": "arc-mid", "start": 150, "end": 220, "strength": 0.6},
    {"name": "arc-minor", "start": 250, "end": 290, "strength": 0.36},
]
NOW_POINT = {"angle": 325, "radius": 64}

CANVAS = 1024
CENTER = CANVAS / 2
ARC_RADIUS = 250  # radius of the arc's center line
ARC_WIDTH = 96    # band width; segment ends are rounded by half of it

# Menu bar images crop the canvas to the glyph and are drawn at this size in
# points. Template images keep only alpha, so segment strength becomes opacity.
MENU_BAR_VIEWBOX = (200, 200, 624, 624)
MENU_BAR_POINTS = 16


def polar(angle: float, radius: float) -> tuple[float, float]:
    """Convert a clockwise angle from twelve o'clock to canvas coordinates."""
    a = math.radians(angle)
    return round(CENTER + radius * math.sin(a), 2), round(CENTER - radius * math.cos(a), 2)


def svg_doc(body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" '
        f'width="{CANVAS}" height="{CANVAS}">\n  {body}\n</svg>\n'
    )


def segment_path(start: float, end: float) -> str:
    """Outline one rounded arc segment as a filled path (no strokes)."""
    half = ARC_WIDTH / 2
    outer, inner = ARC_RADIUS + half, ARC_RADIUS - half
    large = 1 if end - start > 180 else 0
    ox1, oy1 = polar(start, outer)
    ox2, oy2 = polar(end, outer)
    ix2, iy2 = polar(end, inner)
    ix1, iy1 = polar(start, inner)
    return (
        f"M {ox1} {oy1} "
        f"A {outer} {outer} 0 {large} 1 {ox2} {oy2} "
        f"A {half} {half} 0 0 1 {ix2} {iy2} "
        f"A {inner} {inner} 0 {large} 0 {ix1} {iy1} "
        f"A {half} {half} 0 0 1 {ox1} {oy1} Z"
    )


def hex_to_rgb(hex_color: str) -> tuple[float, float, float]:
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def blend(foreground: str, background: str, strength: float) -> str:
    """Mix the foreground into the background and return the result as hex."""
    fg, bg = hex_to_rgb(foreground), hex_to_rgb(background)
    mixed = (bg[i] + (fg[i] - bg[i]) * strength for i in range(3))
    return "#" + "".join(f"{round(c * 255):02X}" for c in mixed)


def segment_color(appearance: str, strength: float) -> str:
    colors = APPEARANCES[appearance]
    return blend(colors["glyph"], colors["background"], strength)


def segment_svg(segment: dict) -> str:
    fill = segment_color("light", segment["strength"])
    return svg_doc(f'<path d="{segment_path(segment["start"], segment["end"])}" fill="{fill}"/>')


def now_svg() -> str:
    x, y = polar(NOW_POINT["angle"], ARC_RADIUS)
    return svg_doc(
        f'<circle cx="{x}" cy="{y}" r="{NOW_POINT["radius"]}" fill="{APPEARANCES["light"]["now"]}"/>'
    )


def icon_color(hex_color: str) -> str:
    r, g, b = hex_to_rgb(hex_color)
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"


def solid_specializations(light: str, dark: str) -> list:
    return [
        {"value": {"solid": icon_color(light)}},
        {"appearance": "dark", "value": {"solid": icon_color(dark)}},
    ]


def layer(name: str, light: str, dark: str) -> dict:
    return {
        "image-name": f"{name}.svg",
        "name": name,
        "glass": True,
        "fill-specializations": solid_specializations(light, dark),
    }


def manifest() -> dict:
    light, dark = APPEARANCES["light"], APPEARANCES["dark"]
    # Layers are listed top to bottom: the "now" point sits above the arc.
    layers = [layer("now", light["now"], dark["now"])]
    for segment in reversed(SEGMENTS):
        layers.append(
            layer(
                segment["name"],
                segment_color("light", segment["strength"]),
                segment_color("dark", segment["strength"]),
            )
        )
    return {
        "fill-specializations": solid_specializations(light["background"], dark["background"]),
        "groups": [{"name": "Foreground", "layers": layers}],
        "supported-platforms": {"squares": "shared"},
    }


def menu_bar_svg(tracking: bool) -> str:
    x, y, w, h = MENU_BAR_VIEWBOX
    body = "".join(
        f'<path d="{segment_path(s["start"], s["end"])}" fill="#000000" fill-opacity="{s["strength"]}"/>'
        for s in SEGMENTS
    )
    if tracking:
        cx, cy = polar(NOW_POINT["angle"], ARC_RADIUS)
        body += f'<circle cx="{cx}" cy="{cy}" r="{NOW_POINT["radius"]}" fill="#000000"/>'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" '
        f'width="{MENU_BAR_POINTS}" height="{MENU_BAR_POINTS}">\n  {body}\n</svg>\n'
    )


def write_menu_bar_image(catalog: Path, name: str, tracking: bool) -> None:
    imageset = catalog / f"{name}.imageset"
    if imageset.exists():
        shutil.rmtree(imageset)
    imageset.mkdir(parents=True)
    filename = f"{name}.svg"
    (imageset / filename).write_text(menu_bar_svg(tracking), encoding="utf-8")
    contents = {
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {
            "preserves-vector-representation": True,
            "template-rendering-intent": "template",
        },
    }
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    app_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Avow")
    bundle = app_dir / "Resources" / "Avow.icon"
    assets = bundle / "Assets"
    # Rebuild the assets folder so layers removed from the design do not linger.
    if assets.exists():
        shutil.rmtree(assets)
    assets.mkdir(parents=True)
    (assets / "now.svg").write_text(now_svg(), encoding="utf-8")
    for segment in SEGMENTS:
        (assets / f'{segment["name"]}.svg').write_text(segment_svg(segment), encoding="utf-8")
    (bundle / "icon.json").write_text(json.dumps(manifest(), indent=2) + "\n", encoding="utf-8")
    print(f"Generated {bundle}")

    catalog = app_dir / "Assets.xcassets"
    write_menu_bar_image(catalog, "MenuBarIdle", tracking=False)
    write_menu_bar_image(catalog, "MenuBarTracking", tracking=True)
    print(f"Generated menu bar images in {catalog}")


if __name__ == "__main__":
    main()

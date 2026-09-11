#!/usr/bin/env python3
"""Generate every placeholder asset in the workspace, deterministically.

The sample games ship no hand-drawn art or recorded audio. Their sprites,
sound effects, meshes and material fixtures are produced here from code, so the
repository stays small, the files are byte-identical on every machine, and an
agent can regenerate or restyle them without a binary editor.

Usage:
    python3 tools/gen_assets.py            # every project
    python3 tools/gen_assets.py leap       # one project
    python3 tools/gen_assets.py --list     # what would be written

Only the Python standard library is used.
"""

from __future__ import annotations

import math
import os
import random
import struct
import sys
import wave
import zlib
from typing import Callable

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 22050

#: Files written by the current run, in call order.
WRITTEN: list[str] = []

# --------------------------------------------------------------------------- #
# encoders
# --------------------------------------------------------------------------- #


def write_wav(path: str, samples: list[float]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    WRITTEN.append(path)


def _png_chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )


Pixel = tuple[int, int, int, int]


def write_png(path: str, width: int, height: int, shader: Callable[[int, int], Pixel]) -> None:
    """Writes an RGBA PNG whose pixels come from shader(x, y)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rows = []
    for y in range(height):
        row = bytearray([0])  # filter type 0
        for x in range(width):
            r, g, b, a = shader(x, y)
            row += bytes((r & 255, g & 255, b & 255, a & 255))
        rows.append(bytes(row))
    png = b"\x89PNG\r\n\x1a\n"
    png += _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += _png_chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
    png += _png_chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    WRITTEN.append(path)


# --------------------------------------------------------------------------- #
# drawing helpers
# --------------------------------------------------------------------------- #


def solid(color: Pixel) -> Callable[[int, int], Pixel]:
    return lambda x, y: color


def disc(size: int, color: Pixel, edge: Pixel | None = None) -> Callable[[int, int], Pixel]:
    """A filled circle with a soft shaded edge, transparent outside."""
    c = (size - 1) / 2.0
    radius = size / 2.0 - 0.5
    edge = edge or tuple(max(0, v - 60) for v in color[:3]) + (color[3],)  # type: ignore[assignment]

    def shader(x: int, y: int) -> Pixel:
        d = math.hypot(x - c, y - c)
        if d > radius:
            return (0, 0, 0, 0)
        t = d / radius
        if t > 0.72:
            return edge  # type: ignore[return-value]
        # cheap top-left highlight
        lift = max(0.0, 1.0 - math.hypot(x - c * 0.6, y - c * 0.6) / radius) * 60
        return tuple(min(255, int(v + lift)) for v in color[:3]) + (color[3],)  # type: ignore[return-value]

    return shader


def rounded_box(size: int, color: Pixel, radius: int = 3, outline: Pixel | None = None):
    outline = outline or tuple(max(0, v - 70) for v in color[:3]) + (255,)  # type: ignore[assignment]

    def shader(x: int, y: int) -> Pixel:
        cx = min(x, size - 1 - x)
        cy = min(y, size - 1 - y)
        if cx < radius and cy < radius:
            if math.hypot(radius - cx, radius - cy) > radius + 0.5:
                return (0, 0, 0, 0)
        if cx == 0 or cy == 0:
            return outline  # type: ignore[return-value]
        return color

    return shader


def triangle_up(size: int, color: Pixel) -> Callable[[int, int], Pixel]:
    def shader(x: int, y: int) -> Pixel:
        half = (y + 1) / 2.0
        return color if abs(x - (size - 1) / 2.0) <= half else (0, 0, 0, 0)

    return shader


def brick(size: int, base: Pixel, mortar: Pixel) -> Callable[[int, int], Pixel]:
    def shader(x: int, y: int) -> Pixel:
        row = y // (size // 2)
        offset = (size // 2) * (row % 2)
        if y % (size // 2) == 0 or (x + offset) % size == 0:
            return mortar
        shade = -8 if (x + y) % 7 == 0 else 0
        return tuple(max(0, v + shade) for v in base[:3]) + (base[3],)  # type: ignore[return-value]

    return shader


def ring(size: int, color: Pixel, thickness: float = 2.5) -> Callable[[int, int], Pixel]:
    c = (size - 1) / 2.0
    outer = size / 2.0 - 0.5

    def shader(x: int, y: int) -> Pixel:
        d = math.hypot(x - c, y - c)
        return color if outer - thickness <= d <= outer else (0, 0, 0, 0)

    return shader


# --------------------------------------------------------------------------- #
# audio helpers
# --------------------------------------------------------------------------- #


def sweep(duration: float, f0: float, f1: float, decay: float, gain: float = 0.6) -> list[float]:
    n = int(RATE * duration)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (f0 + (f1 - f0) * (t / duration)) / RATE
        out.append(gain * math.exp(-t * decay) * math.sin(phase))
    return out


def thud(duration: float, freq: float, seed: int, gain: float = 0.7) -> list[float]:
    rng = random.Random(seed)
    n = int(RATE * duration)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 18.0)
        tone = math.sin(2 * math.pi * freq * t) * gain
        noise = (rng.random() * 2 - 1) * 0.3 * math.exp(-t * 40.0)
        out.append(env * (tone + noise))
    return out


def blip(duration: float, freq: float, decay: float, square: bool = False, gain: float = 0.5):
    n = int(RATE * duration)
    out = []
    for i in range(n):
        t = i / RATE
        wave_value = math.sin(2 * math.pi * freq * t)
        if square:
            wave_value = 1.0 if wave_value >= 0 else -1.0
        out.append(gain * math.exp(-t * decay) * wave_value)
    return out


def noise_burst(duration: float, decay: float, seed: int, gain: float = 0.5) -> list[float]:
    rng = random.Random(seed)
    n = int(RATE * duration)
    return [gain * math.exp(-(i / RATE) * decay) * (rng.random() * 2 - 1) for i in range(n)]


# --------------------------------------------------------------------------- #
# meshes
# --------------------------------------------------------------------------- #


def write_octahedron_obj(path: str, radius: float = 0.4) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    r = radius
    verts = [(0, r, 0), (r, 0, 0), (0, 0, r), (-r, 0, 0), (0, 0, -r), (0, -r, 0)]
    faces = [(1, 3, 2), (1, 4, 3), (1, 5, 4), (1, 2, 5), (6, 2, 3), (6, 3, 4), (6, 4, 5), (6, 5, 2)]
    lines = ["# GodotGo orb: octahedron generated by tools/gen_assets.py", "o Orb"]
    lines += ["v %.4f %.4f %.4f" % v for v in verts]
    for a, b, c in faces:
        va, vb, vc = (verts[i - 1] for i in (a, b, c))
        ux, uy, uz = (vb[i] - va[i] for i in range(3))
        wx, wy, wz = (vc[i] - va[i] for i in range(3))
        nx, ny, nz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
        length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        lines.append("vn %.4f %.4f %.4f" % (nx / length, ny / length, nz / length))
    for i, (a, b, c) in enumerate(faces, start=1):
        lines.append("f %d//%d %d//%d %d//%d" % (a, i, b, i, c, i))
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    WRITTEN.append(path)


def crosshair(size: int = 32) -> Callable[[int, int], Pixel]:
    c = size // 2

    def shader(x: int, y: int) -> Pixel:
        dx, dy = abs(x - c + 0.5), abs(y - c + 0.5)
        on_arm = (dx <= 1.5 and 3 <= dy <= 12) or (dy <= 1.5 and 3 <= dx <= 12)
        outline = (dx <= 2.5 and 2 <= dy <= 13) or (dy <= 2.5 and 2 <= dx <= 13)
        if on_arm:
            return (255, 255, 255, 230)
        if outline:
            return (0, 0, 0, 160)
        return (0, 0, 0, 0)

    return shader


# --------------------------------------------------------------------------- #
# per-project asset tables
# --------------------------------------------------------------------------- #

PROJECTS: dict[str, Callable[[str], None]] = {}


def project(name: str):
    def wrap(fn):
        PROJECTS[name] = fn
        return fn

    return wrap


@project("framework")
def _framework(base: str) -> None:
    """Tiny PBR maps so the material loader can be tested without a real export."""
    mm = os.path.join(base, "tests/fixtures/materials/demo")
    write_png(os.path.join(mm, "demo_albedo.png"), 4, 4, solid((180, 120, 90, 255)))
    write_png(os.path.join(mm, "demo_orm.png"), 4, 4, solid((255, 160, 40, 255)))
    write_png(os.path.join(mm, "demo_normal.png"), 4, 4, solid((128, 128, 255, 255)))
    write_png(os.path.join(mm, "demo_emission.png"), 4, 4, solid((10, 200, 220, 255)))


@project("games/orb-run")
def _orb_run(base: str) -> None:
    write_wav(os.path.join(base, "assets/audio/pickup.wav"), sweep(0.18, 600, 1500, 14))
    write_wav(os.path.join(base, "assets/audio/land.wav"), thud(0.25, 80, 7))
    write_png(os.path.join(base, "assets/textures/crosshair.png"), 32, 32, crosshair())
    write_octahedron_obj(os.path.join(base, "assets/models/orb.obj"))


@project("games/leap")
def _leap(base: str) -> None:
    tex = os.path.join(base, "assets/textures")
    write_png(os.path.join(tex, "brick.png"), 16, 16, brick(16, (122, 96, 84, 255), (70, 56, 50, 255)))
    write_png(os.path.join(tex, "ground.png"), 16, 16, brick(16, (86, 122, 74, 255), (52, 78, 46, 255)))
    write_png(os.path.join(tex, "hero.png"), 16, 16, rounded_box(16, (238, 200, 96, 255), 4))
    write_png(os.path.join(tex, "coin.png"), 12, 12, disc(12, (252, 214, 74, 255)))
    write_png(os.path.join(tex, "spike.png"), 16, 16, triangle_up(16, (214, 88, 92, 255)))
    write_png(os.path.join(tex, "flag.png"), 16, 16, rounded_box(16, (96, 214, 140, 255), 2))
    write_png(os.path.join(tex, "platform.png"), 16, 16, rounded_box(16, (120, 150, 220, 255), 3))
    audio = os.path.join(base, "assets/audio")
    write_wav(os.path.join(audio, "jump.wav"), sweep(0.12, 320, 720, 20, 0.45))
    write_wav(os.path.join(audio, "coin.wav"), blip(0.10, 1180, 26, gain=0.4))
    write_wav(os.path.join(audio, "hurt.wav"), sweep(0.22, 420, 120, 12, 0.5))


@project("games/swarm")
def _swarm(base: str) -> None:
    tex = os.path.join(base, "assets/textures")
    write_png(os.path.join(tex, "ship.png"), 20, 20, disc(20, (110, 210, 255, 255)))
    write_png(os.path.join(tex, "drone.png"), 18, 18, rounded_box(18, (232, 108, 128, 255), 5))
    write_png(os.path.join(tex, "brute.png"), 26, 26, rounded_box(26, (176, 96, 224, 255), 7))
    write_png(os.path.join(tex, "bullet.png"), 8, 8, disc(8, (255, 246, 168, 255)))
    write_png(os.path.join(tex, "spawn_ring.png"), 28, 28, ring(28, (255, 128, 128, 200)))
    audio = os.path.join(base, "assets/audio")
    write_wav(os.path.join(audio, "shoot.wav"), blip(0.07, 880, 40, square=True, gain=0.3))
    write_wav(os.path.join(audio, "hit.wav"), noise_burst(0.12, 34, 11, 0.45))
    write_wav(os.path.join(audio, "wave.wav"), sweep(0.35, 180, 520, 6, 0.4))


@project("games/shift")
def _shift(base: str) -> None:
    tex = os.path.join(base, "assets/textures")
    write_png(os.path.join(tex, "wall.png"), 16, 16, brick(16, (98, 104, 122, 255), (62, 66, 80, 255)))
    write_png(os.path.join(tex, "floor.png"), 16, 16, solid((36, 38, 48, 255)))
    write_png(os.path.join(tex, "crate.png"), 16, 16, rounded_box(16, (198, 148, 84, 255), 2))
    write_png(os.path.join(tex, "crate_done.png"), 16, 16, rounded_box(16, (120, 208, 140, 255), 2))
    write_png(os.path.join(tex, "target.png"), 16, 16, ring(16, (240, 200, 96, 220), 2.0))
    write_png(os.path.join(tex, "mover.png"), 16, 16, disc(16, (118, 190, 248, 255)))
    audio = os.path.join(base, "assets/audio")
    write_wav(os.path.join(audio, "step.wav"), blip(0.06, 320, 44, gain=0.25))
    write_wav(os.path.join(audio, "push.wav"), noise_burst(0.10, 40, 3, 0.3))
    write_wav(os.path.join(audio, "solved.wav"), sweep(0.45, 520, 1180, 5, 0.45))


# --------------------------------------------------------------------------- #


def main(argv: list[str]) -> int:
    names = [a for a in argv if not a.startswith("-")]
    listing = "--list" in argv
    targets = names or list(PROJECTS)
    unknown = [n for n in targets if n not in PROJECTS and f"games/{n}" not in PROJECTS]
    if unknown:
        print("unknown project(s): %s" % ", ".join(unknown), file=sys.stderr)
        print("known: %s" % ", ".join(PROJECTS), file=sys.stderr)
        return 2
    for name in targets:
        key = name if name in PROJECTS else f"games/{name}"
        base = os.path.join(ROOT, key)
        if not os.path.isdir(base):
            print("skip %s (no such directory)" % key)
            continue
        if listing:
            print(key)
            continue
        WRITTEN.clear()
        PROJECTS[key](base)
        print("%s: %d asset(s)" % (key, len(WRITTEN)))
        for p in sorted(WRITTEN):
            print("    %-52s %7d bytes" % (os.path.relpath(p, ROOT), os.path.getsize(p)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

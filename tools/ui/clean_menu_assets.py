"""Regenera assets/ui/game_logo.png con alpha real desde el original JPEG.

El original trae el patrón de tablero (transparencia falsa) y una sombra
suave mezclada con ese tablero. Pipeline:
1. flood-fill desde los bordes sobre píxeles claros poco saturados
   (umbral relajado para comerse también la franja sombra+tablero);
2. eliminar islas opacas pequeñas (motas residuales);
3. erosión suave del halo en el borde;
4. recorte ajustado al contenido.
"""
from collections import deque

from PIL import Image

SRC = (
    "/home/dilan/.cursor/projects/home-dilan-Documentos-GitHub-granja-supervivencia-godot/"
    "assets/logo_finca_tica-918be837-9f7f-4f25-bd18-b06fe34be6ba.png"
)
DST = "assets/ui/game_logo.png"


def stats(px):
    r, g, b = px[0], px[1], px[2]
    bright = (r + g + b) / 3.0
    sat = max(r, g, b) - min(r, g, b)
    return bright, sat


def clearable(px) -> bool:
    bright, sat = stats(px)
    # tablero blanco/gris y franja de sombra contaminada por tablero
    return (bright > 120 and sat < 48) or (bright > 95 and sat < 14)


def flood_clear(img) -> int:
    w, h = img.size
    pix = img.load()
    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))
    cleared = 0
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        idx = y * w + x
        if seen[idx]:
            continue
        seen[idx] = 1
        if pix[x, y][3] == 0 or not clearable(pix[x, y]):
            continue
        pix[x, y] = (0, 0, 0, 0)
        cleared += 1
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return cleared


def remove_small_islands(img, min_size: int = 600) -> int:
    w, h = img.size
    pix = img.load()
    labels = [0] * (w * h)
    current = 0
    removed = 0
    for sy in range(h):
        for sx in range(w):
            if pix[sx, sy][3] == 0 or labels[sy * w + sx]:
                continue
            current += 1
            component = []
            queue = deque([(sx, sy)])
            labels[sy * w + sx] = current
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        idx = ny * w + nx
                        if not labels[idx] and pix[nx, ny][3] != 0:
                            labels[idx] = current
                            queue.append((nx, ny))
            if len(component) < min_size:
                for x, y in component:
                    pix[x, y] = (0, 0, 0, 0)
                removed += len(component)
    return removed


def erode_halo(img, passes: int = 2) -> int:
    w, h = img.size
    pix = img.load()
    eroded = 0
    for _ in range(passes):
        edge = []
        for y in range(h):
            for x in range(w):
                if pix[x, y][3] == 0:
                    continue
                bright, sat = stats(pix[x, y])
                if not (bright > 100 and sat < 60):
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and pix[nx, ny][3] == 0:
                        edge.append((x, y))
                        break
        for x, y in edge:
            pix[x, y] = (0, 0, 0, 0)
        eroded += len(edge)
    return eroded


img = Image.open(SRC).convert("RGBA")
print(f"flood: {flood_clear(img)} px")
print(f"islas: {remove_small_islands(img)} px")
print(f"halo:  {erode_halo(img)} px")
bbox = img.getbbox()
img = img.crop(bbox)
img.save(DST)
print(f"final: bbox={bbox} size={img.size}")

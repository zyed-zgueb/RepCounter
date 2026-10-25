#!/usr/bin/env python3
"""Icône d'app iOS 1024×1024 opaque à partir de l'image fournie (damier « transparent » incrusté).
Usage : python3 Design/make_icon.py Design/icone-source.png RepCounter/Assets.xcassets/AppIcon.appiconset/AppIcon.png
On garde le cadran (anneau + chiffre) et on remplace tout l'extérieur par le fond du carré,
modélisé par un dégradé linéaire ajusté sur ses pixels : plus de damier, d'ombre ni de coins."""
import sys
import numpy as np
from PIL import Image

source, output = sys.argv[1], sys.argv[2]
img = np.asarray(Image.open(source).convert("RGB")).astype(np.float64)
h, w, _ = img.shape
cx, cy = 392.5, 564.0          # centre de l'anneau
yy, xx = np.mgrid[0:h, 0:w]
r = np.hypot(xx - cx, yy - cy)

# Fond du carré : pixels de l'anneau intérieur au carré, hors anneau et hors lueur
sample = (r > 282) & (r < 305) & (xx > 84) & (xx < 700) & (yy > 240) & (yy < 892)
features = np.stack([np.ones(sample.sum()), xx[sample], yy[sample]], axis=1)
coeffs, *_ = np.linalg.lstsq(features, img[sample], rcond=None)

side = 640                      # carré découpé (px source) ; anneau ≈ 80 % du rayon visible
left, top = int(round(cx - side / 2)), int(round(cy - side / 2))
gy, gx = np.mgrid[top:top + side, left:left + side]
background = coeffs[0] + gx[..., None] * coeffs[1] + gy[..., None] * coeffs[2]

crop = np.zeros((side, side, 3))
inside = (gx >= 0) & (gx < w) & (gy >= 0) & (gy < h)
crop[inside] = img[gy[inside], gx[inside]]
rr = np.hypot(gx - cx, gy - cy)
keep = np.clip((310 - rr) / 30, 0, 1)[..., None]   # fondu de r = 280 à 310 px
result = keep * crop + (1 - keep) * background

icon = Image.fromarray(np.clip(result, 0, 255).astype(np.uint8), "RGB").resize((1024, 1024), Image.LANCZOS)
icon.save(output, optimize=True)
print("fond :", np.round(coeffs, 3).tolist())

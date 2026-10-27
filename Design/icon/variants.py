"""Variantes de l'icône pour iOS 18+ : sombre (identique, l'icône est déjà sombre) et teintée
(niveaux de gris : iOS la colore avec la teinte choisie). Usage : python3 Design/icon/variants.py"""
import os
from PIL import Image, ImageOps

folder = os.path.join(os.path.dirname(__file__), "../../RepCounter/Assets.xcassets/AppIcon.appiconset")
icon = Image.open(os.path.join(folder, "AppIcon.png")).convert("RGB")
icon.save(os.path.join(folder, "AppIcon-dark.png"))
ImageOps.autocontrast(icon.convert("L"), cutoff=1).save(os.path.join(folder, "AppIcon-tinted.png"))
print("variantes dans", folder)

// Icône finale (variante A) : node Design/icon/render.js
// → RepCounter/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024 × 1024, sans coins arrondis :
// iOS les applique), plus les variantes sombre et teintée (niveaux de gris) produites ensuite par
// Design/make_icon_variants.py.
const { chromium } = require("playwright");
const path = require("path");

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  await page.goto("file://" + path.join(__dirname, "icons.html"));
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(() => {
    document.body.style.background = "#000";
    document.body.innerHTML = window.ICONS.A.replaceAll("SIZE", 1024);
  });
  await page.waitForTimeout(200);
  const out = path.join(__dirname, "../../RepCounter/Assets.xcassets/AppIcon.appiconset/AppIcon.png");
  await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await browser.close();
  console.log("icône :", out);
})();

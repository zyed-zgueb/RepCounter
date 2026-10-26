// Captures de la proposition v2 (v2.html) : node Design/mockups/render-v2.js → Design/mockups/out/v2-*.png
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const themes = JSON.parse(fs.readFileSync(path.join(__dirname, "../../RepCounter/Themes.json"), "utf8")).themes;
const byId = Object.fromEntries(themes.map(t => [t.id, t]));
const out = path.join(__dirname, "out");
fs.mkdirSync(out, { recursive: true });

const SCREENS = [
  ["1-ouverture", { phase: "ready", signal: "ok", caption: "Ouverture de l'app (veille)" }],
  ["1b-ouverture-centre", { phase: "ready", centerPicker: true, signal: "ok", caption: "Variante : toucher le pictogramme" }],
  ["1c-abdos-centre", { phase: "ready", centerPicker: true, exercise: 1, signal: "weak", caption: "Variante, abdos" }],
  ["2-choix-exercice", { phase: "picker", exercise: 0, caption: "Toucher le nom de l'exercice" }],
  ["2b-abdos", { phase: "ready", exercise: 1, signal: "weak", caption: "Abdos choisis" }],
  ["3-depart", { phase: "countdown", caption: "Départ (bips 3, 2, 1, accord)" }],
  ["4-detection", { phase: "acquiring", tentative: 2, caption: "Détection 2/3" }],
  ["5-serie", { phase: "counting", reps: 7, total: 19, caption: "Pendant la série" }],
  ["6-recuperation", { phase: "resting", sets: [12, 11, 10, 11, 10, 10], caption: "Récupération" }],
  ["7-fin", { phase: "finished", total: 64, sets: [12, 11, 10, 11, 10, 10], caption: "Fin de séance" }],
  ["8-reglages-son", { phase: "settings", audio: "sons", caption: "Réglages · retour sonore" }],
];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  await page.goto("file://" + path.join(__dirname, "v2.html"));
  await page.evaluate(() => document.fonts.ready);
  const shots = SCREENS.map(([name, s]) => [`v2-${name}`, byId.monitor, s]);
  for (const id of ["clinic", "neon"]) {
    shots.push([`v2-${id}-5-serie`, byId[id], SCREENS.find(x => x[0] === "5-serie")[1]]);
    shots.push([`v2-${id}-1-ouverture`, byId[id], SCREENS.find(x => x[0] === "1-ouverture")[1]]);
  }
  for (const [name, theme, screen] of shots) {
    await page.evaluate(([t, s]) => window.renderScreen(t, s), [theme, screen]);
    await page.waitForTimeout(50);
    await page.screenshot({ path: path.join(out, `${name}.png`), clip: { x: 0, y: 0, width: 390, height: 844 } });
  }
  await browser.close();
  console.log(`${shots.length} captures dans ${out}`);
})();

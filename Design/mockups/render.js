// Génère les captures des maquettes (screens.html) à partir de RepCounter/Themes.json.
// Usage : node Design/mockups/render.js   → images dans Design/mockups/out/
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const themes = JSON.parse(fs.readFileSync(path.join(__dirname, "../../RepCounter/Themes.json"), "utf8")).themes;
const byId = Object.fromEntries(themes.map(t => [t.id, t]));
const out = path.join(__dirname, "out");
fs.mkdirSync(out, { recursive: true });

const SCREENS = [
  ["01-accueil", { kind: "home", caption: "Accueil" }],
  ["01b-reglages", { kind: "settings", themes, caption: "Réglages (roue dentée)" }],
  ["02-veille", { phase: "ready", signal: "ok", phase01: 0.3, caption: "Veille" }],
  ["03-compte-a-rebours", { phase: "countdown", signal: "weak", phase01: 0, caption: "Compte à rebours" }],
  ["04-detection-2-sur-3", { phase: "acquiring", signal: "ok", phase01: 0.55, tentative: 2, total: 0, sets: [], caption: "Détection, pas encore validé" }],
  ["05-comptage", { phase: "counting", signal: "ok", phase01: 0.7, reps: 7, total: 19, cadence: "1.6", regularity: 97, sets: [12], caption: "Comptage validé" }],
  ["06-recuperation", { phase: "resting", signal: "weak", phase01: 0, total: 22, cadence: "1.6", regularity: 97, sets: [12, 10], caption: "Récupération" }],
  ["06b-recuperation-6-series", { phase: "resting", signal: "weak", phase01: 0, total: 64, cadence: "1.6", sets: [12, 11, 10, 11, 10, 10], caption: "Récupération, 6 séries" }],
  ["08-mode-analyse", { phase: "counting", signal: "ok", phase01: 0.7, reps: 7, total: 19, cadence: "1.6", regularity: 97, sets: [12], analysis: true, caption: "Mode analyse activé" }],
  ["07-resume", { phase: "finished", total: 34, sets: [12, 10, 12], caption: "Résumé de séance" }],
];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  await page.goto("file://" + path.join(__dirname, "screens.html"));
  await page.evaluate(() => document.fonts.ready);
  const shots = [];
  for (const [name, screen] of SCREENS) shots.push([`monitor-${name}`, byId.monitor, screen]);
  for (const id of ["phosphor", "clinic", "neon"]) {
    shots.push([`${id}-05-comptage`, byId[id], SCREENS[5][1]]);
    shots.push([`${id}-04-detection`, byId[id], SCREENS[4][1]]);
    shots.push([`${id}-01b-reglages`, byId[id], SCREENS[1][1]]);
  }
  for (const [name, theme, screen] of shots) {
    await page.evaluate(([t, s]) => window.renderScreen(t, s), [theme, screen]);
    await page.waitForTimeout(50);
    await page.screenshot({ path: path.join(out, `${name}.png`), clip: { x: 0, y: 0, width: 390, height: 844 } });
  }
  await browser.close();
  console.log(`${shots.length} captures dans ${out}`);
})();

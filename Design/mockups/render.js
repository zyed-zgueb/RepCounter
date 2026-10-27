// Captures des maquettes (screens.html) : node Design/mockups/render.js → Design/mockups/out/*.png
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const themes = JSON.parse(fs.readFileSync(path.join(__dirname, "../../RepCounter/Themes.json"), "utf8")).themes;
const byId = Object.fromEntries(themes.map(t => [t.id, t]));
const out = path.join(__dirname, "out");
fs.mkdirSync(out, { recursive: true });

const SCREENS = [
  ["1-ouverture", { phase: "ready", signal: "ok", caption: "Ouverture de l'app (veille)" }],
  ["2-glissement", { phase: "ready", exercise: 0, drag: -95, signal: "ok", caption: "Glisser vers la gauche" }],
  ["2c-biceps", { phase: "ready", exercise: 6, mine: [0, 1, 2, 6, 7], signal: "ok", caption: "Biceps : charge de l'haltère" }],
  ["2d-tractions", { phase: "ready", exercise: 4, signal: "ok", caption: "Tractions" }],
  ["2e-rowing", { phase: "ready", exercise: 7, mine: [0, 1, 2, 6, 7], signal: "ok", caption: "Rowing haltère" }],
  ["2b-abdos", { phase: "ready", exercise: 1, signal: "weak", caption: "Abdos choisis" }],
  ["3-depart", { phase: "countdown", caption: "Départ (bips 3, 2, 1, accord)" }],
  ["4-detection", { phase: "acquiring", tentative: 2, caption: "Détection 2/3" }],
  ["5-serie", { phase: "counting", reps: 7, total: 19, caption: "Pendant la série" }],
  ["6-recuperation", { phase: "resting", sets: [12, 11, 10, 11, 10, 10], caption: "Récupération" }],
  ["7-fin", { phase: "finished", total: 60, sets: [14, 13, 12, 11, 10], recordSet: 0, caption: "Fin de séance" }],
  ["7b-fin-correction", { phase: "finished", total: 60, sets: [14, 13, 12, 11, 10], recordSet: 0, editing: 2, caption: "Correction d'une série" }],
  ["7c-fin-en-cours", { phase: "finished", total: 22, sets: [12, 10], pending: true, caption: "Fin de séance : états en cours" }],
  ["9-historique", { phase: "history", height: 1500, caption: "Historique en 4 blocs (défile)" }],
  ["9b-historique-debut", { phase: "history", sub: "early", height: 1080, caption: "Historique : premières séances" }],
  ["9c-endurance", { phase: "history", sub: "endurance", caption: "Détail : score d'endurance" }],
  ["9d-forme", { phase: "history", sub: "form", caption: "Détail : forme" }],
  ["9e-activite", { phase: "history", sub: "activity", caption: "Détail : activité" }],
  ["11-endurance-info", { phase: "info", caption: "(i) Endurance" }],
  ["10-seance", { phase: "session", caption: "Détail d'une séance" }],
  ["8-reglages", { phase: "settings", audio: "sons", themes, height: 1230, caption: "Réglages (roue dentée)" }],
  ["8b-mes-exercices", { phase: "exercises", caption: "Mes exercices" }],
];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  await page.goto("file://" + path.join(__dirname, "screens.html"));
  await page.evaluate(() => document.fonts.ready);
  const shots = SCREENS.map(([name, s]) => [name, byId.monitor, s]);
  for (const id of ["clinic", "neon"]) {
    shots.push([`${id}-5-serie`, byId[id], SCREENS.find(x => x[0] === "5-serie")[1]]);
    shots.push([`${id}-1-ouverture`, byId[id], SCREENS.find(x => x[0] === "1-ouverture")[1]]);
  }
  for (const [name, theme, screen] of shots) {
    await page.evaluate(([t, s]) => window.renderScreen(t, s), [theme, screen]);
    await page.waitForTimeout(50);
    const height = screen.height || 844;
    await page.setViewportSize({ width: 390, height });
    await page.screenshot({ path: path.join(out, `${name}.png`), clip: { x: 0, y: 0, width: 390, height } });
  }
  await browser.close();
  console.log(`${shots.length} captures dans ${out}`);
})();

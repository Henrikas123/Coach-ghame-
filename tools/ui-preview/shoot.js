// Render scenario JSON dumps to PNG screenshots with Playwright (Chromium).
// Usage: node shoot.js [scenario ...]   (default: all out/*.json)
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');

(async () => {
  const here = __dirname;
  const outDir = path.join(here, 'out');
  const shotDir = path.join(here, 'shots');
  fs.mkdirSync(shotDir, { recursive: true });
  let names = process.argv.slice(2);
  if (names.length === 0) names = fs.readdirSync(outDir).filter(f => f.endsWith('.json')).map(f => f.replace(/\.json$/, ''));
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const qa = {};
  for (const name of names) {
    const data = JSON.parse(fs.readFileSync(path.join(outDir, name + '.json'), 'utf8'));
    for (const k of ['errors', 'warnings']) if (!Array.isArray(data[k])) data[k] = data[k] ? Object.values(data[k]) : [];
    const page = await browser.newPage({ viewport: { width: data.viewport.x, height: data.viewport.y }, deviceScaleFactor: 1 });
    await page.goto('file://' + path.join(here, 'render.html'));
    await page.evaluate(() => document.fonts.ready);
    // warm up fonts (emoji + both weights) before measuring
    await page.evaluate(async () => {
      const probes = ['500 16px Montserrat', '700 16px Montserrat', '16px "Noto Color Emoji"'];
      for (const f of probes) { try { await document.fonts.load(f, 'AaĄčŠž 🥊🏆📱'); } catch (e) {} }
    });
    const issues = await page.evaluate(d => window.renderScene(d, { debug: false }), data);
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(shotDir, name + '.png') });
    if (process.env.DEBUG_SHOTS) {
      await page.evaluate(d => window.renderScene(d, { debug: true }), data);
      await page.screenshot({ path: path.join(shotDir, name + '.debug.png') });
    }
    qa[name] = { errors: data.errors, warnings: (data.warnings || []).filter(w => !/DataStore nepasiekiamas/.test(w)), deprecated: data.deprecated, issues };
    await page.close();
    const bad = issues.filter(i => i.kind !== 'truncated');
    console.log(`${name}: ${data.errors.length} errors, ${bad.length} layout issues, ${issues.length - bad.length} truncations`);
  }
  fs.writeFileSync(path.join(shotDir, 'qa.json'), JSON.stringify(qa, null, 2));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });

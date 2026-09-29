// Generates the HUD icon set (white line icons, 256x256 transparent PNG) into assets/icons/
// and a preview sheet. White icons can be tinted in Roblox with ImageColor3.
// Usage: node tools/icons/make_icons.js   (needs Playwright; uses the pre-installed Chromium)
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');

const S = 'fill="none" stroke="#fff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"';
const F = 'fill="#fff"';

const ICONS = {
  profile: `<circle cx="32" cy="22" r="10" ${S}/><path d="M12 54c2-11 10-17 20-17s18 6 20 17" ${S}/>`,
  academy: `<path d="M8 24 32 10l24 14" ${S}/><path d="M12 24h40" ${S}/><path d="M17 29v17M27 29v17M37 29v17M47 29v17" ${S}/><path d="M10 52h44" ${S}/><path d="M13 46h38" ${S}/>`,
  staff: `<rect x="14" y="12" width="36" height="44" rx="5" ${S}/><path d="M25 8h14v8H25z" ${S}/><path d="m21 29 4 4 7-8" ${S}/><path d="M36 30h8" ${S}/><path d="m21 43 4 4 7-8" ${S}/><path d="M36 44h8" ${S}/>`,
  scout: `<circle cx="19" cy="40" r="10" ${S}/><circle cx="45" cy="40" r="10" ${S}/><path d="M25 32 28 16h8l3 16" ${S}/><path d="M13 32 17 18M51 32 47 18" ${S}/><path d="M29 38h6" ${S}/>`,
  sponsor: `<path d="M16 8h24l10 10v38H16z" ${S}/><path d="M40 8v10h10" ${S}/><path d="M23 26h16M23 34h20" ${S}/><path d="M22 47c3-5 5-5 6-1s3 4 6-1 4-2 5 1 3 1 6-2" ${S}/>`,
  tournament: `<path d="M20 10h24v14a12 12 0 0 1-24 0z" ${S}/><path d="M20 15h-7c0 8 3 12 8 13M44 15h7c0 8-3 12-8 13" ${S}/><path d="M32 36v8" ${S}/><path d="M23 54h18M26 44h12v10H26z" ${S}/>`,
  phone: `<rect x="18" y="6" width="28" height="52" rx="6" ${S}/><path d="M28 12h8" ${S}/><circle cx="32" cy="50" r="2.5" ${F}/>`,
  money: `<circle cx="32" cy="32" r="22" ${S}/><path d="M39 23c-2-3-5-4-8-4-4 0-7 2-7 6 0 8 16 5 16 13 0 4-3 6-8 6-3 0-7-1-9-4" ${S}/><path d="M32 14v5M32 45v5" ${S}/>`,
  belt: `<path d="M4 26h14M4 38h14M46 26h14M46 38h14" ${S}/><rect x="16" y="18" width="32" height="28" rx="8" ${S}/><circle cx="32" cy="32" r="7" ${S}/><circle cx="10" cy="32" r="2" ${F}/><circle cx="54" cy="32" r="2" ${F}/>`,
  glove: `<path d="M22 50V34c-5-2-8-6-8-12 0-9 7-14 16-14h6c9 0 14 7 14 16v8c0 6-3 10-8 12v6" ${S}/><path d="M20 50h22v8H20z" ${S}/><path d="M22 34c4 2 10 2 14-1" ${S}/><path d="M30 22c-4 0-7 3-7 7" ${S}/>`,
};

(async () => {
  const outDir = path.join(__dirname, '..', '..', 'assets', 'icons');
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const page = await browser.newPage({ viewport: { width: 256, height: 256 } });
  for (const [name, body] of Object.entries(ICONS)) {
    await page.setContent(`<html><body style="margin:0;background:transparent">
      <svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 64 64">${body}</svg></body></html>`);
    await page.screenshot({ path: path.join(outDir, name + '.png'), omitBackground: true });
  }
  // preview sheet: gold on the HUD background
  const cells = Object.entries(ICONS).map(([name, body]) => `
    <div style="display:flex;flex-direction:column;align-items:center;gap:10px;width:150px">
      <div style="width:96px;height:96px;border-radius:22px;background:linear-gradient(#2a252c,#1e1b20);border:1px solid #403828;display:flex;align-items:center;justify-content:center">
        <svg width="64" height="64" viewBox="0 0 64 64" style="filter:none">${body.replaceAll('#fff', '#D4AF37')}</svg></div>
      <div style="font:600 14px sans-serif;color:#a8a096">${name}.png</div></div>`).join('');
  const sheet = await browser.newPage({ viewport: { width: 700, height: 470 } });
  await sheet.setContent(`<html><body style="margin:0;background:#16141a;padding:24px;box-sizing:border-box;display:flex;flex-wrap:wrap;gap:12px">${cells}</body></html>`);
  await sheet.screenshot({ path: path.join(outDir, '_preview.png') });
  await browser.close();
  console.log('icons:', Object.keys(ICONS).length, '->', outDir);
})().catch(e => { console.error(e); process.exit(1); });

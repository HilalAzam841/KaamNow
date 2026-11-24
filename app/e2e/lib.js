const fs = require('fs');
const BASE = process.env.APP_URL || 'http://localhost:8080/';
fs.mkdirSync('shots', { recursive: true });
async function open(browser, opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: 430, height: 900 }, ...opts });
  const page = await ctx.newPage();
  page.errors = [];
  page.on('pageerror', e => page.errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error') page.errors.push(m.text()); });
  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await sem(page);
  return page;
}
async function sem(page) {
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(600);
}
async function reveal(page, loc, tries = 14) {
  for (let i = 0; i < tries; i++) {
    if (await loc.count()) return loc;
    await page.mouse.move(215, 500);
    await page.mouse.wheel(0, 350);
    await page.waitForTimeout(350);
  }
  return loc;
}
async function type(page, label, text) {
  const box = await reveal(page, page.getByRole('textbox', { name: label, exact: true }).first());
  await box.click();
  await page.waitForTimeout(150);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(text, { delay: 5 });
  await page.waitForTimeout(150);
}
async function tap(page, role, name, opts = {}) {
  const el = await reveal(page, page.getByRole(role, { name, exact: opts.exact ?? false }).first());
  await el.waitFor({ timeout: opts.timeout ?? 15000 });
  await el.click();
  await page.waitForTimeout(opts.wait ?? 900);
}
async function see(page, text, timeout = 15000) {
  await page.getByText(text, { exact: false }).first().waitFor({ timeout });
}
async function shot(page, name) { await page.screenshot({ path: `shots/${name}.png` }); }
module.exports = { reveal, open, sem, type, tap, see, shot, BASE };

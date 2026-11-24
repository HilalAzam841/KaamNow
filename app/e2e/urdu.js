// Urdu walk-through: checks the app opens in English, picks Urdu from the language menu, then visits the customer's and the
// worker's main screens (right to left, Nastaliq font, Urdu alerts and category names from the
// server) and switches back to English. Run after step1-3, which create the users it signs in as.
const fs = require('fs');
const { chromium } = require('playwright');
const L = require('./lib');

const state = JSON.parse(fs.readFileSync('state.json', 'utf8'));
const PASSWORD = 'kaamnow-pass-123';

// Opens the language menu in the top bar and picks a language.
async function pick(page, name) {
  await L.tap(page, 'button', 'Language / زبان', { exact: false, wait: 800 });
  await page.getByRole('menuitemcheckbox', { name, exact: true }).click();
  await page.waitForTimeout(1500);
}

async function login(page, phone) {
  // Urdu labels: فون نمبر = phone number, پاس ورڈ = password, لاگ اِن = log in.
  await L.type(page, 'فون نمبر', phone);
  await L.type(page, 'پاس ورڈ', PASSWORD);
  await L.tap(page, 'button', 'لاگ اِن', { exact: true, wait: 3500 });
}

async function visit(page, hash, name, expect) {
  await page.goto(new URL(hash, L.BASE).toString());
  await page.waitForTimeout(2500);
  await L.sem(page);
  if (expect) await L.see(page, expect);
  await L.shot(page, name);
}

(async () => {
  const browser = await chromium.launch();
  let step = 'start';
  const pages = [];
  try {
    step = 'switch language on the login screen';
    // A browser set to Urdu still opens the app in English: Urdu is only used once picked.
    const page = await L.open(browser, { locale: 'ur-PK' });
    pages.push(page);
    await L.see(page, 'Log in');
    await L.shot(page, 'urdu-00-login-english');
    await pick(page, 'اردو');
    await L.see(page, 'لاگ اِن');
    const dir = await page.evaluate(() => getComputedStyle(document.querySelector('flt-semantics-host') || document.body).direction);
    await L.shot(page, 'urdu-01-login');

    step = 'customer home';
    await login(page, state.customerPhone);
    await L.see(page, 'السلام علیکم');
    await L.see(page, 'الیکٹریشن');
    await L.shot(page, 'urdu-02-customer-home');

    step = 'customer screens';
    await visit(page, '#/requests', 'urdu-03-my-requests');
    await visit(page, '#/bookings', 'urdu-04-bookings');
    const booking = page.getByRole('button', { name: /بکنگ|Fan|fan/ }).first();
    if (await booking.count()) {
      await booking.click();
      await page.waitForTimeout(2500);
      await L.shot(page, 'urdu-05-booking-detail');
    }
    await visit(page, '#/notifications', 'urdu-06-alerts', 'اطلاعات');
    await visit(page, '#/account', 'urdu-07-account');

    step = 'server messages in Urdu';
    const api = process.env.API_URL || 'http://localhost:8000/api/v1';
    const r = await fetch(`${api}/auth/login/`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept-Language': 'ur' },
      body: JSON.stringify({ phone: '03000000000', password: 'x' }),
    });
    const lang = (await r.json()).error.message;
    if (!/غلط/.test(lang)) throw new Error(`login error not in Urdu: ${lang}`);

    step = 'worker screens';
    const ctx2 = await L.open(browser);
    pages.push(ctx2);
    await pick(ctx2, 'اردو');
    await login(ctx2, state.workerPhone);
    await L.shot(ctx2, 'urdu-08-worker-feed');
    await visit(ctx2, '#/offers', 'urdu-09-worker-offers');
    await visit(ctx2, '#/worker/earnings', 'urdu-10-worker-earnings');
    await visit(ctx2, '#/worker/profile', 'urdu-11-worker-profile');

    step = 'switch back to English';
    await visit(page, '#/account', 'urdu-12-account-before-switch');
    await pick(page, 'English');
    await L.see(page, 'Account');
    await L.shot(page, 'urdu-13-account-english');

    // Map tiles come from openstreetmap.org, which a sandbox without internet cannot reach.
    const errors = pages.flatMap(p => p.errors).filter(e => !/ERR_TUNNEL_CONNECTION_FAILED|ERR_NAME_NOT_RESOLVED/.test(e));
    if (errors.length) throw new Error(`page errors: ${errors.join(' | ')}`);
    console.log(`OK Urdu walk-through (semantics direction: ${dir})`);
  } catch (e) {
    console.log(`FAIL at ${step}: ${e.message}`);
    for (const [i, p] of pages.entries()) await L.shot(p, `urdu-fail-${i}`).catch(() => {});
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();

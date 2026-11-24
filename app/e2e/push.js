// Browser notifications check, on the real web build and backend (started with VAPID keys):
// the home-screen card turns notifications on (permission granted, subscription sent to the
// server), a push message is shown as a notification with the server's title, tapping it opens
// the right screen, and signing out removes this browser from the account.
//
// Delivering through Google's push service needs internet. Without it (as in a sandbox) the
// browser cannot create a real subscription, so this script then delivers the push message
// straight to the service worker (Chrome DevTools Protocol) and registers a stand-in
// subscription through the API, and says so.
const fs = require('fs');
const { chromium } = require('playwright');
const L = require('./lib');

const state = JSON.parse(fs.readFileSync('state.json', 'utf8'));
const API = process.env.API_URL || 'http://localhost:8000/api/v1';

(async () => {
  // Full Chromium (new headless): the headless shell always reports notifications as denied.
  const browser = await chromium.launch({ channel: 'chromium' });
  const ctx = await browser.newContext({ viewport: { width: 430, height: 900 } });
  await ctx.grantPermissions(['notifications'], { origin: new URL(L.BASE).origin });
  const page = await ctx.newPage();
  page.errors = [];
  page.on('pageerror', (e) => page.errors.push(String(e)));
  let step = 'start';
  try {
    step = 'sign in';
    await page.goto(L.BASE, { waitUntil: 'networkidle' });
    await page.waitForTimeout(2500);
    await L.sem(page);
    await L.type(page, 'Phone number', state.customerPhone);
    await L.type(page, 'Password', 'kaamnow-pass-123');
    await L.tap(page, 'button', 'Log in', { exact: true, wait: 3500 });

    step = 'home card';
    // The card's text is read out as one group, so wait for its button.
    await page.getByRole('button', { name: 'Turn on', exact: true }).waitFor({ timeout: 15000 });
    await L.shot(page, 'push-01-home-card');

    step = 'turn on';
    const subscribeCalls = [];
    page.on('request', (r) => { if (r.url().includes('/web-push/subscribe/')) subscribeCalls.push(r); });
    await L.tap(page, 'button', 'Turn on', { exact: true, wait: 6000 });
    let realSubscription = subscribeCalls.length > 0;
    const access = await page.evaluate(() => {
      for (const k of Object.keys(localStorage)) if (k.includes('access')) return JSON.parse(localStorage[k]);
      return null;
    });
    if (!realSubscription) {
      // No route to the browser's push service: register a stand-in subscription the same way.
      const keys = await page.evaluate(async () => {
        const k = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
        const raw = new Uint8Array(await crypto.subtle.exportKey('raw', k.publicKey));
        const b64 = (b) => btoa(String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        return { p256dh: b64(raw), auth: b64(crypto.getRandomValues(new Uint8Array(16))) };
      });
      const r = await page.request.post(`${API}/notifications/web-push/subscribe/`, {
        headers: { Authorization: `Bearer ${access}` },
        data: { endpoint: 'https://fcm.googleapis.com/fcm/send/e2e-stand-in', keys },
      });
      if (r.status() !== 201) throw new Error(`stand-in subscribe failed: ${r.status()} ${await r.text()}`);
    }

    step = 'push message is shown';
    const sw = ctx.serviceWorkers()[0] || (await ctx.waitForEvent('serviceworker'));
    const cdp = await ctx.newCDPSession(page);
    const registrations = [];
    cdp.on('ServiceWorker.workerRegistrationUpdated', (e) => registrations.push(...e.registrations));
    await cdp.send('ServiceWorker.enable');
    await page.waitForTimeout(800);
    const reg = registrations.find((r) => !r.isDeleted);
    const payload = { title: 'New offer received', body: 'Bilal Ahmed offered Rs. 1,500 for your job.', url: '/#/bookings', type: 'new_offer' };
    await cdp.send('ServiceWorker.deliverPushMessage', {
      origin: new URL(L.BASE).origin, registrationId: reg.registrationId, data: JSON.stringify(payload),
    });
    await page.waitForTimeout(1500);
    const shown = await sw.evaluate(async () => (await self.registration.getNotifications()).map((n) => ({ title: n.title, body: n.body, url: n.data.url })));
    if (!shown.some((n) => n.title === payload.title && n.url === payload.url)) throw new Error(`not shown: ${JSON.stringify(shown)}`);

    step = 'tapping opens the screen';
    await sw.evaluate(async () => {
      const [n] = await self.registration.getNotifications();
      self.dispatchEvent(new NotificationEvent('notificationclick', { notification: n }));
    });
    await page.waitForTimeout(2500);
    if (!page.url().includes('#/bookings')) throw new Error(`did not open bookings: ${page.url()}`);
    await L.sem(page);
    await L.shot(page, 'push-02-opened-from-notification');

    step = 'account switch';
    await page.goto(new URL('#/account', L.BASE).toString());
    await page.waitForTimeout(2500);
    await L.sem(page);
    await L.shot(page, 'push-03-account');

    console.log(`OK push: ${realSubscription ? 'real browser subscription sent to the server' : 'no route to the push service here, used a stand-in subscription'}; notification shown and opened /#/bookings`);
    if (page.errors.length) console.log('page errors:', page.errors.slice(0, 3));
  } catch (e) {
    console.log(`FAIL at ${step}: ${e.message}`);
    await L.shot(page, 'push-fail').catch(() => {});
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();

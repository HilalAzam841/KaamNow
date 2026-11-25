// Google Maps on the website: with GOOGLE_MAPS_BROWSER_KEY set on the server, the job form's map
// is Google's (the page loads Google's script); without it, OpenStreetMap and no Google script.
//   GOOGLE_MAPS_BROWSER_KEY=... daphne ...   then   EXPECT=google node maps.js
//   (no key)                                         EXPECT=osm node maps.js
// Uses the demo customer from `python manage.py seed_demo_data`.
const { chromium } = require('playwright');
const L = require('./lib');

const EXPECT = process.env.EXPECT || 'google';

(async () => {
  const browser = await chromium.launch();
  const page = await L.open(browser);
  const googleRequests = [];
  page.on('request', r => { if (r.url().startsWith('https://maps.googleapis.com/')) googleRequests.push(r.url()); });
  try {
    await L.type(page, 'Phone number', '03000000002');
    await L.type(page, 'Password', 'KaamNow-Demo-2026');
    await L.tap(page, 'button', 'Log in', { exact: true, wait: 3500 });
    await page.goto(new URL('#/requests/new', L.BASE).toString());
    await page.waitForTimeout(6000);
    await L.sem(page);
    const google = await page.evaluate(() => !!(window.google && window.google.maps));
    const tiles = await page.evaluate(() => document.querySelectorAll('flt-platform-view, .gm-style').length);
    await L.shot(page, `maps-${EXPECT}`);
    console.log({ google, platformViews: tiles, googleRequests: googleRequests.length });
    if (EXPECT === 'google') {
      if (!google || !googleRequests.length || !tiles) throw new Error('Google Maps did not load');
      if (!googleRequests[0].includes('key=')) throw new Error('Script loaded without the key');
    } else if (google || googleRequests.length) {
      throw new Error('Google Maps loaded without a key');
    }
    console.log(`maps.js: OK (${EXPECT})`);
  } catch (e) {
    console.error('maps.js failed:', e.message, page.errors);
    await L.shot(page, 'maps-failed');
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();

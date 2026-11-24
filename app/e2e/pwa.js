// Installable app check: manifest, icons, service worker, Chrome's installability audit,
// the offline page, and that API responses are never stored by the service worker.
// Needs the web build served (see README) and, for the API part, the backend.
const { chromium } = require('playwright');
const L = require('./lib');

(async () => {
  const browser = await chromium.launch();
  let step = 'start';
  const ctx = await browser.newContext({ viewport: { width: 430, height: 900 } });
  const page = await ctx.newPage();
  try {
    step = 'load and register the service worker';
    await page.goto(L.BASE, { waitUntil: 'networkidle' });
    await page.waitForTimeout(2500);
    await page.evaluate(() => navigator.serviceWorker.ready);
    await page.reload({ waitUntil: 'networkidle' }); // now controlled by the worker
    await page.waitForTimeout(2500);
    const controlled = await page.evaluate(() => !!navigator.serviceWorker.controller);
    if (!controlled) throw new Error('page is not controlled by the service worker');

    step = 'manifest';
    const manifest = await page.evaluate(async () => (await fetch('manifest.json')).json());
    if (manifest.short_name !== 'KaamNow' || manifest.display !== 'standalone') throw new Error('manifest fields');
    for (const icon of manifest.icons) {
      const r = await page.request.get(new URL(icon.src, L.BASE).toString());
      if (!r.ok()) throw new Error(`icon missing: ${icon.src}`);
    }

    step = 'installability audit';
    const cdp = await ctx.newCDPSession(page);
    const { installabilityErrors } = await cdp.send('Page.getInstallabilityErrors');
    if (installabilityErrors.length) throw new Error(JSON.stringify(installabilityErrors));
    const { url: manifestUrl, errors } = await cdp.send('Page.getAppManifest');
    if (errors.length) throw new Error(`manifest errors: ${JSON.stringify(errors)}`);

    step = 'API responses are not cached';
    const api = process.env.API_URL || 'http://localhost:8000/api/v1';
    await page.evaluate(async (u) => { try { await fetch(`${u}/app/config/`); } catch (e) {} }, api);
    await page.evaluate(async () => { try { await fetch('api/v1/health/'); } catch (e) {} });
    const cached = await page.evaluate(async () => {
      const names = await caches.keys();
      const urls = [];
      for (const n of names) for (const r of await (await caches.open(n)).keys()) urls.push(r.url);
      return urls;
    });
    if (cached.some((u) => /\/api\/|\/media\/|\/ws\//.test(u))) throw new Error(`API cached: ${cached}`);
    if (!cached.some((u) => u.endsWith('main.dart.js'))) throw new Error('app files were not kept for offline use');

    step = 'offline page';
    await ctx.setOffline(true);
    await page.reload().catch(() => {});
    await page.waitForTimeout(1500);
    await L.see(page, 'You are offline');
    await L.shot(page, 'pwa-offline');
    await ctx.setOffline(false);
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForTimeout(2500);
    await L.sem(page);
    await L.see(page, 'Log in');

    console.log(`OK installable (${manifestUrl}), ${cached.length} app files kept offline, API never cached`);
  } catch (e) {
    console.log(`FAIL at ${step}: ${e.message}`);
    await L.shot(page, 'pwa-fail').catch(() => {});
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();

// Admin dashboard walk-through: overview, worker verification with a private CNIC image,
// users, jobs, revenue, plans, complaints, settings and the audit log.
// Needs a pending worker with CNIC uploads (run step1/step2 first, or any signed-up worker).
const { chromium } = require('playwright');
const L = require('./lib');

// Text inside a tile is exposed as the button's or group's label, not as text.
async function seeAnywhere(page, t, timeout = 15000) {
  const re = new RegExp(t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  await page.getByText(t).or(page.getByRole('button', { name: re })).or(page.getByRole('group', { name: re })).first().waitFor({ timeout });
}

(async () => {
  const browser = await chromium.launch();
  const page = await L.open(browser, { viewport: { width: 1400, height: 900 } });
  const ADMIN_PHONE = process.env.ADMIN_PHONE || '03009999999';
  const ADMIN_PASS = process.env.ADMIN_PASSWORD || 'admin-pass-123';
  try {
    await L.type(page, 'Phone number', ADMIN_PHONE);
    await L.type(page, 'Password', ADMIN_PASS);
    await L.tap(page, 'button', 'Log in', { exact: true, wait: 3000 });
    await L.see(page, 'Workers waiting for verification');
    await L.shot(page, 'admin-01-overview');

    await L.tap(page, 'tab', 'Verification', { exact: true, wait: 2000 });
    await L.shot(page, 'admin-02-queue');
    const pending = page.getByRole('button', { name: /CNIC/ }).first();
    if (await pending.count()) {
      await pending.click();
      await page.waitForTimeout(2500);
      await L.see(page, 'Review worker');
      await L.tap(page, 'button', 'View', { wait: 2500 });
      await L.shot(page, 'admin-03-review');
      await page.goBack();
      await page.waitForTimeout(2000);
      await L.sem(page);
    }

    for (const [nav, expect, name] of [
      ['Users', '+92', 'admin-04-users'],
      ['Jobs', 'Rs ', 'admin-05-jobs'],
      ['Revenue', 'Rs ', 'admin-06-revenue'],
      ['Plans', 'days', 'admin-07-plans'],
      ['Complaints', 'Complaints', 'admin-08-complaints'],
      ['Settings', 'Last changed', 'admin-09-settings'],
      ['Audit log', 'Admin ·', 'admin-10-audit'],
    ]) {
      await L.tap(page, 'tab', nav, { exact: true, wait: 2200 });
      await seeAnywhere(page, expect);
      await L.shot(page, name);
    }

    // Reload keeps the admin on the same page.
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);
    await L.sem(page);
    await L.see(page, 'Admin ·');
    console.log('ADMIN OK', page.url());
    if (page.errors.length) console.log('page errors:', page.errors.slice(0, 5));
  } catch (e) {
    await L.shot(page, 'admin-failure');
    console.log('ADMIN FAILED', e.message, page.errors.slice(0, 5));
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();

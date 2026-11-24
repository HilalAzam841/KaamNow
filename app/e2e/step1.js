// Customer registers and posts a job through the UI.
const { chromium } = require('playwright');
const L = require('./lib');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch();
  const run = Date.now() % 10000000;
  const phone = '0300' + String(run).padStart(7, '0');
  const page = await L.open(browser, { geolocation: { latitude: 31.5204, longitude: 74.3587 }, permissions: ['geolocation'] });
  try {
    await L.tap(page, 'button', 'Create an account');
    await L.type(page, 'Full name', 'Ayesha Khan');
    await L.type(page, 'Phone number', phone);
    await L.type(page, 'Password', 'kaamnow-pass-123');
    await L.shot(page, '01-register');
    await L.tap(page, 'button', 'Create account', { exact: true, wait: 2500 });
    await L.see(page, 'What do you need help with?');
    await L.sem(page);
    await L.shot(page, '02-customer-home');
    await L.tap(page, 'button', 'Electrician', { wait: 2500 });
    await L.see(page, 'Post a job');
    await L.type(page, 'Title', 'Ceiling fan not working');
    await L.type(page, 'Describe the problem', 'The fan in the lounge stopped after a power cut. Regulator may be faulty.');
    await L.tap(page, 'button', 'Use my location', { wait: 2500 });
    await L.type(page, 'Address', 'House 12, Street 4, Gulberg III');
    await L.type(page, 'Area (optional)', 'Gulberg');
    await L.shot(page, '03-new-request');
    await L.tap(page, 'button', 'Post job and get offers', { wait: 3000 });
    await L.see(page, 'Waiting for offers');
    await L.shot(page, '04-request-waiting');
    const url = page.url();
    console.log('OK customer', phone, url);
    fs.writeFileSync('state.json', JSON.stringify({ customerPhone: phone, requestUrl: url }));
  } catch (e) {
    await L.shot(page, 'fail-step1');
    console.log('FAIL', e.message.split('\n')[0]);
    console.log((await page.locator('body').ariaSnapshot()).slice(0, 1500));
  }
  console.log('errors:', page.errors.slice(0, 5));
  await browser.close();
})();

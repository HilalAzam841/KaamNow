// Phone verification and "Forgot password" by SMS, on the real web build and backend.
// Start the backend with PHONE_VERIFICATION_REQUIRED=true and DJANGO_DEBUG=true (SMS go to its
// log) and pass that log file: SMS_LOG=/path/to/daphne.log node phone.js
const fs = require('fs');
const { chromium } = require('playwright');
const L = require('./lib');

const LOG = process.env.SMS_LOG;
if (!LOG) { console.log('Set SMS_LOG to the backend log file.'); process.exit(2); }

// The newest code the backend "sent" to this number (console SMS backend writes "SMS to +92...: ...").
async function lastCode(phone, after) {
  for (let i = 0; i < 40; i++) {
    const lines = fs.readFileSync(LOG, 'utf8').split('\n').slice(after).filter((l) => l.includes(`SMS to ${phone}:`));
    const m = lines.length && lines[lines.length - 1].match(/code is (\d{6})/);
    if (m) return m[1];
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`no SMS to ${phone} in ${LOG}`);
}
const logLines = () => fs.readFileSync(LOG, 'utf8').split('\n').length - 1;

(async () => {
  const browser = await chromium.launch();
  const run = Date.now() % 10000000;
  const local = '0333' + String(run).padStart(7, '0');
  const intl = '+92' + local.slice(1);
  const page = await L.open(browser);
  let step = 'register';
  try {
    await L.tap(page, 'button', 'Create an account');
    await L.type(page, 'Full name', 'Sana Tariq');
    await L.type(page, 'Phone number', local);
    await L.type(page, 'Password', 'kaamnow-pass-123');
    await L.tap(page, 'button', 'Create account', { exact: true, wait: 2500 });

    step = 'confirm number';
    await L.see(page, 'Confirm your phone number');
    await L.shot(page, 'phone-01-confirm');
    let mark = logLines();
    await L.tap(page, 'button', 'Send code', { exact: true, wait: 1500 });
    await L.see(page, 'Send a new code in');
    const wrong = '000000';
    await L.type(page, '6-digit code', wrong);
    await L.tap(page, 'button', 'Confirm', { exact: true, wait: 1500 });
    await L.see(page, 'Wrong or expired code.');
    const code = await lastCode(intl, mark);
    await L.type(page, '6-digit code', code);
    await L.shot(page, 'phone-02-code');
    await L.tap(page, 'button', 'Confirm', { exact: true, wait: 2500 });
    await L.see(page, 'What do you need help with?');
    await L.sem(page);
    await L.shot(page, 'phone-03-home');

    step = 'log out';
    await page.goto(new URL('#/account', L.BASE).toString());
    await page.waitForTimeout(2000);
    await L.sem(page);
    await L.tap(page, 'button', 'Log out', { wait: 2000 });

    step = 'forgot password';
    await L.tap(page, 'button', 'Forgot password?', { wait: 1500 });
    await L.see(page, 'Forgot your password?');
    await L.type(page, 'Your phone number', local);
    mark = logLines();
    await L.tap(page, 'button', 'Send code', { exact: true, wait: 2000 });
    const reset = await lastCode(intl, mark);
    await L.type(page, '6-digit code', reset);
    await L.type(page, 'New password', 'fresh-pass-456');
    await L.type(page, 'Repeat new password', 'fresh-pass-456');
    await L.shot(page, 'phone-04-reset');
    await L.tap(page, 'button', 'Save new password', { wait: 2000 });
    await L.see(page, 'Password changed');
    await L.tap(page, 'button', 'Back to log in', { wait: 1500 });

    step = 'log in with the new password';
    await L.type(page, 'Phone number', local);
    await L.type(page, 'Password', 'fresh-pass-456');
    await L.tap(page, 'button', 'Log in', { exact: true, wait: 3000 });
    await L.see(page, 'What do you need help with?');

    console.log(`OK phone: ${local} confirmed by SMS code, password reset by SMS code, signed in with the new password`);
    if (page.errors.length) console.log('page errors:', page.errors.slice(0, 3));
  } catch (e) {
    console.log(`FAIL at ${step}: ${e.message}`);
    await L.shot(page, 'phone-fail').catch(() => {});
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();

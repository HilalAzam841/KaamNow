// Worker signs up, completes profile (service, CNIC, base location), gets verified, and sends an offer.
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const L = require('./lib');
const fs = require('fs');
const path = require('path');
const BACKEND = process.env.BACKEND_DIR || path.resolve(__dirname, '../..');
if (!fs.existsSync('cnic.jpg')) execSync(`python3 -c "from PIL import Image; Image.new('RGB', (400, 250), (200, 210, 220)).save('cnic.jpg')"`);
(async () => {
  const state = JSON.parse(fs.readFileSync('state.json'));
  const browser = await chromium.launch();
  const run = Date.now() % 10000000;
  const phone = '0321' + String(run).padStart(7, '0');
  const page = await L.open(browser, { geolocation: { latitude: 31.5150, longitude: 74.3500 }, permissions: ['geolocation'] });
  try {
    await L.tap(page, 'button', 'Create an account');
    await L.tap(page, 'button', 'Offer services');
    await L.type(page, 'Full name', 'Bilal Ahmed');
    await L.type(page, 'Phone number', phone);
    await L.type(page, 'CNIC number', '35202-' + String(run).padStart(7, '0') + '-1');
    await L.type(page, 'Password', 'kaamnow-pass-123');
    await L.tap(page, 'button', 'Create account', { exact: true, wait: 3000 });
    await L.see(page, 'Get verified to send offers');
    await L.sem(page);
    await L.shot(page, '05-worker-unverified');
    await L.tap(page, 'button', 'Get verified to send offers', { wait: 2500 });
    await L.see(page, 'Verification documents');
    for (const label of ['CNIC front', 'CNIC back']) {
      const [chooser] = await Promise.all([
        page.waitForEvent('filechooser'),
        page.getByRole('button', { name: 'Upload' }).nth(label === 'CNIC front' ? 0 : 1).click(),
      ]);
      await chooser.setFiles('cnic.jpg');
      await L.see(page, label + ' uploaded');
      await page.waitForTimeout(1500);
    }
    await L.tap(page, 'button', 'Add');
    await page.getByRole('button', { name: 'Service' }).first().click().catch(() => {});
    await page.waitForTimeout(700);
    await L.tap(page, 'menuitem', 'Electrician', { exact: true }).catch(async () => L.tap(page, 'button', 'Electrician', { exact: true }));
    await L.type(page, 'Starting price (optional)', '500');
    await L.tap(page, 'button', 'Add', { exact: true, wait: 2000 });
    await L.see(page, 'Service added');
    await L.type(page, 'Years of experience', '6');
    await L.type(page, 'Areas you cover', 'Gulberg, Model Town');
    await L.tap(page, 'button', 'Use my location', { wait: 2500 });
    await L.tap(page, 'button', 'Save profile', { wait: 2500 });
    await L.see(page, 'Profile saved');
    await L.shot(page, '06-worker-profile');

    // Admin verifies the worker (stands in for the admin dashboard).
    execSync(`cd ${BACKEND} && python manage.py shell -c "
from apps.accounts.models import WorkerProfile
from apps.accounts import services as s
w = WorkerProfile.objects.get(user__phone__endswith='${phone.slice(1)}')
from django.contrib.auth import get_user_model
admin = get_user_model().objects.filter(is_superuser=True).first() or get_user_model().objects.create_superuser(phone='+923009999999', password='admin-pass-123', full_name='Admin')
s.verify_worker(w, admin) if hasattr(s, 'verify_worker') else None
w.refresh_from_db(); print('verified', w.verification_status)
"`, { stdio: 'inherit' });

    await page.goBack();
    await page.waitForTimeout(1500);
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForTimeout(2500);
    await L.sem(page);
    await page.getByRole('switch').first().waitFor();
    if ((await page.getByRole('switch').first().getAttribute('aria-checked')) !== 'true') {
      await page.getByRole('switch').first().click();
      await page.waitForTimeout(2500);
    }
    await L.sem(page);
    await L.see(page, 'Ceiling fan not working');
    await L.shot(page, '07-worker-feed');
    await L.tap(page, 'button', 'Ceiling fan not working', { wait: 2500 });
    await L.sem(page);
    await L.see(page, 'Send your price');
    await L.type(page, 'Your price', '1800');
    await L.type(page, 'You can arrive in (minutes)', '30');
    await L.type(page, 'Message to the customer (optional)', 'I can fix the regulator today');
    await L.tap(page, 'button', 'Send offer', { wait: 2500 });
    await page.getByRole('group', { name: /Your offer/ }).first().waitFor();
    await L.shot(page, '08-worker-offer-sent');
    state.workerPhone = phone;
    fs.writeFileSync('state.json', JSON.stringify(state));
    console.log('OK worker', phone);
  } catch (e) {
    await L.shot(page, 'fail-step2');
    console.log('FAIL', e.message.split('\n')[0]);
    console.log((await page.locator('body').ariaSnapshot()).slice(0, 2500));
  }
  console.log('errors:', page.errors.filter(e => !e.includes('TUNNEL')).slice(0, 5));
  await browser.close();
})();

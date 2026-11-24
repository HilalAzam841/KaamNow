// Customer books the worker; the job runs end to end with live tracking, chat, completion code, cash payment, review.
const { chromium } = require('playwright');
const L = require('./lib');
const fs = require('fs');

async function login(browser, phone, geo) {
  const page = await L.open(browser, geo ? { geolocation: geo, permissions: ['geolocation'] } : {});
  await L.type(page, 'Phone number', phone);
  await L.type(page, 'Password', 'kaamnow-pass-123');
  await L.tap(page, 'button', 'Log in', { exact: true, wait: 3000 });
  await L.sem(page);
  return page;
}
const snap = async (p) => (await p.locator('body').ariaSnapshot());
async function waitSnap(p, re, timeout = 20000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const s = await snap(p);
    if (re.test(s)) return s;
    await p.waitForTimeout(700);
  }
  throw new Error('not found in snapshot: ' + re + '\n' + (await snap(p)).slice(0, 1500));
}

(async () => {
  const st = JSON.parse(fs.readFileSync('state.json'));
  const browser = await chromium.launch();
  const customer = await login(browser, st.customerPhone);
  const worker = await login(browser, st.workerPhone, { latitude: 31.5170, longitude: 74.3520 });
  let step = 'start';
  try {
    step = 'customer opens request and books';
    await L.tap(customer, 'tab', 'My requests', { wait: 2000 });
    await L.tap(customer, 'button', 'Ceiling fan not working', { wait: 2500 });
    await L.sem(customer);
    await waitSnap(customer, /Book for Rs 1,800/);
    await L.shot(customer, '09-customer-offers');
    await L.tap(customer, 'button', 'Book for Rs 1,800');
    await L.tap(customer, 'button', 'Book', { exact: true, wait: 3000 });
    await L.sem(customer);
    await waitSnap(customer, /Booking #\d+/);
    await L.shot(customer, '10-customer-booking-confirmed');

    step = 'worker starts the job';
    await L.tap(worker, 'tab', 'Bookings', { wait: 2000 });
    await L.tap(worker, 'button', 'Ceiling fan not working', { wait: 2500 });
    await L.sem(worker);
    await waitSnap(worker, /House 12, Street 4/);   // address revealed only after booking
    await L.tap(worker, 'button', 'on my way', { wait: 3000 });
    await waitSnap(worker, /On the way/);
    await L.shot(worker, '11-worker-on-the-way');

    step = 'customer sees live tracking';
    const tracked = await waitSnap(customer, /km away/, 30000);
    console.log('tracking:', (tracked.match(/Bilal is [^\n"]*/) || [''])[0]);
    await L.shot(customer, '12-customer-tracking');

    step = 'chat';
    await L.tap(customer, 'button', 'Chat', { wait: 2500 });
    await L.sem(customer);
    await L.type(customer, 'Type a message', 'Gate code is 4321, please ring twice');
    await L.tap(customer, 'button', 'Send', { exact: false, wait: 1500 }).catch(() => customer.keyboard.press('Enter'));
    await L.tap(worker, 'button', 'Chat', { wait: 2500 });
    await L.sem(worker);
    await waitSnap(worker, /Gate code is 4321/);
    await L.type(worker, 'Type a message', 'On my way, 10 minutes');
    await worker.keyboard.press('Enter');
    await waitSnap(customer, /On my way, 10 minutes/, 15000);   // arrives live over WebSocket
    await L.shot(customer, '13-chat');
    await customer.goBack(); await customer.waitForTimeout(1500); await L.sem(customer);
    await worker.goBack(); await worker.waitForTimeout(1500); await L.sem(worker);

    step = 'arrive and start';
    await L.tap(worker, 'button', 'arrived', { wait: 2500 });
    await waitSnap(worker, /Start work/);
    await L.tap(worker, 'button', 'Start work', { wait: 2500 });
    await waitSnap(worker, /Complete with customer/);
    await waitSnap(customer, /Get completion code/, 20000);   // status pushed over WebSocket

    step = 'completion code';
    await L.tap(customer, 'button', 'Get completion code', { wait: 2000 });
    const dlg = await waitSnap(customer, /Completion code/);
    const code = (dlg.match(/\b(\d{6})\b/) || [])[1];
    if (!code) throw new Error('no code in dialog: ' + dlg.slice(0, 600));
    await L.shot(customer, '14-completion-code');
    await L.tap(customer, 'button', 'Done', { exact: true });
    await L.tap(worker, 'button', 'Complete with customer', { wait: 1200 });
    await L.type(worker, '6-digit code from the customer', code);
    await L.tap(worker, 'button', 'Complete job', { exact: true, wait: 3000 });
    await waitSnap(worker, /Completed/);

    step = 'cash payment';
    await customer.reload({ waitUntil: 'networkidle' }); await customer.waitForTimeout(2500); await L.sem(customer);
    await L.tap(customer, 'button', 'Pay with Cash', { wait: 2500 });
    await waitSnap(customer, /Waiting for the worker to confirm/);
    await worker.reload({ waitUntil: 'networkidle' }); await worker.waitForTimeout(2500); await L.sem(worker);
    await L.tap(worker, 'button', 'Received', { wait: 1200 });
    await L.tap(worker, 'button', 'Confirm', { exact: true, wait: 2500 });
    await waitSnap(worker, /Paid Rs 1,800/);
    await L.shot(worker, '15-worker-paid');

    step = 'review';
    await customer.reload({ waitUntil: 'networkidle' }); await customer.waitForTimeout(2500); await L.sem(customer);
    await waitSnap(customer, /Paid Rs 1,800/);
    await L.tap(customer, 'button', 'Rate Bilal', { wait: 1500 });
    await L.tap(customer, 'button', 'Submit', { exact: true, wait: 2500 });
    await customer.waitForTimeout(1500);
    const after = await snap(customer);
    if (/Rate Bilal/.test(after)) throw new Error('review button still visible');
    await L.shot(customer, '16-customer-done');

    step = 'worker earnings';
    await worker.goto(L.BASE + '#/worker/earnings', { waitUntil: 'networkidle' });   // deep link
    await worker.waitForTimeout(2500); await L.sem(worker);
    const earn = await waitSnap(worker, /You earned/);
    console.log('earnings:', earn.replace(/\s+/g, ' ').slice(0, 300));
    await L.shot(worker, '17-worker-earnings');
    console.log('OK full journey');
  } catch (e) {
    console.log('FAIL at', step, '-', e.message.slice(0, 1800));
    await L.shot(customer, 'fail-customer');
    await L.shot(worker, 'fail-worker');
  }
  const errs = [...customer.errors, ...worker.errors].filter(e => !e.includes('TUNNEL'));
  console.log('page errors:', errs.slice(0, 5));
  await browser.close();
})();

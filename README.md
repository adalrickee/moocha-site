# moocha — setup guide

This is written assuming you've never done this before. Take it one step at
a time — none of it requires knowing how to code.

## What's in this folder

- `index.html` — the whole app (customer menu + hidden staff dashboard)
- `assets/` — your logo and drink photos
- `supabase-schema.sql` — sets up your database (you'll copy-paste this once)

**You can preview it right now, before doing anything else:** double-click
`index.html`. It'll open in your web browser and works fully — you can browse
the menu, add to cart, and even complete a fake checkout. It'll just be
running in "demo mode" (saved only on your own computer) until you connect
Supabase in the steps below. This is exactly how it'll look once it's live.

---

## Part 1 — Supabase (the database that stores orders)

Supabase is a free service that gives your app a real, shared database —
this is what lets you (staff) see orders that customers place from their
own phones.

1. Go to **[supabase.com](https://supabase.com)** and sign up (you can use
   your Google account, it's quick).
2. Click **New project**. Give it any name (e.g. "moocha"), set a database
   password (just something you'll remember — you probably won't need it
   again), pick the region closest to Singapore, and click **Create**.
3. Wait a minute or two while it sets itself up.
4. On the left sidebar, click **SQL Editor**.
5. Click **New query**. This opens a blank text box.
6. Open `supabase-schema.sql` (it's in this folder) in any text editor,
   select all the text, copy it, and paste it into that box on the
   Supabase website.
7. Click **Run** (bottom right). You should see a green "Success" message.
   That's it — your database now exists, with your menu already loaded in
   and your staff passphrase set to `QUEENraks!`.
8. On the left sidebar, go to **Project Settings** (the gear icon at the
   bottom) → **API**.
9. You'll see two things you need:
   - **Project URL** — looks like `https://abcdefgh.supabase.co`
   - **anon public** key — a long string of letters and numbers starting
     with `eyJ`
   Keep this browser tab open, you'll copy these in a second.

## Part 2 — Connect the app to your database

1. Open `index.html` in a plain text editor — **not** Word or Pages.
   - On Mac: right-click the file → Open With → **TextEdit**
   - On Windows: right-click the file → Open With → **Notepad**
2. Use "Find" (Cmd+F on Mac, Ctrl+F on Windows) and search for:
   `PASTE_YOUR_SUPABASE_URL_HERE`
3. Replace the text between the quotes with your **Project URL** from
   step 9 above. It should now look like:
   `const SUPABASE_URL = "https://abcdefgh.supabase.co";`
4. Do the same for `PASTE_YOUR_SUPABASE_ANON_KEY_HERE`, replacing it with
   your **anon public** key.
5. Save the file (Cmd+S / Ctrl+S) and close it.

## Part 3 — Netlify (puts your app on the internet)

1. Go to **[netlify.com](https://netlify.com)** and sign up (Google account
   works here too).
2. On your dashboard, look for a box that says something like "Drag and
   drop your site output folder here" (under **Sites** → **Add new site**
   → **Deploy manually**).
3. Drag the **whole `moocha-site` folder** (the one with `index.html`
   inside it) onto that box.
4. Wait a few seconds — Netlify gives you a live web address, something
   like `https://random-name-12345.netlify.app`. That's your ordering
   site! Anyone with that link can open it on their phone right now.
5. (Optional) In Netlify, under **Site settings** → **Change site name**,
   you can pick a nicer name, e.g. `moocha-orders.netlify.app`.

**If you edit `index.html` again later** (like pasting in real menu photos
or prices), you'll need to re-deploy: just drag the folder onto Netlify
again the same way, or drag it into the "Deploys" tab of your existing
site — it'll update the live link automatically.

## Part 4 — Try it for real

1. Open your live Netlify link on your phone.
2. Add a drink to cart, check out with a test name/phone, and scan the
   PayNow QR with your own banking app (see note on payments below).
3. Tap the small gear icon top-right → type `QUEENraks!` → you're in the
   staff dashboard. Change this passphrase immediately (Settings tab —
   see below) to something only you and your friends know.
4. Confirm your test order shows up under **Sales** and **Customers**.

## About payments (card + PayNow, via Stripe)

Checkout now hands off to Stripe, which offers both a card payment and
PayNow in the same screen — Stripe generates and verifies the PayNow QR
itself, so it's more reliable than a homemade one. See **Part 5** below to
set this up; until you do, the Checkout button stays disabled with a note.

## Part 5 — Stripe (accept card + PayNow payments for real)

This part is more technical than the others — it needs a small piece of
"backend" code (Supabase Edge Functions) because Stripe's secret key must
never be visible in your website's code, unlike the Supabase keys from
Part 1. Take it slowly, one command at a time, in your computer's
**Terminal** app (Mac) or **Command Prompt/PowerShell** (Windows).

### 5.1 — Create your Stripe account

1. Go to **[stripe.com](https://stripe.com)** and sign up.
2. You can build and fully test everything below in **test mode** (the
   default) before you ever enter real business/bank details. Switch to
   live mode later, when you're ready to take real money.
3. Go to **Developers → API keys**. Copy the **Secret key** (starts with
   `sk_test_...` in test mode). Keep this tab open.

### 5.2 — Install the tools (one-time)

1. Check if you already have Node.js: open Terminal and type `node -v`.
   If you see a version number, skip to step 2. If not, install it from
   [nodejs.org](https://nodejs.org) (download the "LTS" version, run the
   installer, then restart Terminal).
2. Install the Supabase CLI:
   - **Mac**: `brew install supabase/tap/supabase` (if you don't have
     Homebrew, install it first from [brew.sh](https://brew.sh))
   - **Windows**: `scoop install supabase` (if you don't have Scoop,
     install it first from [scoop.sh](https://scoop.sh))
3. In Terminal, navigate into your `moocha-site` folder, e.g.:
   `cd Downloads/moocha-site` (adjust the path to wherever you unzipped it)
4. Run `supabase login` — this opens a browser tab to connect your
   account.
5. Run `supabase link --project-ref YOUR_PROJECT_REF` — find your project
   ref in the Supabase dashboard URL: `supabase.com/dashboard/project/`**`this part`**.

### 5.3 — Set your secrets

Still in the same Terminal window, in the `moocha-site` folder:

```
supabase secrets set STRIPE_SECRET_KEY=sk_test_your_key_here
```

Then get your **service role key** (Supabase dashboard → Project Settings
→ API — it's the *other* key, below the anon key, marked secret) and run:

```
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

**This key is powerful and must never appear in `index.html` or anywhere
public** — it belongs only in this one command.

### 5.4 — Deploy the two functions

```
supabase functions deploy create-checkout-session
supabase functions deploy stripe-webhook
```

Each should finish with a green success message.

### 5.5 — Connect Stripe's webhook

1. In Stripe, go to **Developers → Webhooks → Add endpoint**.
2. Endpoint URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/stripe-webhook`
3. Select the event **checkout.session.completed**.
4. After creating it, click into the new webhook and copy its **Signing
   secret** (starts with `whsec_...`).
5. Back in Terminal: `supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_secret_here`

### 5.6 — Test it

1. Open your live Netlify site, add something to cart, checkout.
2. On Stripe's payment page, use a Stripe **test card**: card number
   `4242 4242 4242 4242`, any future expiry date, any 3-digit CVC.
3. You should land back on your site with a "Payment received" message,
   and the order should appear in your staff dashboard under Sales.
4. When ready to take real payments: in Stripe, complete your business
   verification, switch to live mode, and repeat steps 5.1–5.5 with your
   **live** keys (`sk_live_...`) instead of test ones.

## About payments

Checkout works right now without any payment processor set up: the customer
sees your PayNow number and taps "Place order" once they've paid, the same
way a small stall would handle a bank transfer normally. It's an honor
system for now — good enough to run on, but someone could tap that button
without actually paying. See **Part 5** below whenever you're ready for
real-time payment confirmation via Stripe (optional, not required to use
the app).

## Day to day (once it's live)

- **Add or edit drinks**: staff dashboard → Menu tab. Each drink has its own
  milk options and toppings — set them from that drink's ✎ edit screen,
  with whatever names and prices you like (no shared list to manage).
- **Add a thumbnail photo**: same edit screen — choose a JPEG or PNG from
  your computer and it uploads automatically.
- **Pause orders**: staff dashboard → Settings → toggle "Accepting orders"
  off. Customers can still browse the menu — only checkout gets blocked,
  with a friendly note.
- **Reorder drinks**: staff dashboard → Menu tab → ↑ / ↓ next to each drink.
- **Manage individual customers**: staff dashboard → Customers tab — edit
  anyone's stamp count directly, or remove a customer record entirely.
- **Delete an order**: staff dashboard → Orders tab → ✕ on that order.
- **Change your PayNow number or stall name**: same Settings tab.
- **Change the staff passphrase**: same Settings tab, under "Staff passphrase".

## About the staff passphrase

Your passphrase (`QUEENraks!` by default — please change it) is stored
hashed in the database, in a table your app can never directly read. When
you type it in, the database checks it behind the scenes and only replies
yes or no — the real passphrase never travels back to any phone or browser.
This closes the obvious hole a simpler setup would have. It isn't
*unhackable* (nothing public-facing ever truly is), but it's a solid,
realistic level of protection for a small stall.

## If something looks off

- Customer app showing old menu/settings: it refreshes automatically every
  ~8 seconds, or just reload the page.
- Staff dashboard looks empty: tap "↻ Refresh" in the top bar.
- Still see a "Demo mode" banner in Settings: double-check the URL/key in
  Part 2 were pasted correctly, with no extra spaces and the quote marks
  still in place.

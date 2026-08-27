-- Moocha — Supabase schema
-- Run this once in your Supabase project's SQL editor (SQL Editor > New query > Run).

-- needed for password hashing (crypt / gen_salt) — Supabase keeps this
-- in a separate "extensions" schema, so every call below is written as
-- extensions.crypt(...) / extensions.gen_salt(...) to find it reliably.
create extension if not exists pgcrypto with schema extensions;

create table if not exists settings (
  id text primary key default 'main',
  payment_enabled boolean not null default true,
  stall_phone text not null default '+6596586775',
  stall_name text not null default 'Moocha'
);
insert into settings (id) values ('main') on conflict (id) do nothing;

create table if not exists menu (
  id text primary key default 'main',
  data jsonb not null
);
insert into menu (id, data) values ('main', '{
  "categories": {
    "Matcha Drinks": [
      {"id":"m1","name":"Matcha Latte","desc":"Our everyday matcha, whisked with fresh milk.","price":6.00,"iced":true,"soldout":false,"icon":"matcha",
        "milks":[{"id":"milk1","name":"Fresh milk","price":0},{"id":"milk2","name":"Oat milk","price":0.80},{"id":"milk3","name":"Soy milk","price":0.60}],
        "toppings":[{"id":"top1","name":"Extra matcha shot","price":1.50},{"id":"top2","name":"Pearls","price":0.80}]},
      {"id":"m2","name":"Strawberry Matcha","desc":"Layered strawberry puree with ceremonial matcha.","price":7.00,"iced":true,"soldout":false,"icon":"strawberry",
        "milks":[{"id":"milk1","name":"Fresh milk","price":0},{"id":"milk2","name":"Oat milk","price":0.80}],
        "toppings":[{"id":"top1","name":"Extra matcha shot","price":1.50},{"id":"top2","name":"Pearls","price":0.80},{"id":"top3","name":"Grass jelly","price":0.80}]},
      {"id":"m3","name":"Sea Salt Foam Matcha","desc":"Matcha topped with a whisked sea salt cream foam.","price":7.00,"iced":true,"soldout":false,"photo":"assets/sea-salt-matcha.jpg",
        "milks":[{"id":"milk1","name":"Fresh milk","price":0},{"id":"milk3","name":"Soy milk","price":0.60}],
        "toppings":[{"id":"top1","name":"Extra matcha shot","price":1.50}]},
      {"id":"m4","name":"Biscoff Matcha","desc":"Matcha and biscoff caramel, swirled together.","price":7.50,"iced":true,"soldout":false,"photo":"assets/biscoff-matcha.jpg",
        "milks":[{"id":"milk1","name":"Fresh milk","price":0},{"id":"milk2","name":"Oat milk","price":0.80}],
        "toppings":[]}
    ],
    "Seasonal Bakes": []
  }
}'::jsonb) on conflict (id) do nothing;

-- Migrates an older flat menu (from before categories/milk/toppings existed
-- in their current form) into today's shape. Safe to run any time, even if
-- you're already fully up to date — each step only acts when needed.
do $$
declare
  old_data jsonb;
begin
  -- Step 1: an even older shape had categories directly at the root with
  -- no "categories" wrapper at all. Wrap it if that's what we find.
  select data into old_data from menu where id = 'main';
  if old_data is not null and not (old_data ? 'categories') then
    update menu set data = jsonb_build_object('categories', old_data) where id = 'main';
  end if;
end $$;

do $$
declare
  old_data jsonb;
  cat_key text;
  item jsonb;
  new_items jsonb;
  new_categories jsonb := '{}'::jsonb;
  milk_pool jsonb;
  addon_pool jsonb;
  new_milks jsonb;
  new_toppings jsonb;
begin
  -- Step 2: a middle shape kept a shared "milkOptions"/"addOns" pool at the
  -- root, with each item referencing them by id ("milkIds"/"addOnIds").
  -- Milk/toppings are now fully custom per drink, stored inline on the item
  -- itself — so fold each item's referenced pool entries directly into it.
  select data into old_data from menu where id = 'main';
  if old_data is not null and old_data ? 'milkOptions' then
    milk_pool := coalesce(old_data->'milkOptions', '[]'::jsonb);
    addon_pool := coalesce(old_data->'addOns', '[]'::jsonb);

    for cat_key in select jsonb_object_keys(old_data->'categories') loop
      new_items := '[]'::jsonb;
      for item in select * from jsonb_array_elements(old_data->'categories'->cat_key) loop
        if item ? 'milkIds' then
          select coalesce(jsonb_agg(jsonb_build_object('id', m->>'id', 'name', m->>'name', 'price', (m->>'price')::numeric)), '[]'::jsonb)
            into new_milks
            from jsonb_array_elements(milk_pool) m
            where (m->>'id') in (select jsonb_array_elements_text(item->'milkIds'));
        else
          select coalesce(jsonb_agg(jsonb_build_object('id', m->>'id', 'name', m->>'name', 'price', (m->>'price')::numeric)), '[]'::jsonb)
            into new_milks
            from jsonb_array_elements(milk_pool) m;
        end if;

        if item ? 'addOnIds' then
          select coalesce(jsonb_agg(jsonb_build_object('id', a->>'id', 'name', a->>'name', 'price', (a->>'price')::numeric)), '[]'::jsonb)
            into new_toppings
            from jsonb_array_elements(addon_pool) a
            where (a->>'id') in (select jsonb_array_elements_text(item->'addOnIds'));
        else
          select coalesce(jsonb_agg(jsonb_build_object('id', a->>'id', 'name', a->>'name', 'price', (a->>'price')::numeric)), '[]'::jsonb)
            into new_toppings
            from jsonb_array_elements(addon_pool) a;
        end if;

        item := (item - 'milkIds' - 'addOnIds') || jsonb_build_object('milks', new_milks, 'toppings', new_toppings);
        new_items := new_items || jsonb_build_array(item);
      end loop;
      new_categories := new_categories || jsonb_build_object(cat_key, new_items);
    end loop;

    update menu set data = jsonb_build_object('categories', new_categories) where id = 'main';
  end if;
end $$;

-- Storage bucket for drink thumbnail photos, uploaded from the staff Menu
-- editor. Public so the customer app can display them directly.
insert into storage.buckets (id, name, public)
values ('menu-photos', 'menu-photos', true)
on conflict (id) do nothing;

drop policy if exists "public read menu photos" on storage.objects;
create policy "public read menu photos" on storage.objects
  for select using (bucket_id = 'menu-photos');

drop policy if exists "public upload menu photos" on storage.objects;
create policy "public upload menu photos" on storage.objects
  for insert with check (bucket_id = 'menu-photos');

drop policy if exists "public replace menu photos" on storage.objects;
create policy "public replace menu photos" on storage.objects
  for update using (bucket_id = 'menu-photos');
-- Same trade-off as elsewhere in this file: anyone with your public anon
-- key could technically upload to this bucket too. Fine for a small stall;
-- real Supabase Auth would be the fix if that ever matters more.

create table if not exists orders (
  id text primary key,
  name text,
  phone text,
  date timestamptz default now(),
  items jsonb,
  total numeric,
  notes text,
  status text default 'Received',
  stripe_session_id text
);
alter table orders add column if not exists stripe_session_id text;

-- Loyalty stamps live here as a real, directly-editable number per phone —
-- not calculated from order count — so staff can adjust them by hand
-- (bonus stamps, corrections, walk-up cash sales entered manually, etc).
create table if not exists customers (
  phone text primary key,
  name text,
  stamps integer not null default 0,
  updated_at timestamptz default now()
);


-- ---------------------------------------------------------------
-- Staff passphrase: stored hashed, in its own table with NO public
-- read/write access at all. The app never receives the real
-- passphrase back — only true/false from the functions below.
-- ---------------------------------------------------------------
create table if not exists staff_auth (
  id text primary key default 'main',
  pin_hash text not null
);
insert into staff_auth (id, pin_hash)
  values ('main', extensions.crypt('QUEENraks!', extensions.gen_salt('bf')))
  on conflict (id) do nothing;

create or replace function check_staff_pin(candidate text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from staff_auth where id = 'main' and pin_hash = extensions.crypt(candidate, pin_hash)
  );
$$;

create or replace function set_staff_pin(old_pin text, new_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if exists (select 1 from staff_auth where id = 'main' and pin_hash = extensions.crypt(old_pin, pin_hash)) then
    update staff_auth set pin_hash = extensions.crypt(new_pin, extensions.gen_salt('bf')) where id = 'main';
    return true;
  else
    return false;
  end if;
end;
$$;

-- Row Level Security
alter table settings enable row level security;
alter table menu enable row level security;
alter table orders enable row level security;
alter table customers enable row level security;
alter table staff_auth enable row level security;
-- staff_auth intentionally gets NO policies below — that means nobody
-- (not even with the public anon key) can read or write it directly.
-- The two functions above can still reach it because they run as
-- "security definer", and only they are granted to the public below.

grant execute on function check_staff_pin(text) to anon;
grant execute on function set_staff_pin(text, text) to anon;

-- IMPORTANT: these policies are permissive (anyone with your public anon
-- key can read and write orders/menu/settings). That's a normal trade-off
-- for a small static-site project like this one — the part that actually
-- protects your staff dashboard (the passphrase) is locked down properly
-- above. If you ever want orders/menu locked down too, that needs real
-- Supabase Auth — ask me about it later if it matters to you.

drop policy if exists "public read settings" on settings;
create policy "public read settings" on settings for select using (true);
drop policy if exists "public update settings" on settings;
create policy "public update settings" on settings for update using (true);

drop policy if exists "public read menu" on menu;
create policy "public read menu" on menu for select using (true);
drop policy if exists "public update menu" on menu;
create policy "public update menu" on menu for update using (true);

drop policy if exists "public read orders" on orders;
create policy "public read orders" on orders for select using (true);
drop policy if exists "public insert orders" on orders;
create policy "public insert orders" on orders for insert with check (true);
drop policy if exists "public update orders" on orders;
create policy "public update orders" on orders for update using (true);
drop policy if exists "public delete orders" on orders;
create policy "public delete orders" on orders for delete using (true);

drop policy if exists "public read customers" on customers;
create policy "public read customers" on customers for select using (true);
drop policy if exists "public insert customers" on customers;
create policy "public insert customers" on customers for insert with check (true);
drop policy if exists "public update customers" on customers;
create policy "public update customers" on customers for update using (true);
drop policy if exists "public delete customers" on customers;
create policy "public delete customers" on customers for delete using (true);

-- kai-proxy backing tables (SEC-01).
-- Accessed only by the Edge Function via the service-role key, which bypasses RLS.
-- RLS is enabled with NO policies so nothing else (anon/authenticated) can read them.

create table if not exists attest_devices (
  key_id      text        primary key,
  public_key  bytea       not null,
  sign_count  bigint      not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists attest_challenges (
  challenge   text        primary key,
  created_at  timestamptz not null default now()
);

create table if not exists usage_counters (
  key_id       text  not null,
  day          date  not null,
  chat_count   int   not null default 0,
  vision_count int   not null default 0,
  primary key (key_id, day)
);

alter table attest_devices    enable row level security;
alter table attest_challenges enable row level security;
alter table usage_counters    enable row level security;

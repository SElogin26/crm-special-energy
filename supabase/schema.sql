-- Schema CRM Special Energy
-- Eseguire in Supabase: SQL Editor -> New query -> incolla -> Run

create extension if not exists pgcrypto;

-- Ruoli utente, collegati a auth.users di Supabase
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  ruolo text not null check (ruolo in ('agente','backoffice','manager','specialist','supervisor')),
  codice_agente text,
  nome text not null
);

-- Helper: ruolo dell'utente corrente
create or replace function current_ruolo() returns text
language sql stable security definer as $$
  select ruolo from profiles where id = auth.uid()
$$;

create table clienti (
  id uuid primary key default gen_random_uuid(),
  codice_cliente text,
  ragione_sociale text not null,
  piva_cf text,
  indirizzo text,
  telefono text,
  email text,
  stato text,
  agente_codice text,
  agente_nome text,
  agente_id uuid references profiles(id),
  created_at timestamptz default now()
);

-- Dati economici separati: il backoffice non deve vederli
create table clienti_economici (
  cliente_id uuid primary key references clienti(id) on delete cascade,
  ricorrente_mese numeric,
  provvigione numeric
);

create table note (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clienti(id) on delete cascade,
  testo text not null,
  letta boolean default false,
  created_at timestamptz default now()
);

create table richieste (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid references clienti(id) on delete cascade,
  path jsonb not null,
  stato text not null default 'inviata' check (stato in ('inviata','in_lavorazione','completata','respinta')),
  motivo text,
  docs jsonb default '[]',
  note_backoffice jsonb default '[]',
  created_at timestamptz default now()
);

-- RLS
alter table profiles enable row level security;
alter table clienti enable row level security;
alter table clienti_economici enable row level security;
alter table note enable row level security;
alter table richieste enable row level security;

-- profiles: ognuno legge/aggiorna solo il proprio; manager/supervisor leggono tutti
create policy "profiles self" on profiles for select using (id = auth.uid());
create policy "profiles self update" on profiles for update using (id = auth.uid());
create policy "profiles manager read all" on profiles for select using (current_ruolo() in ('manager','supervisor'));

-- clienti: tutti i ruoli autenticati leggono; agente scrive solo i propri, manager/backoffice/supervisor scrivono tutti
create policy "clienti read" on clienti for select using (auth.uid() is not null);
create policy "clienti write own" on clienti for all using (
  agente_id = auth.uid() or current_ruolo() in ('manager','backoffice','supervisor','specialist')
);

-- clienti_economici: SOLO agente/manager/supervisor/specialist, MAI backoffice
create policy "economici no backoffice" on clienti_economici for select using (
  current_ruolo() in ('agente','manager','supervisor','specialist')
);
create policy "economici write" on clienti_economici for all using (
  current_ruolo() in ('agente','manager','supervisor')
);

-- note: tutti leggono/scrivono (nessun dato economico qui)
create policy "note all" on note for all using (auth.uid() is not null);

-- richieste: tutti leggono/scrivono (il workflow agente<->backoffice passa da qui)
create policy "richieste all" on richieste for all using (auth.uid() is not null);

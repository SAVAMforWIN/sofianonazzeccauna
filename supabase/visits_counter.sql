-- ============================================================
-- Contatore visite REALE per sofianonazzeccauna.com
-- ------------------------------------------------------------
-- Da incollare UNA volta nell'editor SQL di Supabase
-- (progetto "czfzbprwuxrlezbxcutn" → SQL Editor → New query → Run).
--
-- Crea una tabella con il totale delle visite e due funzioni che il
-- sito chiama con la chiave PUBBLICA "anon" (la stessa del guestbook):
--   bump_visits() -> somma 1 e restituisce il nuovo totale
--   get_visits()  -> restituisce il totale senza toccarlo
--
-- La tabella resta blindata: il pubblico NON la legge/scrive a mano,
-- passa solo dalle due funzioni qui sotto. Stesso schema di sicurezza
-- usato per i voti del guestbook.
-- È sicuro rilanciare questo script più volte (è idempotente).
-- ============================================================

-- 1) Tabella contatore: una riga per "metrica", qui solo 'visits'.
create table if not exists public.site_stats (
  key   text   primary key,
  value bigint not null default 0
);

-- 2) Valore di partenza: 1337 per non perdere la gag "0001337" (leet).
--    Se la riga esiste già non viene toccata. Per partire da zero,
--    metti 0 al posto di 1337 PRIMA di lanciare lo script la prima volta.
insert into public.site_stats (key, value)
values ('visits', 1337)
on conflict (key) do nothing;

-- 3) Blindatura: niente accesso diretto alla tabella per il pubblico.
alter table public.site_stats enable row level security;
revoke all on table public.site_stats from anon, authenticated;
-- (RLS attiva e nessuna policy => i ruoli pubblici non leggono/scrivono la tabella)

-- 4) Incremento ATOMICO. SECURITY DEFINER: la funzione gira con i
--    permessi del proprietario, quindi può scrivere sulla tabella
--    blindata, ma fa una cosa sola (somma 1 e restituisce il totale).
--    L'ON CONFLICT con lock di riga rende sicure le visite simultanee.
create or replace function public.bump_visits()
returns bigint
language sql
security definer
set search_path = public
as $$
  insert into public.site_stats (key, value)
  values ('visits', 1)
  on conflict (key) do update set value = site_stats.value + 1
  returning value;
$$;

-- 5) Sola lettura del totale (per i ricaricamenti nella stessa sessione).
create or replace function public.get_visits()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select value from public.site_stats where key = 'visits'), 0);
$$;

-- 6) Permessi: il pubblico può solo ESEGUIRE queste due funzioni.
revoke all on function public.bump_visits() from public;
revoke all on function public.get_visits()  from public;
grant execute on function public.bump_visits() to anon, authenticated;
grant execute on function public.get_visits()  to anon, authenticated;

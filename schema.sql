-- CRM Monaco Detailing - Setup completo (tablas + índices + RLS + RPC)
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;
set search_path to public, extensions;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end$$;

create or replace function public.set_owner_user_id()
returns trigger language plpgsql security definer as $$
begin if new.user_id is null then new.user_id := auth.uid(); end if; return new; end$$;

create table if not exists public.personas (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text, dni text, telefono text, email text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
create table if not exists public.accesos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text, dni text, vehiculo text, dominio text, motivo text,
  f_ing date, h_ing time, f_sal date, h_sal time,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
create table if not exists public.paqueteria (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  receptor text, empresa text, remito text, estado text,
  fecha date, hora time, notas text,
  descripcion text, id_num text, entregado_a text,
  fecha_entrega date, hora_entrega time,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);

drop trigger if exists t_personas_updated on public.personas;
create trigger t_personas_updated before update on public.personas
for each row execute function public.set_updated_at();
drop trigger if exists t_accesos_updated on public.accesos;
create trigger t_accesos_updated before update on public.accesos
for each row execute function public.set_updated_at();
drop trigger if exists t_paqueteria_updated on public.paqueteria;
create trigger t_paqueteria_updated before update on public.paqueteria
for each row execute function public.set_updated_at();

drop trigger if exists t_personas_owner on public.personas;
create trigger t_personas_owner before insert on public.personas
for each row execute function public.set_owner_user_id();
drop trigger if exists t_accesos_owner on public.accesos;
create trigger t_accesos_owner before insert on public.accesos
for each row execute function public.set_owner_user_id();
drop trigger if exists t_paqueteria_owner on public.paqueteria;
create trigger t_paqueteria_owner before insert on public.paqueteria
for each row execute function public.set_owner_user_id();

create index if not exists idx_personas_nombre on public.personas (lower(nombre));
create index if not exists idx_personas_dni    on public.personas (dni);
create index if not exists idx_acc_vehiculo on public.accesos (lower(vehiculo));
create index if not exists idx_acc_dominio  on public.accesos (lower(dominio));
create index if not exists idx_acc_motivo   on public.accesos (lower(motivo));
create index if not exists idx_acc_nombre   on public.accesos (lower(nombre));
create index if not exists idx_acc_dni      on public.accesos (dni);
create index if not exists idx_paq_receptor on public.paqueteria (lower(receptor));
create index if not exists idx_paq_entrega  on public.paqueteria (lower(entregado_a));
create index if not exists idx_paq_desc     on public.paqueteria (lower(descripcion));
create index if not exists idx_paq_idnum    on public.paqueteria (lower(id_num));

alter table public.personas   enable row level security;
alter table public.accesos    enable row level security;
alter table public.paqueteria enable row level security;
drop policy if exists personas_owner_all   on public.personas;
drop policy if exists accesos_owner_all    on public.accesos;
drop policy if exists paqueteria_owner_all on public.paqueteria;
create policy personas_owner_all on public.personas
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy accesos_owner_all on public.accesos
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy paqueteria_owner_all on public.paqueteria
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.distinct_prefix(p_table text, p_column text, p_prefix text)
returns text[] language plpgsql stable as $$
declare sql text; res text[];
begin
  sql := format($f$
    select array_agg(val order by val) from (
      select distinct %1$I as val
      from %2$I
      where %1$I ilike %3$L
      order by %1$I
      limit 12
    ) t
  $f$, p_column, p_table, p_prefix || '%');
  execute sql into res;
  return coalesce(res, array[]::text[]);
end$$;

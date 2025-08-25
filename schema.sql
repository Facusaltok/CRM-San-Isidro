-- Extensiones
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ===== Tablas =====
create table if not exists public.personas (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text,
  dni text,
  telefono text,
  email text,
  created_at timestamp default now()
);

create table if not exists public.accesos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text,
  dni text,
  vehiculo text,
  dominio text,
  motivo text,
  f_ing date,
  h_ing time,
  f_sal date,
  h_sal time,
  created_at timestamp default now()
);

create table if not exists public.paqueteria (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  receptor text,
  empresa text,
  remito text,
  estado text,
  fecha date,
  hora time,
  notas text,
  created_at timestamp default now()
);

create table if not exists public.movimientos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  tipo text,                  -- Ingreso / Egreso
  concepto text,
  monto numeric(14,2),
  fecha date,
  url text,                   -- comprobante público
  created_at timestamp default now()
);

create table if not exists public.agenda_dom (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  cliente text,
  servicio text,
  segmento text,              -- Hatch/Sedán / SUV/PickUp / Motos
  fecha date,
  hora time,
  estado text,
  notas text,
  created_at timestamp default now()
);

create table if not exists public.parte_diario (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  fecha date,
  hora time,
  responsable text,
  detalle text,
  created_at timestamp default now()
);

-- ===== Índices =====
create index if not exists idx_personas_user on personas(user_id);
create index if not exists idx_accesos_user on accesos(user_id);
create index if not exists idx_paq_user on paqueteria(user_id);
create index if not exists idx_mov_user on movimientos(user_id);
create index if not exists idx_agenda_user on agenda_dom(user_id);
create index if not exists idx_parte_user on parte_diario(user_id);

-- ===== RLS =====
alter table personas     enable row level security;
alter table accesos      enable row level security;
alter table paqueteria   enable row level security;
alter table movimientos  enable row level security;
alter table agenda_dom   enable row level security;
alter table parte_diario enable row level security;

-- Políticas: cada usuario ve/gestiona sus filas
-- (Si querés que todos vean todo, cambiá USING por TRUE en SELECT)

-- personas
drop policy if exists p_personas_select on personas;
create policy p_personas_select on personas for select to authenticated using (user_id = auth.uid());

drop policy if exists p_personas_insert on personas;
create policy p_personas_insert on personas for insert to authenticated with check (user_id = auth.uid());

drop policy if exists p_personas_upd on personas;
create policy p_personas_upd on personas for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_personas_del on personas;
create policy p_personas_del on personas for delete to authenticated using (user_id = auth.uid());

-- accesos
drop policy if exists p_acc_select on accesos;
create policy p_acc_select on accesos for select to authenticated using (user_id = auth.uid());

drop policy if exists p_acc_insert on accesos;
create policy p_acc_insert on accesos for insert to authenticated with check (user_id = auth.uid());

drop policy if exists p_acc_upd on accesos;
create policy p_acc_upd on accesos for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_acc_del on accesos;
create policy p_acc_del on accesos for delete to authenticated using (user_id = auth.uid());

-- paqueteria
drop policy if exists p_paq_select on paqueteria;
create policy p_paq_select on paqueteria for select to authenticated using (user_id = auth.uid());

drop policy if exists p_paq_insert on paqueteria;
create policy p_paq_insert on paqueteria for insert to authenticated with check (user_id = auth.uid());

drop policy if exists p_paq_upd on paqueteria;
create policy p_paq_upd on paqueteria for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_paq_del on paqueteria;
create policy p_paq_del on paqueteria for delete to authenticated using (user_id = auth.uid());

-- movimientos (contable)
drop policy if exists p_mov_select on movimientos;
create policy p_mov_select on movimientos for select to authenticated using (user_id = auth.uid());

drop policy if exists p_mov_insert on movimientos;
create policy p_mov_insert on movimientos for insert to authenticated with check (user_id = auth.uid());

drop policy if exists p_mov_upd on movimientos;
create policy p_mov_upd on movimientos for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_mov_del on movimientos;
create policy p_mov_del on movimientos for delete to authenticated using (user_id = auth.uid());

-- agenda_dom
drop policy if exists p_age_select on agenda_dom;
create policy p_age_select on agenda_dom for select to authenticated using (user_id = auth.uid());

drop policy if exists p_age_insert on agenda_dom;
create policy p_age_insert on agenda_dom for insert to authenticated with check (user_id = auth.uid());

drop policy if exists p_age_upd on agenda_dom;
create policy p_age_upd on agenda_dom for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_age_del on agenda_dom;
create policy p_age_del on agenda_dom for delete to authenticated using (user_id = auth.uid());

-- parte_diario
drop policy if exists p_pd_select on parte_diario;
create policy p_pd_select on parte_diario for select to authenticated using (user_id = auth.uid());

drop policy if exists p_pd_insert on parte_diario;
create policy p_pd_insert on parte_diario for insert to authenticated with check (user_id = auth.uid());

drop policy if exists p_pd_upd on parte_diario;
create policy p_pd_upd on parte_diario for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_pd_del on parte_diario;
create policy p_pd_del on parte_diario for delete to authenticated using (user_id = auth.uid());

-- ===== Storage: bucket comprobantes =====
insert into storage.buckets (id, name, public) 
select 'tickets','tickets', true
where not exists (select 1 from storage.buckets where id='tickets');

-- Políticas Storage
drop policy if exists "tickets_public_read" on storage.objects;
create policy "tickets_public_read"
on storage.objects for select
to public
using ( bucket_id = 'tickets' );

drop policy if exists "tickets_user_write" on storage.objects;
create policy "tickets_user_write"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'tickets'
);

drop policy if exists "tickets_user_update" on storage.objects;
create policy "tickets_user_update"
on storage.objects for update
to authenticated
using ( bucket_id = 'tickets' );

drop policy if exists "tickets_user_delete" on storage.objects;
create policy "tickets_user_delete"
on storage.objects for delete
to authenticated
using ( bucket_id = 'tickets' );

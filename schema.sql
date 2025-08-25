-- =========================================================
-- CRM SAN ISIDRO — Esquema base + RLS + Storage (tickets)
-- Alineado al dashboard provisto (Accesos, Paquetería, Agenda, Contable)
-- Idempotente: se puede ejecutar varias veces
-- =========================================================

-- UUID helper
create extension if not exists pgcrypto;

-- =========================
-- 1) TABLAS PRINCIPALES
-- =========================

-- EMPLEADOS (para combos “Recibido por”, etc.)
create table if not exists public.empleados (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid unique,
  nombre     text not null,
  apellido   text not null,
  rol        text default 'empleado',
  created_at timestamptz default now()
);

-- PERSONAS (cache para autocompletar en Accesos)
create table if not exists public.personas (
  id              uuid primary key default gen_random_uuid(),
  nombre_apellido text not null,
  dni             text,
  vehiculo        text,
  dominio         text,
  ultima_visita   timestamptz default now(),
  created_at      timestamptz default now()
);

-- UNIQUE para permitir upsert onConflict('dni,dominio') desde el dashboard
-- (Postgres permite múltiples NULL en UNIQUE, está OK para nuestro uso)
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ux_personas_dni_dominio'
      and conrelid = 'public.personas'::regclass
  ) then
    alter table public.personas
      add constraint ux_personas_dni_dominio unique (dni, dominio);
  end if;
end $$;

-- ACCESOS
create table if not exists public.accesos (
  id              uuid primary key default gen_random_uuid(),
  nombre_apellido text not null,
  dni             text,
  vehiculo        text,
  dominio         text,
  motivo          text,
  fecha_ingreso   date,
  hora_ingreso    time,
  fecha_salida    date,
  hora_salida     time,
  registrado_por  uuid references public.empleados(id) on delete set null,
  created_at      timestamptz default now()
);
create index if not exists idx_accesos_fechas on public.accesos (fecha_ingreso, fecha_salida);

-- PAQUETERIA
create table if not exists public.paqueteria (
  id               uuid primary key default gen_random_uuid(),
  descripcion      text not null,
  fecha_recepcion  date not null,
  hora_recepcion   time not null,
  recibido_por     uuid references public.empleados(id) on delete set null,
  observaciones    text,
  entregado_a      text,
  fecha_entrega    date,
  hora_entrega     time,
  estado           text default 'recibido',
  created_at       timestamptz default now()
);
create index if not exists idx_paq_recepcion on public.paqueteria (fecha_recepcion);
create index if not exists idx_paq_entrega   on public.paqueteria (fecha_entrega);

-- AGENDA (solo Amalia / Valentino / Otros)
create table if not exists public.agenda_dom (
  id           uuid primary key default gen_random_uuid(),
  fecha        date not null,
  hora         time,
  destinatario text not null check (destinatario in ('Amalia','Valentino','Otros')),
  tarea        text not null,
  done         boolean default false,
  creado_por   uuid references public.empleados(id) on delete set null,
  created_at   timestamptz default now()
);
create index if not exists idx_agenda_fecha on public.agenda_dom (fecha);

-- MOVIMIENTOS (contable) + URL de ticket (imagen)
create table if not exists public.movimientos (
  id          uuid primary key default gen_random_uuid(),
  tipo        text not null check (tipo in ('gasto','ingreso')),
  fecha       date not null,
  importe     numeric not null,
  descripcion text,
  categoria   text,    -- "Caja Chica" | "Eventuales" | "Apertura" | etc.
  ticket_url  text,    -- URL pública al ticket (bucket `tickets`)
  empleado_id uuid references public.empleados(id) on delete set null,
  created_at  timestamptz default now()
);
create index if not exists idx_mov_fecha on public.movimientos (fecha);
create index if not exists idx_mov_tipo  on public.movimientos (tipo);

-- =========================
-- 2) RLS Y POLÍTICAS
-- =========================
alter table public.empleados   enable row level security;
alter table public.personas    enable row level security;
alter table public.accesos     enable row level security;
alter table public.paqueteria  enable row level security;
alter table public.agenda_dom  enable row level security;
alter table public.movimientos enable row level security;

-- Políticas abiertas para usuarios autenticados (como definiste en el front)

drop policy if exists "empleados all"   on public.empleados;
drop policy if exists "personas all"    on public.personas;
drop policy if exists "accesos all"     on public.accesos;
drop policy if exists "paqueteria all"  on public.paqueteria;
drop policy if exists "agenda all"      on public.agenda_dom;
drop policy if exists "movimientos all" on public.movimientos;

create policy "empleados all"   on public.empleados   for all to authenticated using (true) with check (true);
create policy "personas all"    on public.personas    for all to authenticated using (true) with check (true);
create policy "accesos all"     on public.accesos     for all to authenticated using (true) with check (true);
create policy "paqueteria all"  on public.paqueteria  for all to authenticated using (true) with check (true);
create policy "agenda all"      on public.agenda_dom  for all to authenticated using (true) with check (true);
create policy "movimientos all" on public.movimientos for all to authenticated using (true) with check (true);

-- =========================
-- 3) STORAGE (BUCKET: tickets)
-- =========================
-- ⚠️ Ejecutar esta sección con ROLE = postgres (o propietario de storage)

-- Crear bucket público (para que el enlace del ticket pueda abrirse)
insert into storage.buckets (id, name, public)
values ('tickets','tickets', true)
on conflict (id) do nothing;

-- Políticas de objetos del bucket
drop policy if exists "tickets read public" on storage.objects;
drop policy if exists "tickets insert auth" on storage.objects;
drop policy if exists "tickets update own"  on storage.objects;
drop policy if exists "tickets delete own"  on storage.objects;

-- Lectura de metadatos (cualquiera). El archivo ya es público por el bucket.
create policy "tickets read public"
  on storage.objects
  for select to public
  using ( bucket_id = 'tickets' );

-- Inserción por usuarios autenticados (propietario = auth.uid())
create policy "tickets insert auth"
  on storage.objects
  for insert to authenticated
  with check ( bucket_id = 'tickets' and owner = auth.uid() );

-- Update/Delete solo del dueño
create policy "tickets update own"
  on storage.objects
  for update to authenticated
  using ( bucket_id = 'tickets' and owner = auth.uid() )
  with check ( bucket_id = 'tickets' and owner = auth.uid() );

create policy "tickets delete own"
  on storage.objects
  for delete to authenticated
  using ( bucket_id = 'tickets' and owner = auth.uid() );

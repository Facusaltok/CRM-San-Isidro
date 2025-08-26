-- =========================
-- CRM San Isidro – Esquema completo (idempotente)
-- =========================

-- Extensiones necesarias
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- Helper: updated_at automático
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end$$;

-- Helper: verificación de propietario (RLS)
create or replace function public.is_owner(uid uuid)
returns boolean language sql stable as $$
  select uid = auth.uid()
$$;

-- =============== TABLAS ===============

-- Personas (genérica, por si la usás más adelante)
create table if not exists public.personas (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre     text,
  dni        text,
  telefono   text,
  email      text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_personas_updated on public.personas;
create trigger t_personas_updated before update on public.personas
for each row execute function public.set_updated_at();

-- Accesos (registro de ingresos/egresos)
create table if not exists public.accesos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre   text,
  dni      text,
  vehiculo text,
  dominio  text,
  motivo   text,
  f_ing    date,
  h_ing    time,
  f_sal    date,
  h_sal    time,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_accesos_updated on public.accesos;
create trigger t_accesos_updated before update on public.accesos
for each row execute function public.set_updated_at();

-- Paquetería
create table if not exists public.paqueteria (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  receptor text,
  empresa  text,
  remito   text,
  estado   text,
  fecha    date,
  hora     time,
  notas    text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
-- columnas nuevas (idempotente)
alter table public.paqueteria
  add column if not exists entregado_a   text,
  add column if not exists fecha_entrega date,
  add column if not exists hora_entrega  time;

drop trigger if exists t_paqueteria_updated on public.paqueteria;
create trigger t_paqueteria_updated before update on public.paqueteria
for each row execute function public.set_updated_at();

-- Contable (movimientos)
create table if not exists public.movimientos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  tipo     text,               -- 'Ingreso' | 'Egreso'
  concepto text,
  monto    numeric(14,2),
  fecha    date,
  url      text,               -- link público al comprobante (Storage)
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_movimientos_updated on public.movimientos;
create trigger t_movimientos_updated before update on public.movimientos
for each row execute function public.set_updated_at();

-- Agenda simplificada (un solo campo 'tarea')
create table if not exists public.agenda_dom (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  asignado_a text check (asignado_a in ('Amalia','Valentino','Otros')) default 'Otros',
  fecha    date,
  hora     time,
  estado   text,
  notas    text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
-- columna requerida por el frontend
alter table public.agenda_dom
  add column if not exists tarea text;

drop trigger if exists t_agenda_dom_updated on public.agenda_dom;
create trigger t_agenda_dom_updated before update on public.agenda_dom
for each row execute function public.set_updated_at();

-- Parte diario
create table if not exists public.parte_diario (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  fecha date not null default current_date,
  hora_inicio time,
  hora_fin    time,
  caja_chica  numeric(14,2),
  cabina text,
  amt text,
  puesto_hudson text,
  choferes text[],
  novedades_vehiculos jsonb,
  familia_en_quinta   jsonb,
  personal_domestico  jsonb,
  sistemas_tecnicos   jsonb,
  invitados           jsonb,
  profesionales       jsonb,
  elementos_asignados text[],
  otros         text,
  agenda_texto  text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_parte_diario_updated on public.parte_diario;
create trigger t_parte_diario_updated before update on public.parte_diario
for each row execute function public.set_updated_at();

-- =============== ÍNDICES ===============
create index if not exists idx_personas_user   on public.personas(user_id);
create index if not exists idx_accesos_user    on public.accesos(user_id);
create index if not exists idx_paq_user        on public.paqueteria(user_id);
create index if not exists idx_mov_user        on public.movimientos(user_id);
create index if not exists idx_agenda_user     on public.agenda_dom(user_id);
create index if not exists idx_parte_user      on public.parte_diario(user_id);

create index if not exists idx_acc_fechas      on public.accesos(f_ing, f_sal);
create index if not exists idx_paq_fecha       on public.paqueteria(fecha);
create index if not exists idx_mov_fecha       on public.movimientos(fecha);
create index if not exists idx_agenda_fecha    on public.agenda_dom(fecha);
create index if not exists idx_pd_fecha        on public.parte_diario(fecha);

-- =============== RLS (Row Level Security) ===============
alter table public.personas     enable row level security;
alter table public.accesos      enable row level security;
alter table public.paqueteria   enable row level security;
alter table public.movimientos  enable row level security;
alter table public.agenda_dom   enable row level security;
alter table public.parte_diario enable row level security;

-- Personas
drop policy if exists sel_personas on public.personas;
create policy sel_personas on public.personas for select to authenticated using (is_owner(user_id));
drop policy if exists ins_personas on public.personas;
create policy ins_personas on public.personas for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_personas on public.personas;
create policy upd_personas on public.personas for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_personas on public.personas;
create policy del_personas on public.personas for delete to authenticated using (is_owner(user_id));

-- Accesos
drop policy if exists sel_accesos on public.accesos;
create policy sel_accesos on public.accesos for select to authenticated using (is_owner(user_id));
drop policy if exists ins_accesos on public.accesos;
create policy ins_accesos on public.accesos for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_accesos on public.accesos;
create policy upd_accesos on public.accesos for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_accesos on public.accesos;
create policy del_accesos on public.accesos for delete to authenticated using (is_owner(user_id));

-- Paquetería
drop policy if exists sel_paqueteria on public.paqueteria;
create policy sel_paqueteria on public.paqueteria for select to authenticated using (is_owner(user_id));
drop policy if exists ins_paqueteria on public.paqueteria;
create policy ins_paqueteria on public.paqueteria for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_paqueteria on public.paqueteria;
create policy upd_paqueteria on public.paqueteria for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_paqueteria on public.paqueteria;
create policy del_paqueteria on public.paqueteria for delete to authenticated using (is_owner(user_id));

-- Movimientos
drop policy if exists sel_movimientos on public.movimientos;
create policy sel_movimientos on public.movimientos for select to authenticated using (is_owner(user_id));
drop policy if exists ins_movimientos on public.movimientos;
create policy ins_movimientos on public.movimientos for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_movimientos on public.movimientos;
create policy upd_movimientos on public.movimientos for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_movimientos on public.movimientos;
create policy del_movimientos on public.movimientos for delete to authenticated using (is_owner(user_id));

-- Agenda
drop policy if exists sel_agenda_dom on public.agenda_dom;
create policy sel_agenda_dom on public.agenda_dom for select to authenticated using (is_owner(user_id));
drop policy if exists ins_agenda_dom on public.agenda_dom;
create policy ins_agenda_dom on public.agenda_dom for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_agenda_dom on public.agenda_dom;
create policy upd_agenda_dom on public.agenda_dom for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_agenda_dom on public.agenda_dom;
create policy del_agenda_dom on public.agenda_dom for delete to authenticated using (is_owner(user_id));

-- Parte diario
drop policy if exists sel_parte_diario on public.parte_diario;
create policy sel_parte_diario on public.parte_diario for select to authenticated using (is_owner(user_id));
drop policy if exists ins_parte_diario on public.parte_diario;
create policy ins_parte_diario on public.parte_diario for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_parte_diario on public.parte_diario;
create policy upd_parte_diario on public.parte_diario for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_parte_diario on public.parte_diario;
create policy del_parte_diario on public.parte_diario for delete to authenticated using (is_owner(user_id));

-- =============== FUNCIÓN + VISTA (Mensaje WhatsApp) ===============
drop view if exists public.parte_diario_whatsapp;
drop function if exists public.fn_parte_diario_mensaje(uuid);

create or replace function public.fn_parte_diario_mensaje(p_id uuid)
returns text
language plpgsql
as $$
declare
  r   record;
  msg text := '';
begin
  select * into r from public.parte_diario where id = p_id;
  if not found then return null; end if;

  msg := 'SERVICIO '||coalesce(to_char(r.fecha,'DD/MM/YYYY'),'')||E'\n'||
         coalesce(to_char(r.hora_inicio,'HH24:MI'),'')||' a '||coalesce(to_char(r.hora_fin,'HH24:MI'),'')||E'\n\n';

  if r.cabina is not null        then msg := msg||'CABINA:'||E'\n'||r.cabina||E'\n\n'; end if;
  if r.amt is not null           then msg := msg||'AMT:'||E'\n'||r.amt||E'\n\n'; end if;
  if r.puesto_hudson is not null then msg := msg||'PUESTO HUDSON:'||E'\n'||r.puesto_hudson||E'\n\n'; end if;

  if r.caja_chica is not null    then msg := msg||'*CAJA CHICA: $ '||trim(to_char(r.caja_chica,'999G999G990D00'))||'.-*'||E'\n\n'; end if;
  if r.choferes is not null      then msg := msg||'CHOFERES:'||E'\n- '||array_to_string(r.choferes, E'\n- ')||E'\n\n'; end if;

  if r.novedades_vehiculos is not null then
    msg := msg || 'NOVEDADES DE VEHICULOS'||E'\n'|| r.novedades_vehiculos::text || E'\n\n';
  end if;
  if r.familia_en_quinta is not null then
    msg := msg || 'INTEGRANTES DE LA FAMILIA EN LA QUINTA'||E'\n'|| r.familia_en_quinta::text || E'\n\n';
  end if;
  if r.personal_domestico is not null then
    msg := msg || 'EMPLEADAS / NIÑERA'||E'\n'|| r.personal_domestico::text || E'\n\n';
  end if;
  if r.sistemas_tecnicos is not null then
    msg := msg || 'SISTEMA DE CAMARAS / CERCO / PORTONES'||E'\n'|| r.sistemas_tecnicos::text || E'\n\n';
  end if;
  if r.profesionales is not null then
    msg := msg || 'PROFESIONALES'||E'\n'|| r.profesionales::text || E'\n\n';
  end if;
  if r.invitados is not null then
    msg := msg || 'AMIGOS / INVITADOS'||E'\n'|| r.invitados::text || E'\n\n';
  end if;
  if r.elementos_asignados is not null then
    msg := msg || 'ELEMENTOS ASIGNADOS:'||E'\n- '||array_to_string(r.elementos_asignados, E'\n- ')||E'\n\n';
  end if;
  if r.otros is not null then
    msg := msg || 'OTROS:'||E'\n'|| r.otros || E'\n\n';
  end if;
  if r.agenda_texto is not null then
    msg := msg || 'AGENDA:'||E'\n'|| r.agenda_texto || E'\n';
  end if;

  return msg;
end
$$;

create or replace view public.parte_diario_whatsapp as
select id, user_id, fecha, hora_inicio, hora_fin,
       fn_parte_diario_mensaje(id) as mensaje
from public.parte_diario;

alter view public.parte_diario_whatsapp owner to postgres;

-- =============== REFRESCAR ESQUEMA API ===============
notify pgrst, 'reload schema';

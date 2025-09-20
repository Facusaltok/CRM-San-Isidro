-- ===== Extensiones =====
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- updated_at automático
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end$$;

-- RLS helper
create or replace function public.is_owner(uid uuid)
returns boolean language sql stable as $$ select uid = auth.uid() $$;

-- ===== Tablas =====
create table if not exists public.personas (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text, dni text, telefono text, email text,
  created_at timestamp not null default now(), updated_at timestamp not null default now()
);
drop trigger if exists t_personas_updated on public.personas;
create trigger t_personas_updated before update on public.personas for each row execute function public.set_updated_at();

create table if not exists public.accesos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text, dni text, vehiculo text, dominio text, motivo text,
  f_ing date, h_ing time, f_sal date, h_sal time,
  created_at timestamp not null default now(), updated_at timestamp not null default now()
);
drop trigger if exists t_accesos_updated on public.accesos;
create trigger t_accesos_updated before update on public.accesos for each row execute function public.set_updated_at();

create table if not exists public.paqueteria (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  receptor text,
  empresa  text,      -- legacy
  remito   text,      -- legacy
  estado   text,
  fecha    date, hora time,
  notas    text,
  -- nuevos
  descripcion  text,
  id_num       text,
  entregado_a  text,
  fecha_entrega date,
  hora_entrega  time,
  created_at timestamp not null default now(), updated_at timestamp not null default now()
);

-- Migración a columnas nuevas (aseguramos que existan ANTES de actualizar)
alter table public.paqueteria
  add column if not exists descripcion text,
  add column if not exists id_num text,
  add column if not exists entregado_a text,
  add column if not exists fecha_entrega date,
  add column if not exists hora_entrega time;

update public.paqueteria
set descripcion = empresa
where descripcion is null
  and empresa is not null;

update public.paqueteria
set id_num = remito
where id_num is null
  and remito is not null;

drop trigger if exists t_paqueteria_updated on public.paqueteria;
create trigger t_paqueteria_updated before update on public.paqueteria for each row execute function public.set_updated_at();

create table if not exists public.movimientos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  tipo text, concepto text, monto numeric(14,2), fecha date,
  url text,
  created_at timestamp not null default now(), updated_at timestamp not null default now()
);
drop trigger if exists t_movimientos_updated on public.movimientos;
create trigger t_movimientos_updated before update on public.movimientos for each row execute function public.set_updated_at();

create table if not exists public.agenda_dom (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  asignado_a text check (asignado_a in ('Amalia','Valentino','Otros')) default 'Otros',
  tarea text,
  fecha date, hora time, estado text, notas text,
  created_at timestamp not null default now(), updated_at timestamp not null default now()
);
drop trigger if exists t_agenda_dom_updated on public.agenda_dom;
create trigger t_agenda_dom_updated before update on public.agenda_dom for each row execute function public.set_updated_at();

create table if not exists public.parte_diario (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  fecha date not null default current_date,
  hora_inicio time, hora_fin time, caja_chica numeric(14,2),
  cabina text, amt text, puesto_hudson text,
  choferes text[],
  novedades_vehiculos jsonb,
  familia_en_quinta   jsonb,
  personal_domestico  jsonb,
  sistemas_tecnicos   jsonb,
  invitados           jsonb,
  profesionales       jsonb,
  elementos_asignados text[],
  otros text,
  agenda_texto text,
  created_at timestamp not null default now(), updated_at timestamp not null default now()
);
drop trigger if exists t_parte_diario_updated on public.parte_diario;
create trigger t_parte_diario_updated before update on public.parte_diario for each row execute function public.set_updated_at();

-- ===== Índices =====
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

-- ===== RLS =====
alter table public.personas     enable row level security;
alter table public.accesos      enable row level security;
alter table public.paqueteria   enable row level security;
alter table public.movimientos  enable row level security;
alter table public.agenda_dom   enable row level security;
alter table public.parte_diario enable row level security;

drop policy if exists sel_personas on public.personas;
create policy sel_personas on public.personas for select to authenticated using (is_owner(user_id));
drop policy if exists ins_personas on public.personas;
create policy ins_personas on public.personas for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_personas on public.personas;
create policy upd_personas on public.personas for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_personas on public.personas;
create policy del_personas on public.personas for delete to authenticated using (is_owner(user_id));

drop policy if exists sel_accesos on public.accesos;
create policy sel_accesos on public.accesos for select to authenticated using (is_owner(user_id));
drop policy if exists ins_accesos on public.accesos;
create policy ins_accesos on public.accesos for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_accesos on public.accesos;
create policy upd_accesos on public.accesos for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_accesos on public.accesos;
create policy del_accesos on public.accesos for delete to authenticated using (is_owner(user_id));

drop policy if exists sel_paqueteria on public.paqueteria;
create policy sel_paqueteria on public.paqueteria for select to authenticated using (is_owner(user_id));
drop policy if exists ins_paqueteria on public.paqueteria;
create policy ins_paqueteria on public.paqueteria for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_paqueteria on public.paqueteria;
create policy upd_paqueteria on public.paqueteria for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_paqueteria on public.paqueteria;
create policy del_paqueteria on public.paqueteria for delete to authenticated using (is_owner(user_id));

drop policy if exists sel_movimientos on public.movimientos;
create policy sel_movimientos on public.movimientos for select to authenticated using (is_owner(user_id));
drop policy if exists ins_movimientos on public.movimientos;
create policy ins_movimientos on public.movimientos for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_movimientos on public.movimientos;
create policy upd_movimientos on public.movimientos for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_movimientos on public.movimientos;
create policy del_movimientos on public.movimientos for delete to authenticated using (is_owner(user_id));

drop policy if exists sel_agenda_dom on public.agenda_dom;
create policy sel_agenda_dom on public.agenda_dom for select to authenticated using (is_owner(user_id));
drop policy if exists ins_agenda_dom on public.agenda_dom;
create policy ins_agenda_dom on public.agenda_dom for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_agenda_dom on public.agenda_dom;
create policy upd_agenda_dom on public.agenda_dom for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_agenda_dom on public.agenda_dom;
create policy del_agenda_dom on public.agenda_dom for delete to authenticated using (is_owner(user_id));

drop policy if exists sel_parte_diario on public.parte_diario;
create policy sel_parte_diario on public.parte_diario for select to authenticated using (is_owner(user_id));
drop policy if exists ins_parte_diario on public.parte_diario;
create policy ins_parte_diario on public.parte_diario for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_parte_diario on public.parte_diario;
create policy upd_parte_diario on public.parte_diario for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_parte_diario on public.parte_diario;
create policy del_parte_diario on public.parte_diario for delete to authenticated using (is_owner(user_id));

-- ===== WhatsApp: función + vista =====
drop view if exists public.parte_diario_whatsapp;
drop function if exists public.fn_parte_diario_mensaje(uuid);

create or replace function public.fn_parte_diario_mensaje(p_id uuid)
returns text language plpgsql as $$
declare r record; msg text := '';
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

  if r.novedades_vehiculos is not null then msg := msg || 'NOVEDADES DE VEHICULOS'||E'\n'|| r.novedades_vehiculos::text || E'\n\n'; end if;
  if r.familia_en_quinta is not null then msg := msg || 'INTEGRANTES DE LA FAMILIA EN LA QUINTA'||E'\n'|| r.familia_en_quinta::text || E'\n\n'; end if;
  if r.personal_domestico is not null then msg := msg || 'EMPLEADAS / NIÑERA'||E'\n'|| r.personal_domestico::text || E'\n\n'; end if;
  if r.sistemas_tecnicos is not null then msg := msg || 'SISTEMA DE CAMARAS / CERCO / PORTONES'||E'\n'|| r.sistemas_tecnicos::text || E'\n\n'; end if;
  if r.profesionales is not null then msg := msg || 'PROFESIONALES'||E'\n'|| r.profesionales::text || E'\n\n'; end if;
  if r.invitados is not null then msg := msg || 'AMIGOS / INVITADOS'||E'\n'|| r.invitados::text || E'\n\n'; end if;
  if r.elementos_asignados is not null then msg := msg || 'ELEMENTOS ASIGNADOS:'||E'\n- '||array_to_string(r.elementos_asignados, E'\n- ')||E'\n\n'; end if;
  if r.otros is not null then msg := msg || 'OTROS:'||E'\n'|| r.otros || E'\n\n'; end if;
  if r.agenda_texto is not null then msg := msg || 'AGENDA:'||E'\n'|| r.agenda_texto || E'\n'; end if;

  return msg;
end$$;

create or replace view public.parte_diario_whatsapp as
select id, user_id, fecha, hora_inicio, hora_fin, fn_parte_diario_mensaje(id) as mensaje
from public.parte_diario;

alter view public.parte_diario_whatsapp owner to postgres;

-- ===== Refrescar esquema =====
notify pgrst, 'reload schema';

-- ========= DUEÑO AUTOMÁTICO EN INSERTS =========
create or replace function public.set_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is null then
    new.user_id := auth.uid();
  end if;
  return new;
end;
$$;

-- Aplico el trigger a todas las tablas de datos
drop trigger if exists t_personas_owner on public.personas;
create trigger t_personas_owner before insert on public.personas
for each row execute function public.set_owner();

drop trigger if exists t_accesos_owner on public.accesos;
create trigger t_accesos_owner before insert on public.accesos
for each row execute function public.set_owner();

drop trigger if exists t_paqueteria_owner on public.paqueteria;
create trigger t_paqueteria_owner before insert on public.paqueteria
for each row execute function public.set_owner();

drop trigger if exists t_movimientos_owner on public.movimientos;
create trigger t_movimientos_owner before insert on public.movimientos
for each row execute function public.set_owner();

drop trigger if exists t_agenda_dom_owner on public.agenda_dom;
create trigger t_agenda_dom_owner before insert on public.agenda_dom
for each row execute function public.set_owner();

drop trigger if exists t_parte_diario_owner on public.parte_diario;
create trigger t_parte_diario_owner before insert on public.parte_diario
for each row execute function public.set_owner();

-- ========= RPC para "reclamar" filas históricas sin user_id =========
drop function if exists public.claim_orphan_rows cascade;
create or replace function public.claim_orphan_rows()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  -- Evita usar si no hay sesión
  if uid is null then
    raise exception 'No authenticated user';
  end if;

  update public.personas     set user_id = uid where user_id is null;
  update public.accesos      set user_id = uid where user_id is null;
  update public.paqueteria   set user_id = uid where user_id is null;
  update public.movimientos  set user_id = uid where user_id is null;
  update public.agenda_dom   set user_id = uid where user_id is null;
  update public.parte_diario set user_id = uid where user_id is null;
end;
$$;

revoke all on function public.claim_orphan_rows() from public;
grant execute on function public.claim_orphan_rows() to authenticated;

-- ========= Helpers de Personas para Accesos =========
-- Upsert rápido de persona (opcional cuando guardás desde el modal de Accesos)
drop function if exists public.upsert_persona(text,text,text,text);
create or replace function public.upsert_persona(p_nombre text, p_dni text, p_telefono text, p_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  pid uuid;
begin
  if uid is null then
    raise exception 'No authenticated user';
  end if;

  select id into pid
  from public.personas
  where user_id = uid
    and ( (p_dni is not null and dni = p_dni) or (p_nombre is not null and nombre = p_nombre) )
  limit 1;

  if pid is null then
    insert into public.personas(user_id, nombre, dni, telefono, email)
    values (uid, p_nombre, p_dni, p_telefono, p_email)
    returning id into pid;
  else
    update public.personas
       set nombre   = coalesce(p_nombre, nombre),
           dni      = coalesce(p_dni, dni),
           telefono = coalesce(p_telefono, telefono),
           email    = coalesce(p_email, email)
     where id = pid;
  end if;

  return pid;
end;
$$;

grant execute on function public.upsert_persona(text,text,text,text) to authenticated;

-- ========= Vista auxiliar para horas (por si querés chequear desde SQL) =========
drop view if exists public.accesos_horas;
create or replace view public.accesos_horas as
select
  id,
  user_id,
  nombre,
  dni,
  f_ing, h_ing, f_sal, h_sal,
  -- duración en horas (decimal) si hay ingreso y salida
  case
    when f_ing is not null and h_ing is not null and f_sal is not null and h_sal is not null
      then extract(epoch from ((f_sal + h_sal) - (f_ing + h_ing))) / 3600.0
    else null
  end as horas
from public.accesos;

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

create index if not exists idx_personas_nombre on public.personas (lower(nombre));
create index if not exists idx_personas_dni on public.personas (dni);
create index if not exists idx_acc_vehiculo on public.accesos (lower(vehiculo));
create index if not exists idx_acc_dominio on public.accesos (lower(dominio));
create index if not exists idx_acc_motivo on public.accesos (lower(motivo));

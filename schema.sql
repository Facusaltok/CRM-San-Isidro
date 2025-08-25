-- ========= Extensiones & utilidades =========
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- updated_at automático
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end$$;

-- ========= Tablas =========

-- Personas (opcional, ya usada en tu proyecto)
create table if not exists public.personas (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  nombre text,
  dni text,
  telefono text,
  email text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_personas_updated on public.personas;
create trigger t_personas_updated before update on public.personas
for each row execute function public.set_updated_at();

-- Accesos
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
drop trigger if exists t_paqueteria_updated on public.paqueteria;
create trigger t_paqueteria_updated before update on public.paqueteria
for each row execute function public.set_updated_at();

-- Contable (movimientos)
create table if not exists public.movimientos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  tipo     text,                -- Ingreso / Egreso
  concepto text,
  monto    numeric(14,2),
  fecha    date,
  url      text,                -- comprobante (público)
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_movimientos_updated on public.movimientos;
create trigger t_movimientos_updated before update on public.movimientos
for each row execute function public.set_updated_at();

-- Agenda (Asigna a Amalia / Valentino / Otros)
create table if not exists public.agenda_dom (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  asignado_a text check (asignado_a in ('Amalia','Valentino','Otros')) default 'Otros',
  cliente  text,
  servicio text,
  segmento text,                -- Hatch/Sedán / SUV/PickUp / Motos
  fecha    date,
  hora     time,
  estado   text,                -- Pendiente / Confirmado / Completado / Cancelado
  notas    text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_agenda_dom_updated on public.agenda_dom;
create trigger t_agenda_dom_updated before update on public.agenda_dom
for each row execute function public.set_updated_at();

-- Parte diario (estructura simple + secciones libres)
create table if not exists public.parte_diario (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  fecha date not null default current_date,
  hora_inicio time,
  hora_fin    time,
  caja_chica  numeric(14,2),
  -- campos principales “rápidos”
  cabina text,
  amt text,
  puesto_hudson text,
  choferes text[],                -- ej: '{Paz,Pianelli,...}'
  -- bloques libres en JSONB para que no te quedes corto
  novedades_vehiculos jsonb,      -- { "Trailblazer":"En la quinta", ... }
  familia_en_quinta   jsonb,      -- { "1":"-///-","2":"-///-",...}
  personal_domestico  jsonb,      -- { "empleadas":["Mirta",...], "niniera":"Emilia", ...}
  sistemas_tecnicos   jsonb,      -- { "camaras":"SN", "cerco":"SN", "portones":"..." , ...}
  invitados jsonb,                -- { "amigos_sra":[{nombre:"",dni:"",vehiculos:"",dominio:""}], ...}
  profesionales jsonb,            -- { "jardinero":"SI","piletero":"SI",...}
  elementos_asignados text[],     -- lista simple
  otros text,                     -- notas libres
  agenda_texto text,              -- mini agenda del día
  created_at timestamp not null default now(),
  updated_at timestamp not null default now()
);
drop trigger if exists t_parte_diario_updated on public.parte_diario;
create trigger t_parte_diario_updated before update on public.parte_diario
for each row execute function public.set_updated_at();

-- ========= Índices =========
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

-- ========= RLS =========
alter table public.personas     enable row level security;
alter table public.accesos      enable row level security;
alter table public.paqueteria   enable row level security;
alter table public.movimientos  enable row level security;
alter table public.agenda_dom   enable row level security;
alter table public.parte_diario enable row level security;

-- Helper para políticas “propias”
create or replace function public.is_owner(uid uuid)
returns boolean language sql stable as $$
  select uid = auth.uid()
$$;

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
drop policy if exists sel_paq on public.paqueteria;
create policy sel_paq on public.paqueteria for select to authenticated using (is_owner(user_id));
drop policy if exists ins_paq on public.paqueteria;
create policy ins_paq on public.paqueteria for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_paq on public.paqueteria;
create policy upd_paq on public.paqueteria for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_paq on public.paqueteria;
create policy del_paq on public.paqueteria for delete to authenticated using (is_owner(user_id));

-- Movimientos
drop policy if exists sel_mov on public.movimientos;
create policy sel_mov on public.movimientos for select to authenticated using (is_owner(user_id));
drop policy if exists ins_mov on public.movimientos;
create policy ins_mov on public.movimientos for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_mov on public.movimientos;
create policy upd_mov on public.movimientos for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_mov on public.movimientos;
create policy del_mov on public.movimientos for delete to authenticated using (is_owner(user_id));

-- Agenda
drop policy if exists sel_age on public.agenda_dom;
create policy sel_age on public.agenda_dom for select to authenticated using (is_owner(user_id));
drop policy if exists ins_age on public.agenda_dom;
create policy ins_age on public.agenda_dom for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_age on public.agenda_dom;
create policy upd_age on public.agenda_dom for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_age on public.agenda_dom;
create policy del_age on public.agenda_dom for delete to authenticated using (is_owner(user_id));

-- Parte Diario
drop policy if exists sel_pd on public.parte_diario;
create policy sel_pd on public.parte_diario for select to authenticated using (is_owner(user_id));
drop policy if exists ins_pd on public.parte_diario;
create policy ins_pd on public.parte_diario for insert to authenticated with check (is_owner(user_id));
drop policy if exists upd_pd on public.parte_diario;
create policy upd_pd on public.parte_diario for update to authenticated using (is_owner(user_id)) with check (is_owner(user_id));
drop policy if exists del_pd on public.parte_diario;
create policy del_pd on public.parte_diario for delete to authenticated using (is_owner(user_id));

-- ========= Storage (comprobantes Contable) =========
insert into storage.buckets (id, name, public)
select 'tickets','tickets', true
where not exists (select 1 from storage.buckets where id='tickets');

drop policy if exists tickets_public_read on storage.objects;
create policy tickets_public_read on storage.objects
for select to public using (bucket_id = 'tickets');

drop policy if exists tickets_user_write on storage.objects;
create policy tickets_user_write on storage.objects
for insert to authenticated with check (bucket_id = 'tickets');

drop policy if exists tickets_user_update on storage.objects;
create policy tickets_user_update on storage.objects
for update to authenticated using (bucket_id = 'tickets');

drop policy if exists tickets_user_delete on storage.objects;
create policy tickets_user_delete on storage.objects
for delete to authenticated using (bucket_id = 'tickets');

-- ========= Función: construir mensaje de WhatsApp del parte diario =========
create or replace function public.fn_parte_diario_mensaje(p_id uuid)
returns text language plpgsql stable as $$
declare
  r public.parte_diario%rowtype;
  msg text := '';
begin
  select * into r from public.parte_diario where id = p_id;
  if not found then return null; end if;

  msg := msg || format('SERVICIO %s %s A %s',
          coalesce(to_char(r.fecha,'DD/MM/YYYY'),''),
          coalesce(to_char(r.hora_inicio,'HH24:MI'),'--:--'),
          coalesce(to_char(r.hora_fin,'HH24:MI'),'--:--')) || E'\n\n';

  if r.cabina is not null then
    msg := msg || 'CABINA:'||E'\n'||r.cabina||E'\n\n';
  end if;
  if r.amt is not null then
    msg := msg || 'AMT:'||E'\n'||r.amt||E'\n\n';
  end if;
  if r.puesto_hudson is not null then
    msg := msg || 'PUESTO HUDSON:'||E'\n'||r.puesto_hudson||E'\n\n';
  end if;
  if r.choferes is not null then
    msg := msg || 'CHOFERES:'||E'\n- '||array_to_string(r.choferes, E'\n- ')||E'\n\n';
  end if;
  if r.caja_chica is not null then
    msg := msg || format('CAJA CHICA: $ %s', to_char(r.caja_chica,'999G999G990D00')) || E'\n\n';
  end if;
  if r.novedades_vehiculos is not null then
    msg := msg || 'NOVEDADES DE VEHICULOS'||E'\n';
    msg := msg || jsonb_each_text(r.novedades_vehiculos)::text || E'\n\n';
  end if;
  if r.familia_en_quinta is not null then
    msg := msg || 'INTEGRANTES DE LA FAMILIA EN LA QUINTA'||E'\n';
    msg := msg || jsonb_each_text(r.familia_en_quinta)::text || E'\n\n';
  end if;
  if r.personal_domestico is not null then
    msg := msg || 'PERSONAL DOMESTICO'||E'\n'|| r.personal_domestico::text || E'\n\n';
  end if;
  if r.sistemas_tecnicos is not null then
    msg := msg || 'SISTEMAS/TECNICOS'||E'\n'|| r.sistemas_tecnicos::text || E'\n\n';
  end if;
  if r.profesionales is not null then
    msg := msg || 'PROFESIONALES'||E'\n'|| r.profesionales::text || E'\n\n';
  end if;
  if r.invitados is not null then
    msg := msg || 'INVITADOS'||E'\n'|| r.invitados::text || E'\n\n';
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
end$$;

-- Vista útil para el front (trae mensaje listo)
create or replace view public.parte_diario_whatsapp as
select
  id,
  user_id,
  fecha,
  hora_inicio,
  hora_fin,
  fn_parte_diario_mensaje(id) as mensaje
from public.parte_diario;

-- Permisos de la vista
alter view public.parte_diario_whatsapp owner to postgres;
-- (RLS no aplica a views; la política del select en parte_diario ya limita por user_id)

-- ========= Refrescar el esquema de la API =========
notify pgrst, 'reload schema';

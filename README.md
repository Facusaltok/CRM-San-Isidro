# CRM San Isidro (Supabase + Alpine + Tailwind)

Panel operativo para control de **ingresos/salidas**, **paquetería**, **agenda**, **movimientos** y **parte diario**; con autenticación por usuario (nombre y apellido), y tablero black & gold.

## 1) Requisitos
- Cuenta Supabase (URL y anon key).
- Navegador moderno.
- (Opcional) Python o Node para servir estático.

## 2) Configurar Supabase
1. **Auth → Providers**: habilitar *Email + Password*.
2. **Auth → URL Configuration** (desarrollo):
   - Site URL: `http://localhost:8080/`
   - Redirect URLs: `http://localhost:8080/index.html`, `http://localhost:8080/dashboard.html`
3. **SQL**: abrir el **SQL Editor** y pegar `schema.sql` (este repo) para crear tablas y RLS.
4. **API Keys**: copiar URL y anon key del proyecto.

## 3) Credenciales en el frontend
En `index.html` y `dashboard.html` ya están puestas estas credenciales (podés cambiarlas si es otro proyecto):
- URL: `https://upprsqwloohuzxpwobiu.supabase.co`
- anon: `eyJhbGciOiJI...` (truncado)

> El SDK de Supabase se carga y crea el cliente con `onload`, y el código usa `ensureSB()` para evitar el error *Cannot read properties of undefined (reading 'auth')*.

## 4) Correr local
Con Python:
```bash
python -m http.server 8080
# abrir http://localhost:8080
```

Con Node (serve):
```bash
npm i -g serve
serve -l 8080 .
```

## 5) Deploy (Vercel/GitHub Pages)
- **Vercel**: importar repo → Static site. Agregar la URL final en Supabase → *Auth → URL Configuration* (Site y Redirects).
- **GitHub Pages**: Settings → Pages → Deploy from a branch.

## 6) Tablas
- `empleados` (perfil de usuario con nombre/apellido).
- `clientes`, `vehiculos`, `citas`.
- `accesos` (entradas/salidas con persona, DNI, vehículo, dominio, motivo, fecha/hora).
- `paqueteria` (recepción/entrega y estado).
- `agenda_dom` (tareas del día, check).
- `movimientos` (gastos/ingresos por categoría).
- `presencias` (tildes por fecha/categoría/item/valor) → genera el **parte diario** y enlace a **WhatsApp**.

## 7) Seguridad
- RLS habilitado en todas las tablas con política `to authenticated`. Ajustar si necesitás multi-tenant o roles.

## 8) Notas
- El dashboard autocrea el registro en `empleados` la primera vez que un usuario con Auth inicia sesión (usa su email para inferir nombre/apellido).
- Paleta visual *premium* dorado/negro.

# 🌐 SIGMAV2 - Configuración Nginx Detallada

Explicación completa de todas las configuraciones Nginx.

---

## 📋 Estructura de Archivos Nginx

```
nginx/
├── nginx.conf              # Configuración principal
├── sigmav2-frontend.conf   # Config para servir frontend
└── conf.d/
    └── sigmav2.conf        # Rutas proxy (API)
```

**Carga:**
```
Nginx arranca
  ↓
Lee /etc/nginx/nginx.conf (montado en contenedor)
  ↓
Línea: include /etc/nginx/conf.d/*.conf
  ↓
Lee todas archivos en conf.d/ (sigmav2.conf)
  ↓
Escucha en puertos definidos
```

---

## 🔧 nginx.conf (Configuración Principal)

Archivo: `nginx/nginx.conf`

```nginx
user nginx;
```

**Explicación:**
- `user nginx` = Usuario del proceso worker de Nginx
- En contenedor: usuario `nginx` (uid 101)
- Archivos servidos con permisos `nginx:nginx`

**Seguridad:**
- No corre como root (mejor práctica)
- Limitado en permisos de archivos

---

```nginx
worker_processes auto;
```

**Explicación:**
- `worker_processes` = Número de procesos worker
- `auto` = Detecta número de CPUs
- Cada worker maneja conexiones independientes

**Cálculo automático:**
```
CPU count = 4
  ↓
worker_processes = 4
  ↓
Máximo 4 conexiones paralelas por kernel
  ↓
Total conexiones = 4 workers × worker_connections
```

**Alternativas:**
```nginx
worker_processes 1;      # Forzar un worker
worker_processes 4;      # Forzar 4 workers
worker_processes auto;   # ← Recomendado
```

---

```nginx
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
```

**Explicación:**
- `error_log` = Dónde guardar errores
- `warn` = Nivel (debug, info, notice, warn, error, crit, alert, emerg)
- `pid` = Archivo PID del master process

**Niveles de log:**
```
debug    = Todo (muy verbose)
info     = Información general
notice   = Notices normales
warn     = Warnings (problemas)     ← Típico
error    = Errores (issues serios)
crit     = Critical (muy grave)
alert    = Alertas (urgente)
emerg    = Emergencias (sistema down)
```

---

```nginx
events {
    worker_connections 1024;
}
```

**Explicación:**
- `events` = Bloque de configuración del evento (requerido)
- `worker_connections 1024` = Máximo conexiones por worker

**Cálculo máximo conexiones:**
```
worker_processes = 4
worker_connections = 1024
  ↓
Total = 4 × 1024 = 4096 conexiones concurrentes
```

**Ajuste según carga:**
```
Bajo:    256-512      (desarrollo, few users)
Medio:   1024         ← Típico (sigmav2)
Alto:    2048-4096    (muchos usuarios)
Muy alto: 8192+       (escala, requiere ulimit)
```

---

```nginx
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
```

**Explicación:**
- `include /etc/nginx/mime.types` = Mapeo extensión → Content-Type
  ```
  .js     → application/javascript
  .css    → text/css
  .html   → text/html
  .json   → application/json
  .png    → image/png
  ```
- `default_type` = Si extensión desconocida → application/octet-stream

**Ejemplo:**
```
GET /main.js
  ↓
Nginx busca: .js en mime.types
  ↓
Encuentra: application/javascript
  ↓
Response header: Content-Type: application/javascript
```

---

```nginx
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';

    access_log /var/log/nginx/access.log main;
```

**Explicación:**
- `log_format` = Define formato log de acceso
- `access_log` = Guarda en archivo con formato

**Variables en log:**
```
$remote_addr      = IP del cliente (X-Real-IP si proxy)
$remote_user      = Usuario autenticado (si hay auth)
$time_local       = Timestamp en formato local
$request          = GET /path HTTP/1.1
$status           = 200, 404, 500, etc
$body_bytes_sent  = Bytes en response
$http_referer     = Página desde donde vino
$http_user_agent  = navegador/app del cliente
```

**Ejemplo log:**
```
192.168.1.100 - - [18/Feb/2025 14:30:45 +0000]
"GET /sigmav2 HTTP/1.1" 200 1024
"-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
```

---

```nginx
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
```

**Explicación:**
- `sendfile on` = Usa sendfile() del OS (más eficiente)
  - Sin copy a buffer: kernel → socket directo
- `tcp_nopush on` = Agrupa paquetes antes enviar (menos packets)
- `tcp_nodelay on` = Envía sin esperar más data (low latency)
- `keepalive_timeout 65` = Mantiene conexión 65s inactiva

**Efecto juntos:**
```
sendfile: Eficiencia de lectura
tcp_nopush: Eficiencia de envío (agrupa)
tcp_nodelay: Baja latencia (no espera)
keepalive: Reutiliza conexiones TCP
  ↓
Resultado: Throughput alto + latencia baja
```

---

```nginx
    types_hash_max_size 2048;
    client_max_body_size 100M;
```

**Explicación:**
- `types_hash_max_size` = Tamaño hash tabla MIME types
  - Default 1024 (puede ser pequeño si hay muchos tipos)
  - Aumentar a 2048 es seguro
- `client_max_body_size 100M` = Máximo tamaño POST/PUT
  - Default 1M (muy pequeño para uploads)
  - 100M = Permite subir archivos hasta 100 MB

**Impacto:**
```
GET /filename.jpg
  ↓
Nginx busca en types_hash_size
  ↓
Si tamaño chico → colisiones hash
  ↓
Nginx avisa: "types_hash_max_size"

POST /upload (100 MB file)
  ↓
Si client_max_body_size < 100M
  ↓
Error 413: Request Entity Too Large
```

---

```nginx
    proxy_connect_timeout 120s;
    proxy_send_timeout 120s;
    proxy_read_timeout 120s;
```

**Explicación:**
- `proxy_connect_timeout` = Máximo espera conectar a backend
- `proxy_send_timeout` = Máximo espera enviar request a backend
- `proxy_read_timeout` = Máximo espera response de backend

**Flujo:**
```
Cliente → Nginx → Backend
         │       │
         └────── connect_timeout (120s)
                 send request
                 send_timeout (120s)
                 recibe response
                 read_timeout (120s)
```

**Cuándo ocurren:**
```
connect_timeout:  La DB está down, backend lento
send_timeout:     Backend no lee datos rápido
read_timeout:     Backend procesa lento, no responde
```

**Ajuste:**
```
Operaciones rápidas:  10-30s
Operaciones lentas:   60-120s ← Para queries complejas
Reportes muy lentos:  300s+
```

---

```nginx
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript
               application/x-javascript application/xml+rss
               application/javascript application/json;
```

**Explicación:**
- `gzip on` = Comprime responses antes enviar
- `gzip_vary on` = Agrega Vary: Accept-Encoding (para caché)
- `gzip_types` = Tipos a comprimir

**Compresión:**
```
main.js (150 KB)
  ↓
gzip comprime
  ↓
Envía: main.js.gz (30 KB) + header: Content-Encoding: gzip
  ↓
Browser descomprime automáticamente
  ↓
Tamaño transferencia: 30 KB vs 150 KB = 80% más rápido
```

**Qué tipos comprimir:**
```
✅ text/plain          (logs, etc)
✅ text/css            (estilos)
✅ application/json    (API responses)
✅ application/javascript (scripts)
✅ text/xml            (XML)

❌ image/png           (ya comprimidas)
❌ image/jpeg          (ya comprimidas)
❌ video/mp4           (ya comprimidas)
```

---

```nginx
    include /etc/nginx/conf.d/*.conf;
}
```

**Explicación:**
- Incluye todos archivos en `/etc/nginx/conf.d/`
- Carga: `sigmav2.conf` (nuestro archivo de rutas)

**Orden de carga:**
```
1. nginx.conf (este archivo)
2. Todo en conf.d/ (sigmav2.conf)
   └─ server blocks
   └─ upstream blocks
   └─ etc
```

---

## 🚦 conf.d/sigmav2.conf (Routing)

Archivo: `nginx/conf.d/sigmav2.conf`

```nginx
server {
    listen 80;
    server_name _;
```

**Explicación:**
- `server` = Bloque servidor (pode haber múltiples)
- `listen 80` = Escucha en puerto 80 (HTTP)
- `server_name _` = Matches CUALQUIER nombre
  - `_` es wildcard (catch-all)
  - Alternativa: `server_name example.com www.example.com`

**Ejemplo con múltiples dominios:**
```nginx
server_name sigmav2.example.com;      # Específico
server_name ~^sigmav2-.*\.example.com$;  # Patrón regex
server {
    server_name _;  # Fallback (default)
}
```

---

```nginx
    location /sigmav2 {
        proxy_pass http://sigmav2-frontend;
```

**Explicación:**
- `location /sigmav2` = Ruta a matchear
- `proxy_pass http://sigmav2-frontend` = Redireccionar a
  - `sigmav2-frontend` = DNS interno en Docker
  - Resuelve a IP del contenedor
  - Puerto default: 80 (Nginx en contenedor escucha 80)

**Match de rutas:**
```
GET /sigmav2          → location /sigmav2 ✅
GET /sigmav2/        → location /sigmav2 ✅
GET /sigmav2/about   → location /sigmav2 ✅
GET /api/users       → location /sigmav2 ❌

Sí va a:
GET /sigmav2/api     → Pero probablemente location /sigmav2/api/ lo matchea mejor
```

---

```nginx
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
```

**Explicación:** Headers pasados al backend

| Header | Valor | Uso |
|--------|-------|-----|
| `Host` | `$host` (dominio original) | Backend sabe en qué dominio se accesó |
| `X-Real-IP` | `$remote_addr` (IP real cliente) | Backend obtiene IP cliente (para logs) |
| `X-Forwarded-For` | Chain IPs si hay múltiples proxies | Cadena de IPs por proxies |
| `X-Forwarded-Proto` | `http` o `https` | Backend sabe si es HTTP o HTTPS |

**Ejemplo headers:**
```
Request original:
Host: example.com
...

Nginx proxy lo modifica a:
Host: example.com
X-Real-IP: 192.168.1.100
X-Forwarded-For: 192.168.1.100
X-Forwarded-Proto: http

Backend recibe estos headers
```

**Por qué importante:**
```
Sin headers:
  Backend ve:
    Host: sigmav2-frontend (DNS interno)
    Remote: 172.18.0.1 (IP interna Docker)

Con headers:
  Backend ve:
    Host: example.com (original)
    X-Real-IP: 192.168.1.100 (cliente real)
```

---

```nginx
    }

    location /sigmav2/api/ {
        proxy_pass http://sigmav2-backend/api/;
```

**Explicación:**
- Matchea: `/sigmav2/api/*`
- Redirecciona a: `http://sigmav2-backend:8080/api/`
- Reescribe PATH:
  ```
  GET /sigmav2/api/users
  → proxy_pass/api/
  → GET /api/users (en backend)
  ```

**Matching priority:**
```
GET /sigmav2/api/users
  ↓
¿location /sigmav2/api/?  ✅ Matches (más específico)
¿location /sigmav2?       ✅ Matches (menos específico)
  ↓
Nginx elige: /sigmav2/api/ (más específico gana)
```

---

```nginx
    location /sigmav2/api/health {
        proxy_pass http://sigmav2-backend/api/health;
```

**Explicación:**
- Ruta específica para health check
- No necesita reescritura `/api/` (ya incluida)
- Permite monitoreo: `curl http://IP/sigmav2/api/health`

**Priority:**
```
GET /sigmav2/api/health
  ↓
¿location /sigmav2/api/health?  ✅ Exacto (priority 1)
¿location /sigmav2/api/?        ✅ Patrón (priority 2)
¿location /sigmav2?             ✅ Patrón (priority 3)
  ↓
Elige: /sigmav2/api/health (más específico)
```

---

```nginx
    location ~* \.(ico|css|js|gif|jpe?g|png|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://sigmav2-frontend;
        proxy_cache_valid 200 30d;
        expires 30d;
    }
```

**Explicación:**
- `~*` = Regex case-insensitive
- Matchea extensiones: `.ico`, `.css`, `.js`, `.gif`, `.jpg`, `.jpeg`, `.png`, `.svg`, `.woff`, `.woff2`, `.ttf`, `.eot`

**Regex breakdown:**
```
\.        = Literal punto
(ico|css|js|...)  = Una de estas extensiones
jpe?g     = jpg o jpeg (? = 0 o 1)
$         = Fin string
```

**Caching:**
```
proxy_cache_valid 200 30d;
  = Cache responses 200 por 30 días

expires 30d;
  = Agrega header: Expires (futuro + 30d)
  = Browser cachea localmente
```

**Flujo:**
```
GET /sigmav2/main.js
  ↓
Nginx cache check
  ↓
Si en caché y no expirado: sirve directo
Si no en caché: proxy a frontend, guarda caché
  ↓
Response headers:
  Cache-Control: max-age=2592000  (30 días)
  Expires: <30 días en futuro>
  ✅ Browser cachea 30 días (no re-descarga)
```

---

## 🚀 sigmav2-frontend.conf (SPA Serving)

Archivo: `nginx/sigmav2-frontend.conf`

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
```

**Explicación:**
- `root /usr/share/nginx/html` = Documentroot (donde está dist/)
- `index index.html` = Archivo default

---

```nginx
    location / {
        try_files $uri $uri/ /index.html;
    }
```

**Explicación:**
- `try_files` = Intenta archivos en orden
- Flujo:
  ```
  GET /about
    ↓
  try_files /about /about/ /index.html
    ↓
  ¿Existe /about?       No
  ¿Existe /about/?      No
  ¿Existe /index.html?  Sí → Sirve index.html
  ```

**Por qué esto (SPA routing):**
- Vue Router maneja rutas en browser
- `/about` no existe como archivo
- Se sirve `index.html`, Vue Router detecta ruta y renderiza componente

**Sin try_files:**
```
GET /about
  ↓
¿Existe /about?  No
  ↓
Error 404 Not Found ❌
```

---

```nginx
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
```

**Explicación:**
- Assets (JS/CSS compilados) cachean 30 días
- `immutable` = Nunca cambia (porque Vite usa hash en filenames)

**Vite output:**
```
main.abc123def456.js
main.xyz789uvw012.css
```

**Caching:**
```
GET /main.abc123def456.js
  ↓
Header: Cache-Control: public, immutable; max-age=2592000
  ↓
Browser: "Este archivo NUNCA cambia, cachea 30 días"
  ↓
GET /main.xyz789uvw012.js (versión nueva)
  ↓
Nuevo hash = nuevo archivo = re-descarga
```

---

```nginx
    location ~* \.html?$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
```

**Explicación:**
- HTML (index.html) NO se cachea
- `expires -1` = Tiempo pasado (ya expiró)
- `no-cache` = Valida con servidor antes de usar
- `must-revalidate` = Estricto (no usar stale)

**Efecto:**
```
GET /index.html
  ↓
Browser: "Siempre valida con servidor si me puedes enviar versión nueva"
  ↓
Si index.html cambió → descarga nuevo
Si no cambió → servidor responde 304 Not Modified
```

**Why:**
```
index.html referencia:
  <script src="main.abc123def456.js"></script>

Si cambias código:
  <script src="main.xyz789uvw012.js"></script>

Browser DEBE re-descargar index.html para obtener nuevo hash
```

---

## 🔄 Orden Evaluación Locations

Nginx evalúa `location` en este orden:

```
1. location /sigmav2/api/health          (Exacto)
2. location /sigmav2/api/                (Prefijo largo)
3. location /sigmav2                     (Prefijo corto)
4. location ~* \.(js|css|...)$           (Regex)
5. location /                            (Default)
```

**Ejemplo GET /sigmav2/api/users:**
```
¿/sigmav2/api/health?        No
¿/sigmav2/api/?              Sí ✅ (se usa esto)
```

**Ejemplo GET /sigmav2/main.js:**
```
¿/sigmav2/api/?              No
¿/sigmav2?                   Sí (matches)
¿~* \.(js|...)?              Sí (matches, pero menos priority)
→ /sigmav2 se elige primero
```

---

## 🧪 Testing Configuración

```bash
# Syntax check
docker exec nginx_proxy nginx -t

# Reload config (sin downtime)
docker exec nginx_proxy nginx -s reload

# Ver actual config
docker exec nginx_proxy cat /etc/nginx/nginx.conf

# Ver logs
docker logs nginx_proxy

# Test ruta específica
curl -I http://localhost/sigmav2
curl -I http://localhost/sigmav2/api/health
curl -I http://localhost/sigmav2/main.js
```

---

**Última actualización:** 2025-02-18  
**Versión:** 1.0

# 🏗️ SIGMAV2 - Arquitectura de Despliegue

Documentación detallada de la arquitectura, componentes, redes y flujos.

---

## 📊 Diagrama General

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
│                   Puerto 80 (HTTP público)                      │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
┌──────────────────────────────────────────────────────────────────┐
│                    NGINX PROXY (nginx_proxy)                      │
│                      Puerto 80 (público)                         │
│                  Red: proxy_network (Docker)                     │
├──────────────────────────────────────────────────────────────────┤
│  Ruta: /sigmav2       → sigmav2-frontend:80                     │
│  Ruta: /sigmav2/api/* → sigmav2-backend:8080/api/*             │
│  Estáticos            → Cache 30 días                           │
└──────────────────────────────────────────────────────────────────┘
         │                              │
         ↓                              ↓
┌──────────────────────┐    ┌──────────────────────────┐
│ SIGMAV2 FRONTEND     │    │ SIGMAV2 BACKEND          │
│ (sigmav2-frontend)   │    │ (sigmav2-backend)        │
├──────────────────────┤    ├──────────────────────────┤
│ Nginx + Vue 3 dist   │    │ Spring Boot (Java 21)    │
│ Puerto: 3000→80      │    │ Puerto: 8080             │
│ Red: proxy_network   │    │ Red: proxy_network +     │
│ (interno, privado)   │    │      sigmav2_internal    │
│                      │    │                          │
│ Node 22 build        │    │ Maven build              │
│ Vite compile         │    │ Spring Boot 3.5.5        │
│ Nginx serve          │    │ JPA + MySQL connector    │
└──────────────────────┘    │ JWT authentication       │
                            │ Upload files: /app/uploads
                            └──────────────────────────┘
                                       │
                                       ↓
                            ┌──────────────────────────┐
                            │  SIGMAV2 DATABASE        │
                            │  (sigmav2-db)            │
                            ├──────────────────────────┤
                            │ MySQL 8.0                │
                            │ Puerto: 3306 (privado)   │
                            │ Red: sigmav2_internal    │
                            │ Volumen: mysql_data      │
                            │ Init: SIGMAV2_2.sql      │
                            └──────────────────────────┘
```

---

## 🔗 Redes Docker

### Red 1: `proxy_network` (Compartida)

**Propósito:** Conecta Nginx con aplicaciones públicas

**Conectados:**
- `nginx-proxy` (Nginx - proxy principal)
- `sigmav2-backend` (Backend Spring Boot)
- `sigmav2-frontend` (Frontend Nginx)

**Características:**
- Tráfico externo pasa por aquí
- Separación de BD (no expuesta)
- Permite coexistir con otras apps

**Uso interno:**
```
nginx-proxy → sigmav2-backend (http://sigmav2-backend:8080)
nginx-proxy → sigmav2-frontend (http://sigmav2-frontend:80)
```

### Red 2: `sigmav2_internal` (Privada)

**Propósito:** Conecta Backend con BD (sin exponerlas)

**Conectados:**
- `sigmav2-backend` (Backend Java)
- `sigmav2-db` (MySQL 8.0)

**Características:**
- BD NUNCA expuesta externamente
- Solo Backend puede conectar a BD
- Aislamiento de seguridad

**Uso interno:**
```
sigmav2-backend → sigmav2-db (jdbc:mysql://sigmav2-db:3306/sigmav2)
```

---

## 💾 Volúmenes Persistentes

### Volumen 1: `sigmav2_mysql_data`

**Ruta en contenedor:** `/var/lib/mysql`  
**Ruta en host:** `/var/lib/docker/volumes/sigmav2_mysql_data/_data`  
**Propietario:** `mysql:mysql` (uid 999:999)

**Contiene:**
- Base de datos completa (sigmav2)
- Índices y metadatos
- Logs de MySQL
- Archivos de recuperación

**Persistencia:**
- Sobrevive a `docker-compose down`
- Se pierde con `docker volume rm`
- Backup: `mysqldump` o copiar directorio

### Volumen 2: `sigmav2_uploads_data`

**Ruta en contenedor:** `/app/uploads` (Backend)  
**Ruta en host:** `/var/lib/docker/volumes/sigmav2_uploads_data/_data`  
**Propietario:** Usuario dentro contenedor Spring Boot

**Contiene:**
- Imágenes subidas por usuarios
- Documentos adjuntos
- Archivos QR escaneados

**Persistencia:**
- Sobrevive a `docker-compose down`
- Accesible desde Frontend via API
- Backup: `tar -czf` del directorio

---

## 🐳 Contenedores Detallados

### Contenedor 1: `sigmav2_db` (MySQL 8.0)

**Basado en:** `mysql:8.0` (imagen oficial)

**Variables de Entorno:**
```
MYSQL_ROOT_PASSWORD   = ${DB_ROOT_PASSWORD}  # Contraseña root
MYSQL_DATABASE        = ${DB_NAME}           # DB creada al iniciar
```

**Puertos:**
```
3306:3306  →  Interno (no expuesto)
             Acceso solo desde sigmav2_internal
```

**Volumen:**
```
sigmav2_mysql_data:/var/lib/mysql
```

**Scripts de inicialización:**
```
/docker-entrypoint-initdb.d/SIGMAV2_2.sql
  ↓
Se ejecuta cuando BD no existe
Crea tablas, índices, relaciones
```

**Health Check:**
```bash
mysqladmin ping -h localhost
# Intenta conectar cada 10 segundos
# Falla = conteo de intentos
# Después de 5 fallos = UNHEALTHY
```

**Logs:**
```bash
docker logs sigmav2_db
# Ver: conexiones, consultas lentas, errores
```

---

### Contenedor 2: `sigmav2_backend` (Spring Boot)

**Basado en:** Dockerfile multi-stage

**Stages:**

#### Stage 1: Build
```dockerfile
FROM maven:3.9.6-eclipse-temurin-21
```
- Maven 3.9.6
- Java 21 (OpenJDK - Eclipse Temurin)
- Compila: `mvn clean package -DskipTests`
- Output: `target/*.jar`

#### Stage 2: Runtime
```dockerfile
FROM eclipse-temurin:21-jre
```
- Solo JRE 21 (no Maven)
- Copia JAR de stage 1
- Ejecuta: `java -jar app.jar`

**Variables de Entorno (inyectadas):**
```
SPRING_DATASOURCE_URL       = jdbc:mysql://sigmav2-db:3306/sigmav2
SPRING_DATASOURCE_USERNAME  = root
SPRING_DATASOURCE_PASSWORD  = ${DB_ROOT_PASSWORD}
SERVER_PORT                 = 8080
JWT_SECRET                  = ${JWT_SECRET}
APP_BASE_URL                = http://${SERVER_IP}/sigmav2
APP_UPLOAD_DIR              = /app/uploads
```

**Puertos:**
```
8080:8080  →  Interno (conectado a proxy_network)
              NO accesible desde Internet directo
```

**Volumen:**
```
sigmav2_uploads_data:/app/uploads
  ↓
Almacena archivos subidos
Accesible desde Frontend via API
```

**Dependencias (from pom.xml):**
- Spring Boot 3.5.5
- Spring Data JPA (Hibernate ORM)
- Spring Web (REST controllers)
- MySQL Connector Java
- JWT (JSON Web Tokens)
- Spring Security
- Spring Actuator (health checks)
- Spring AOP

**Health Check:**
```
GET /api/health
→ Retorna 200 OK si servicio está listo
```

**Tiempo de startup:** 10-20 segundos

---

### Contenedor 3: `sigmav2_frontend` (Vue 3 + Nginx)

**Basado en:** Dockerfile multi-stage

**Stage 1: Build**
```dockerfile
FROM node:22-alpine
```
- Node 22 Alpine (18.5 MB - muy pequeña)
- npm install (dependencies)
- npm run build (Vite compile)
- Output: `dist/` (archivos estáticos HTML/CSS/JS)

**Stage 2: Runtime**
```dockerfile
FROM nginx:alpine
```
- Nginx Alpine (12 MB)
- Copia `dist/` → `/usr/share/nginx/html`
- Copia config → `/etc/nginx/conf.d/default.conf`
- Serve: HTTP puerto 80

**Variables de Build:**
```
VITE_API_URL=/sigmav2/api/sigmav2
  ↓
Compilado en el build
Disponible en app como import.meta.env.VITE_API_URL
```

**Puertos:**
```
80:80 (interno)  →  Accesible desde proxy via http://sigmav2-frontend:80
3000:80 (host)   →  Para debugging en desarrollo (mapea a contenedor)
```

**Nginx Config (dentro contenedor):**
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    
    location / {
        try_files $uri $uri/ /index.html;
        # SPA routing: todas rutas → index.html
    }
    
    location ~* \.(js|css|...)$ {
        expires 30d;  # Cache assets 30 días
    }
    
    location ~* \.html$ {
        expires -1;   # No cachear HTML
    }
}
```

**Compilación:**
```
npm install      → node_modules/ (~150 MB)
npm run build    → dist/ (~500 KB)
```

**Tamaño final de imagen:** ~50 MB

---

### Contenedor 4: `nginx_proxy` (Nginx Proxy Principal)

**Basado en:** `nginx:alpine` (imagen oficial)

**Puertos:**
```
80:80      →  HTTP público
443:443    →  HTTPS público (futuro: Let's Encrypt)
```

**Volúmenes:**
```
./nginx/nginx.conf               → /etc/nginx/nginx.conf (config principal)
./nginx/conf.d/sigmav2.conf     → /etc/nginx/conf.d/sigmav2.conf (rutas)
./nginx/sigmav2-frontend.conf   → Copia en build (frontend config)
```

**Config Principal (nginx.conf):**
```nginx
# Worker processes = CPU count (auto)
worker_processes auto;

# Conexiones por worker
worker_connections 1024;

# Compression
gzip on;

# Timeouts
proxy_connect_timeout 120s;
proxy_send_timeout 120s;
proxy_read_timeout 120s;

# Buffer
client_max_body_size 100M;
```

**Routing (conf.d/sigmav2.conf):**
```nginx
location /sigmav2 {
    proxy_pass http://sigmav2-frontend;
    # Headers: X-Real-IP, X-Forwarded-For, X-Forwarded-Proto
    # Logs de acceso automáticos
}

location /sigmav2/api/ {
    proxy_pass http://sigmav2-backend/api/;
    # Redirige peticiones API al backend
}

location ~* \.(js|css|...)$ {
    # Cache estáticos 30 días
    expires 30d;
}
```

---

## 🔄 Flujos de Datos

### Flujo 1: Usuario accede a Frontend

```
1. Usuario: curl http://IP/sigmav2
2. DNS → IP pública
3. Nginx proxy (puerto 80) recibe request
4. Nginx busca: location /sigmav2 → proxy_pass http://sigmav2-frontend
5. sigmav2-frontend (Nginx interno) retorna index.html
6. Browser descarga: index.html + main.js + style.css
7. Vue 3 app se inicializa en browser
```

### Flujo 2: Frontend hace petición API

```
1. Frontend JS: fetch('/sigmav2/api/users')
2. Nginx proxy recibe: GET /sigmav2/api/users
3. Nginx: location /sigmav2/api/ → proxy_pass http://sigmav2-backend/api/
4. Request reescrita: /api/users
5. sigmav2-backend recibe: GET /api/users
6. Spring controller procesa
7. Conecta a DB: jdbc:mysql://sigmav2-db:3306/sigmav2
8. MySQL retorna datos
9. Spring retorna JSON
10. Nginx proxy retorna response
11. Browser recibe JSON
12. Vue renderiza datos
```

### Flujo 3: Usuario sube archivo

```
1. Frontend: POST /sigmav2/api/uploads (multipart form-data)
2. Nginx proxy:
   - Max body: 100 MB (client_max_body_size)
   - Proxy a backend
3. Spring Boot:
   - Recibe multipart
   - Valida (tipo, tamaño)
   - Guarda en: /app/uploads/
4. Base de datos:
   - Guarda metadata (nombre, path, etc)
5. Response:
   - URL pública: /sigmav2/api/files/uuid
6. Frontend:
   - Muestra archivo
   - Permite descargar via API
```

---

## 🔐 Seguridad por Capas

### Capa 1: Networking

```
Internet → Nginx proxy (SOLO puerto 80)
           ↓
        proxy_network
           ├→ Backend (accesible)
           └→ Frontend (accesible)

           ↓ (solo Backend)
        sigmav2_internal
           ├→ Backend
           └→ Database (NO accesible desde proxy)
```

**Garantía:** BD nunca expuesta a Internet

### Capa 2: Authentication

```
JWT Token en cada request:
  Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

Backend valida:
  1. Firma (JWT_SECRET)
  2. Expiración (24 horas)
  3. Claims (user, roles)
  4. Revocación (opcional: blacklist)
```

### Capa 3: Secretos

```
.env file:
  - DB_ROOT_PASSWORD (32 bytes)
  - JWT_SECRET (64 bytes)
  - NO en git (.gitignore)
  - Guardado en backup seguro
```

---

## 📈 Escalabilidad Futura

### Opción A: Múltiples Backends (Load Balancing)

```
Nginx upstream:
  upstream backend {
      server sigmav2-backend-1:8080;
      server sigmav2-backend-2:8080;
      server sigmav2-backend-3:8080;
  }
  
  location /sigmav2/api/ {
      proxy_pass http://backend;
  }
```

### Opción B: BD Replicada (Master-Slave)

```
Docker Compose:
  - sigmav2-db (Master)
  - sigmav2-db-replica (Slave)

Spring:
  - Write: Master
  - Read: Replica
```

### Opción C: Redis Cache

```
Agregar contenedor:
  - redis:7-alpine
  
Spring:
  - Cache @Cacheable
  - Session store
  - Rate limiting
```

---

## 🚀 Startup Sequence

```
docker-compose up -d
       ↓
1. Crear redes: proxy_network, sigmav2_internal
2. Crear volúmenes: sigmav2_mysql_data, sigmav2_uploads_data
3. Build/pull imágenes:
   - mysql:8.0 (oficial, rápido)
   - SIGMAV2-SERVICES/Dockerfile (Maven compile, 2-3 min)
   - Node build (npm install + build, 1-2 min)
   - nginx:alpine (oficial, rápido)
4. Iniciar contenedores en orden:
   a) sigmav2-db (MySQL)
   b) sigmav2-backend (Spring Boot)
   c) sigmav2-frontend (Nginx)
   d) nginx-proxy (Nginx)
5. Health checks:
   - sigmav2-db: mysqladmin ping
   - Otros: están listos
6. Tiempo total: 5-10 minutos
       ↓
Todos servicios UP y comunicados
```

---

## 📊 Recursos Utilizados

### CPU
```
MySQL:      10-20% (en reposo)
Backend:    5-10% (procesando)
Frontend:   <1% (serving estáticos)
Nginx:      <1% (reverse proxy)
```

### Memoria
```
MySQL:      200-300 MB
Backend:    400-500 MB (JVM)
Frontend:   20-30 MB
Nginx:      10-20 MB
```

### Disco
```
MySQL image:       250 MB
Backend image:     500 MB
Frontend image:    50 MB
Nginx image:       15 MB
─────────────────
Total images:    ~815 MB

Data:
  sigmav2_mysql_data:    Variable (según tamaño BD)
  sigmav2_uploads_data:  Variable (según uploads)
```

---

## 🔧 Configuración Avanzada

### Logging Centralizado

**Actualmente:** Logs en stderr (docker logs)

**Futuro:**
```yaml
logging:
  driver: "splunk"  # o loki, datadog, etc
  options:
    splunk-token: "..."
    splunk-url: "..."
```

### Monitoreo

**Actual:** Health checks básicos

**Futuro:**
```yaml
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/
  
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
```

### Backup Automático

**Script cron:**
```bash
0 2 * * * /home/deployments/scripts/backup-db.sh
# Ejecuta backup diariamente a las 2 AM
```

---

**Última actualización:** 2025-02-18  
**Versión:** 1.0

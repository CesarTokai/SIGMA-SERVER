# 🐳 SIGMAV2 - docker-compose.yml Detallado

Explicación línea por línea del orquestador Docker Compose.

---

## 📋 Estructura General

```yaml
version: '3.8'          # Formato de especificación

services:              # Contenedores a orquestar
  sigmav2-db: ...
  sigmav2-backend: ...
  sigmav2-frontend: ...
  nginx-proxy: ...

volumes:               # Volúmenes persistentes
  sigmav2_mysql_data: ...
  sigmav2_uploads_data: ...

networks:              # Redes Docker
  sigmav2_internal: ...
  proxy_network: ...
```

---

## 🏷️ Version

```yaml
version: '3.8'
```

**Explicación:**
- `3.8` = Versión del formato Compose
- Define features disponibles
- Requiere Docker 20.10+ y Docker Compose 2.0+

**Versiones:**
```
3.0   = 2016 (antigua)
3.5   = 2018 (soporte networks)
3.8   = 2020 (soporte secrets, configs)  ← Usar este
4.0+  = 2023+ (nuevo schema)
```

**Qué cambió en 3.8:**
- Mejor soporte para secrets
- Mejor soporte para configs
- Health check extendidos

---

## 🐳 Services (Contenedores)

### Servicio 1: sigmav2-db (MySQL)

```yaml
services:
  sigmav2-db:
    container_name: sigmav2_db
```

**Explicación:**
- `sigmav2-db` = Nombre servicio en docker-compose
- `container_name: sigmav2_db` = Nombre del contenedor cuando corre
- Otros servicios usan DNS: `http://sigmav2-db:3306`

**Diferencia:**
```
Servicio:    sigmav2-db      (DNS interno, docker-compose)
Contenedor:  sigmav2_db      (docker ps, docker logs)
```

---

```yaml
    build:
      context: .
      dockerfile: Dockerfile.database
```

**Explicación:**
- `build` = Construir imagen desde Dockerfile
- `context: .` = Contexto build (root del repo)
- `dockerfile: Dockerfile.database` = Archivo Dockerfile

**Alternativa (image):**
```yaml
image: mysql:8.0
# Usa imagen existente, no construye
```

**Vs build:**
```
build:
  - Ejecuta Dockerfile
  - Permite COPY desde host
  - Crea imagen custom
  
image:
  - Pull desde registry
  - No permite customización
  - Más rápido
```

---

```yaml
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
```

**Explicación:**
- `environment` = Variables de entorno en contenedor
- `${DB_ROOT_PASSWORD}` = Interpola de `.env`
- MySQL dockerfile.entrypoint usa estas variables

**Flujo:**
```
.env:
  DB_ROOT_PASSWORD=xxxxx

docker-compose.yml:
  ${DB_ROOT_PASSWORD}  ← Interpolado a 'xxxxx'

Contenedor:
  MYSQL_ROOT_PASSWORD=xxxxx
```

**Qué hace MySQL con estas:**
```
MYSQL_ROOT_PASSWORD  → ALTER USER 'root'@'localhost' IDENTIFIED BY '...';
MYSQL_DATABASE       → CREATE DATABASE sigmav2;
```

**Alternativa (hardcoded - MAL):**
```yaml
environment:
  MYSQL_ROOT_PASSWORD: hardcoded123  ❌
# Expone secreto en docker-compose.yml
```

---

```yaml
    volumes:
      - sigmav2_mysql_data:/var/lib/mysql
```

**Explicación:**
- `volumes` = Mapeo volumenes (host ← → contenedor)
- `sigmav2_mysql_data` = Nombre volumen persistente
- `:/var/lib/mysql` = Ruta en contenedor
- Formato: `[source]:[destination]`

**Qué ocurre:**
```
Contenedor escribe en /var/lib/mysql/
  ↓
Docker persiste en volumen
  ↓
Volumen guardado en host:
  /var/lib/docker/volumes/sigmav2_mysql_data/_data/
```

**Persistencia:**
```
docker-compose stop      → Datos persisten
docker-compose down      → Datos persisten
docker-compose down -v   → Datos se pierden ⚠️
```

---

```yaml
    networks:
      - sigmav2_internal
```

**Explicación:**
- `networks` = Redes Docker a las que conectarse
- `sigmav2_internal` = Red privada (solo BD + Backend)
- Aislamiento: BD no accesible desde proxy

**Redes definidas:**
```yaml
networks:
  sigmav2_internal:     # Privada (BD + Backend)
  proxy_network:        # Compartida (Proxy + Backend + Frontend)
```

**Acceso entre servicios:**
```
Servicios en sigmav2_internal:
  ├─ sigmav2-db
  └─ sigmav2-backend
  
Pueden comunicarse:
  sigmav2-backend → sigmav2-db:3306 ✅

Servicios en proxy_network:
  ├─ nginx-proxy
  ├─ sigmav2-backend
  └─ sigmav2-frontend
  
Pueden comunicarse:
  nginx-proxy → sigmav2-backend:8080 ✅
  nginx-proxy → sigmav2-frontend:80 ✅
```

---

```yaml
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
```

**Explicación:**
- `healthcheck` = Prueba periódica de salud del servicio
- `test` = Comando a ejecutar (JSON array = sin shell)

**Desglose:**
```
["CMD", "mysqladmin", "ping", "-h", "localhost"]
  ↓
Ejecuta en contenedor: mysqladmin ping -h localhost

Si exit code = 0 → HEALTHY
Si exit code ≠ 0 → UNHEALTHY
```

**Parámetros:**
```
interval: 10s      # Prueba cada 10 segundos
timeout: 5s        # Espera max 5s por respuesta
retries: 5         # Máximo 5 intentos fallidos
start_period: 30s  # Grace period después de iniciar
```

**Estados:**
```
STARTING  → Primeros 30s (start_period)
HEALTHY   → Pruebas exitosas
UNHEALTHY → 5 pruebas fallidas
```

**Uso:**
```yaml
depends_on:
  sigmav2-db:
    condition: service_healthy  # Espera health = HEALTHY
```

---

```yaml
    restart: unless-stopped
```

**Explicación:**
- `restart` = Política cuando contenedor termina
- `unless-stopped` = Reinicia automático (excepto si lo stoppeaste explícitamente)

**Políticas:**
```
no                 # No reinicia nunca
always             # Siempre reinicia (incluso tras reboot)
unless-stopped     # Reinicia, excepto si fu'e stoppado
on-failure         # Reinicia solo en error (exit code ≠ 0)
on-failure:5       # Max 5 reintentos
```

**Uso:**
```
docker stop sigmav2_db
  → Container stay DOWN (porque lo stoppaste)

docker-compose restart
  → Container queda DOWN (porque unless-stopped respeta stop)

docker-compose up
  → Container arranca (porque no estaba stoppado)
```

---

### Servicio 2: sigmav2-backend (Spring Boot)

```yaml
  sigmav2-backend:
    container_name: sigmav2_backend
    build:
      context: ./SIGMAV2-SERVICES
      dockerfile: Dockerfile
```

**Explicación:**
- `context: ./SIGMAV2-SERVICES` = Contexto build (directorio con pom.xml)
- `dockerfile: Dockerfile` = Ubicación dentro de context

**Búsqueda Dockerfile:**
```
./SIGMAV2-SERVICES/Dockerfile
  (relativo a docker-compose.yml)
```

**Build process:**
```
docker-compose up
  ↓
cd ./SIGMAV2-SERVICES
  ↓
docker build -f Dockerfile
  ↓
Maven compila pom.xml → app.jar
  ↓
Copia jar a JRE image
  ↓
Image: sigmav2-server-biuld-sigmav2-backend:latest
```

---

```yaml
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://sigmav2-db:3306/${DB_NAME}
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: ${DB_ROOT_PASSWORD}
      SERVER_PORT: 8080
      JWT_SECRET: ${JWT_SECRET}
      APP_BASE_URL: http://${SERVER_IP}/sigmav2
      APP_UPLOAD_DIR: /app/uploads
```

**Explicación:** Configuración Spring Boot

| Variable | Uso | Ejemplo |
|----------|-----|---------|
| `SPRING_DATASOURCE_URL` | Conexión BD | `jdbc:mysql://sigmav2-db:3306/sigmav2` |
| `SPRING_DATASOURCE_USERNAME` | Usuario BD | `root` |
| `SPRING_DATASOURCE_PASSWORD` | Contraseña BD | `xxxxx` |
| `SERVER_PORT` | Puerto Tomcat | `8080` |
| `JWT_SECRET` | Firma tokens | `xxxxx` (64+ bytes) |
| `APP_BASE_URL` | URL pública app | `http://IP/sigmav2` |
| `APP_UPLOAD_DIR` | Almacenamiento files | `/app/uploads` |

**Spring Boot mapea:**
```
SPRING_DATASOURCE_URL
  ↓
spring.datasource.url = jdbc:mysql://sigmav2-db:3306/sigmav2
  ↓
HibernateJpaAutoConfiguration
  ↓
DataSource bean configurado
  ↓
JPA usa DataSource para queries
```

**DNS interno:**
```
SPRING_DATASOURCE_URL: jdbc:mysql://sigmav2-db:3306/...
                                    └─ Nombre servicio
                                    └─ Docker resuelve a IP contenedor
                                    └─ No requier /etc/hosts
```

---

```yaml
    ports:
      - "8080:8080"
```

**Explicación:**
- Mapeo puertos: `[host]:[contenedor]`
- `8080:8080` = Puerto 8080 host → puerto 8080 contenedor

**Acceso:**
```
localhost:8080     → Contenedor puerto 8080
(solo en host docker)

Desde Internet:    NO (no expuesto en docker-compose)
                   Solo vía Nginx proxy en puerto 80
```

**Por qué mapear si Nginx es el proxy:**
- Debug local: `curl localhost:8080/api/health`
- Desarrollo: acceso directo sin pasar por Nginx

---

```yaml
    volumes:
      - sigmav2_uploads_data:/app/uploads
```

**Explicación:**
- `sigmav2_uploads_data` = Volumen para files subidos
- `/app/uploads` = Ruta en contenedor
- Spring Boot guarda archivos aquí
- Persisten en: `/var/lib/docker/volumes/sigmav2_uploads_data/_data/`

**Uso en aplicación:**
```java
@PostMapping("/upload")
public void upload(@RequestParam("file") MultipartFile file) {
    file.transferTo(new File("/app/uploads/" + file.getOriginalFilename()));
}
```

---

```yaml
    networks:
      - sigmav2_internal
      - proxy_network
```

**Explicación:**
- Backend conectado a DOS redes:
  1. `sigmav2_internal` → Conexión con BD
  2. `proxy_network` → Conexión con Nginx

**Conectividad:**
```
Backend (en ambas redes):
  ├─ Red sigmav2_internal:
  │    └─ Conecta a sigmav2-db:3306
  │
  └─ Red proxy_network:
       └─ Conecta a nginx-proxy:80
```

---

```yaml
    depends_on:
      sigmav2-db:
        condition: service_healthy
```

**Explicación:**
- `depends_on` = Define orden startup
- `condition: service_healthy` = Espera hasta que BD esté HEALTHY

**Flujo:**
```
docker-compose up -d
  ↓
1. Inicia sigmav2-db
2. Ejecuta healthcheck
3. Espera status = HEALTHY
4. Recién inicia sigmav2-backend
5. Backend conecta a DB (ya lista)
```

**Sin condition:**
```yaml
depends_on:
  - sigmav2-db
# Inicia ambo al mismo tiempo
# Backend intenta conectar DB mientras levanta → error de conexión
```

---

### Servicio 3: sigmav2-frontend (Vue + Nginx)

```yaml
  sigmav2-frontend:
    container_name: sigmav2_frontend
    build:
      context: .
      dockerfile: Dockerfile.frontend
      args:
        VITE_API_URL: /sigmav2/api/sigmav2
```

**Explicación:**
- `context: .` = Raíz repo (necesita acceso a SIGMAV2-APPFRONT-END/)
- `args` = Build arguments (compiladas en imagen)

**Build args:**
```
VITE_API_URL=/sigmav2/api/sigmav2
  ↓
En Dockerfile.frontend: RUN npm run build
  ↓
Vite compila y sustituye import.meta.env.VITE_API_URL
  ↓
En dist/main.js:
  const apiUrl = "/sigmav2/api/sigmav2"
```

**Diferencia args vs environment:**
```
args:        Compilados en build (estáticos en imagen)
environment: Inyectados en runtime (flexibles)

frontend: usa args (compilado)
backend:  usa environment (runtime)
```

---

```yaml
    ports:
      - "3000:80"
```

**Explicación:**
- Mapeo para debugging local
- `localhost:3000` → port 80 en contenedor

**Pero en docker-compose:**
```
nginx-proxy se conecta:
  http://sigmav2-frontend:80  (red proxy_network)
  NO usa port 3000
```

---

```yaml
    networks:
      - proxy_network
    depends_on:
      - sigmav2-backend
```

**Explicación:**
- Solo en proxy_network (no necesita BD)
- Depende de Backend (espera que arranque)

---

### Servicio 4: nginx-proxy (Nginx Principal)

```yaml
  nginx-proxy:
    container_name: nginx_proxy
    image: nginx:alpine
```

**Explicación:**
- `image: nginx:alpine` = No construye, usa imagen oficial
- Más eficiente que build (skip Dockerfile)

---

```yaml
    ports:
      - "80:80"
      - "443:443"
```

**Explicación:**
- Puerto 80 público: HTTP
- Puerto 443 público: HTTPS (futuro con Let's Encrypt)

**Acceso desde Internet:**
```
Internet: GET http://IP/sigmav2
         ↓
Host:8080 → IP:80
         ↓
Nginx puerto 80
         ↓
Proxy_pass al backend/frontend
```

---

```yaml
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
```

**Explicación:**
- `:ro` = Read-only (no puede escribir desde contenedor)
- `/etc/nginx/nginx.conf` = Config principal
- `/etc/nginx/conf.d` = Directorio includes (sigmav2.conf)

**Load:**
```
Nginx arranca
  ↓
Lee /etc/nginx/nginx.conf
  ↓
Encuentra: include /etc/nginx/conf.d/*.conf
  ↓
Lee: /etc/nginx/conf.d/sigmav2.conf
  ↓
Configura rutas y proxies
```

---

```yaml
    depends_on:
      - sigmav2-backend
      - sigmav2-frontend
```

**Explicación:**
- Espera que ambos arranquen
- Sin `condition: service_healthy` (Nginx no tiene healthcheck)
- Simple: ambos deben estar en estado "created"

---

---

## 💾 Volumes

```yaml
volumes:
  sigmav2_mysql_data:
    driver: local
  sigmav2_uploads_data:
    driver: local
```

**Explicación:**
- `driver: local` = Volúmenes en host local
- Alternativas: nfs, aws-ebs, ceph, etc.

**Ubicación:**
```
/var/lib/docker/volumes/sigmav2_mysql_data/_data/
/var/lib/docker/volumes/sigmav2_uploads_data/_data/
```

**Comandos:**
```bash
docker volume ls              # Listar volúmenes
docker volume inspect sigmav2_mysql_data  # Ver detalles
docker volume rm sigmav2_mysql_data       # Eliminar ⚠️
```

---

## 🔗 Networks

```yaml
networks:
  sigmav2_internal:
    driver: bridge
  proxy_network:
    driver: bridge
```

**Explicación:**
- `driver: bridge` = Red aislada (defecto)
- Cada red es aislada (servicios en diferentes redes NO se ven)

**Servicios por red:**
```
sigmav2_internal:
  - sigmav2-db
  - sigmav2-backend
  
proxy_network:
  - nginx-proxy
  - sigmav2-backend (conectado a ambas)
  - sigmav2-frontend
```

**Comunicación:**
```
nginx-proxy → sigmav2-backend   ✅ (ambos en proxy_network)
nginx-proxy → sigmav2-db        ❌ (DB no en proxy_network)
sigmav2-backend → sigmav2-db    ✅ (ambos en sigmav2_internal)
```

---

## 🚀 Flujo Completo docker-compose up -d

```
$ docker-compose up -d

Step 1: Create networks
  docker network create sigmav2-server-biuld_sigmav2_internal
  docker network create sigmav2-server-biuld_proxy_network

Step 2: Create volumes
  docker volume create sigmav2_mysql_data
  docker volume create sigmav2_uploads_data

Step 3: Build services
  docker build -t sigmav2-server-biuld-sigmav2-db:latest \
    -f Dockerfile.database .
    
  docker build -t sigmav2-server-biuld-sigmav2-backend:latest \
    -f ./SIGMAV2-SERVICES/Dockerfile ./SIGMAV2-SERVICES
    
  docker build -t sigmav2-server-biuld-sigmav2-frontend:latest \
    -f Dockerfile.frontend .

Step 4: Create containers
  docker create --name sigmav2_db ...
  docker create --name sigmav2_backend ...
  docker create --name sigmav2_frontend ...
  docker create --name nginx_proxy ...

Step 5: Start containers (orden depends_on)
  docker start sigmav2_db
  docker start sigmav2_backend  (espera DB healthcheck)
  docker start sigmav2_frontend
  docker start nginx_proxy

Step 6: All services UP
  ✅ Frontend disponible: http://IP/sigmav2
  ✅ API disponible: http://IP/sigmav2/api
```

---

## 📊 Comandos Útiles

```bash
# Ver estado
docker-compose ps

# Ver logs
docker-compose logs -f sigmav2-backend

# Ejecutar comando en servicio
docker-compose exec sigmav2-backend bash

# Reiniciar servicio
docker-compose restart sigmav2-backend

# Reconstruir y reiniciar
docker-compose up -d --build sigmav2-backend

# Detener todo
docker-compose stop

# Eliminar todo (conserva volúmenes)
docker-compose down

# Eliminar todo + volúmenes ⚠️
docker-compose down -v

# Scale servicio (múltiples instancias)
docker-compose up -d --scale sigmav2-backend=3
```

---

**Última actualización:** 2025-02-18  
**Versión:** 1.0

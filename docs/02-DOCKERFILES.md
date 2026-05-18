# 🐳 SIGMAV2 - Dockerfiles Detallado

Explicación línea por línea de cada Dockerfile.

---

## 📄 Dockerfile.frontend

Archivo: `Dockerfile.frontend`

### Estructura General

```dockerfile
# Build stage
FROM node:22-alpine AS builder
...

# Runtime stage
FROM nginx:alpine
...
```

**Patrón:** Multi-stage build (2 etapas)

---

### Stage 1: Builder (Node.js)

```dockerfile
FROM node:22-alpine AS builder
```

**Explicación:**
- `node:22-alpine` = Imagen oficial Node 22 basada en Alpine Linux
- Alpine = Distribución mínima (~150 MB vs 1+ GB de node:22 con Debian)
- `:22` = Versión Node 22 (LTS)
- `AS builder` = Nombre etapa (referenciado en stage 2)

**Alternativas:**
```
node:22               (Debian, 1+ GB, más herramientas)
node:20-alpine       (Node 20 LTS)
node:22-slim        (Debian comprimida, 400 MB)
```

---

```dockerfile
WORKDIR /app
```

**Explicación:**
- Establece directorio de trabajo dentro contenedor
- Crea `/app` si no existe
- Comandos posteriores ejecutan desde `/app`

**Equivalente bash:**
```bash
mkdir -p /app && cd /app
```

---

```dockerfile
COPY SIGMAV2-APPFRONT-END/SIGMAV2-APP/package*.json ./
```

**Explicación:**
- `COPY src dst` = Copia archivos desde host a contenedor
- `package*.json` = Patrón glob (package.json + package-lock.json)
- `./ ` = Destino `/app/` (porque WORKDIR /app)

**Detalle:**
- `package.json` = Definición de dependencias
- `package-lock.json` = Versiones exactas (reproducible)

**Alternativa (menos seguro):**
```dockerfile
COPY SIGMAV2-APPFRONT-END/SIGMAV2-APP/ ./
# Copia TODO, incluyendo node_modules (evitar)
```

---

```dockerfile
RUN npm install
```

**Explicación:**
- Ejecuta comando dentro contenedor
- `npm install` = Lee package*.json, descarga dependencias
- Crea `node_modules/` (~200+ MB)

**Qué ocurre:**
1. Descarga paquetes desde npm registry
2. Resuelve dependencias transitivas
3. Ejecuta scripts de instalación
4. Crea `node_modules/` y `package-lock.json` actualizado

**Layer Docker:**
- Se cachea (si package*.json no cambió)
- Próxima build reutiliza node_modules

**Alternativas:**
```dockerfile
RUN npm ci  # Usa package-lock.json exactamente (mejor CI/CD)
RUN npm install --ci  # Alias de npm ci
```

---

```dockerfile
COPY SIGMAV2-APPFRONT-END/SIGMAV2-APP .
```

**Explicación:**
- Copia TODO el código fuente desde `.` a `/app/`
- Incluye: `src/`, `vite.config.ts`, `tsconfig.json`, etc
- Excluye: `.gitignore`, `node_modules/` (ya existe)

**Estructura copiada:**
```
/app/
├── src/              (código Vue)
├── public/           (assets públicos)
├── vite.config.ts
├── tsconfig.json
├── package.json      (ya copiado antes)
├── package-lock.json (ya copiado antes)
└── node_modules/     (ya existe de RUN npm install)
```

---

```dockerfile
RUN npm run build
```

**Explicación:**
- Ejecuta script definido en `package.json`
- `"build": "run-p type-check 'build-only {...}' --"`
- Qué hace:
  1. Type check TypeScript
  2. Vite compile + minify
  3. Genera `dist/` (HTML/CSS/JS estáticos)

**Proceso Vite:**
```
src/
├── components/
├── views/
├── App.vue
└── main.ts
    ↓
npm run build
    ↓
dist/
├── index.html        (~10 KB)
├── main.js           (~150 KB minificado)
├── style.css         (~50 KB)
└── chunk-*.js        (code splitting)
```

**Output:**
```
dist/
├── assets/           (JS/CSS compiled)
├── index.html        (entry point)
└── ...
```

**Tamaño:**
- Source: 50+ MB (src/ + node_modules/)
- Build: 500 KB - 2 MB (dist/)
- Ratio: ~1% del original

**Caching:**
- Se cachea si no cambió `src/`
- Importante optimizar: cambios src → rebuild lento

---

### Stage 2: Runtime (Nginx)

```dockerfile
FROM nginx:alpine
```

**Explicación:**
- Nueva imagen base (arranca de cero)
- `nginx:alpine` = Nginx oficial en Alpine Linux
- Stage 1 (builder) descartada (no entra en imagen final)

**Ventaja:**
- Imagen final = ~50 MB
- Sin Node, npm, node_modules, código fuente
- Solo Nginx + dist/

**Alternativa sin multi-stage:**
```dockerfile
FROM node:22-alpine
RUN npm install
RUN npm run build
# Image final = ~1+ GB (incluye Node, npm, node_modules)
```

**Comparación:**
```
Multi-stage:      ~50 MB  ✅
Sin multi-stage: ~1 GB   ❌
```

---

```dockerfile
COPY --from=builder /app/dist /usr/share/nginx/html
```

**Explicación:**
- `--from=builder` = Copia desde etapa Stage 1
- `/app/dist` = Directorio en builder (resultado build Vite)
- `/usr/share/nginx/html` = Documentroot de Nginx en stage 2

**Resultado en imagen final:**
```
/usr/share/nginx/html/
├── index.html
├── main.js
├── style.css
└── assets/
```

**Nginx sirve:**
```
GET / → index.html
GET /main.js → assets compilados
GET /style.css → assets compilados
```

---

```dockerfile
COPY nginx/sigmav2-frontend.conf /etc/nginx/conf.d/default.conf
```

**Explicación:**
- Copia archivo de configuración desde host
- `/etc/nginx/conf.d/default.conf` = Config predeterminada
- Reemplaza config default de nginx:alpine

**Contenido (sigmav2-frontend.conf):**
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    
    location / {
        try_files $uri $uri/ /index.html;
        # SPA routing
    }
}
```

**Qué hace:**
- Escucha puerto 80
- Raíz = documentroot (donde está dist/)
- `try_files` = Si archivo no existe → /index.html
  - `/about` → intenta `/about` → `/about/` → `/index.html`
  - Vue router maneja en browser

---

```dockerfile
EXPOSE 80
```

**Explicación:**
- Documenta que contenedor escucha puerto 80
- **NO expone realmente** (necesita `-p` en docker run)
- Solo documentación para usuarios

**Equivalente:**
```yaml
# En docker-compose.yml
ports:
  - "3000:80"  # Esto SÍ expone
```

---

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

**Explicación:**
- Comando por defecto cuando contenedor inicia
- `nginx` = Ejecuta servidor Nginx
- `-g "daemon off;"` = Nginx en foreground (necesario para Docker)
  - Sin esto: Nginx fork background → contenedor termina

**Qué ocurre:**
1. `docker-compose up` arranca contenedor
2. Ejecuta: `nginx -g "daemon off;"`
3. Nginx vincula puerto 80, entra en loop
4. Docker monitorea el proceso
5. Si termina → contenedor DOWN

**Alternativa (sin foreground):**
```dockerfile
CMD ["nginx"]
# Nginx forkea a background → contenedor termina inmediatamente ❌
```

---

## 📄 Dockerfile.database

Archivo: `Dockerfile.database`

```dockerfile
FROM mysql:8.0
```

**Explicación:**
- `mysql:8.0` = Imagen oficial MySQL 8.0
- Latest patch version
- Basada en Debian

**Versiones disponibles:**
```
mysql:8.0         (latest 8.0.x)
mysql:8.0.36      (específica)
mysql:5.7         (legacy)
```

---

```dockerfile
COPY BD_SIGMAV2/SIGMAV2_2.sql /docker-entrypoint-initdb.d/
```

**Explicación:**
- Copia script SQL desde host
- `/docker-entrypoint-initdb.d/` = Directorio especial MySQL
- SQL se ejecuta cuando BD se crea (PRIMERA VEZ)

**Secuencia:**
```
docker-compose up
  ↓
MySQL contenedor inicia
  ↓
Detecta: MYSQL_DATABASE=sigmav2 (nueva BD)
  ↓
Ejecuta: SIGMAV2_2.sql
  ↓
Crea: tablas, índices, data inicial
```

**Importante:**
- Solo ejecuta SI BD no existe
- Si BD existe → ignora script
- Para actualizar schema: usar migraciones (Spring Flyway/Liquibase)

**Formato SQL esperado:**
```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    ...
);

INSERT INTO users VALUES (...);
```

---

```dockerfile
ENV MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
ENV MYSQL_DATABASE=${DB_NAME}
```

**Explicación:**
- `ENV` = Variales de entorno en contenedor
- `${DB_ROOT_PASSWORD}` = Interpolación de build args
- MySQL dockerfile.entrypoint las usa:
  - `MYSQL_ROOT_PASSWORD` = Contraseña root
  - `MYSQL_DATABASE` = BD a crear

**Proceso:**
1. `docker-compose` lee `.env`
2. Pasa: `-e DB_ROOT_PASSWORD=xxx` al contenedor
3. `Dockerfile` usa: `${DB_ROOT_PASSWORD}`
4. MySQL inicializa con contraseña

**Alternativa (hardcoded - MAL):**
```dockerfile
ENV MYSQL_ROOT_PASSWORD=insecure  ❌
# Exposición de secreto en imagen
```

---

```dockerfile
EXPOSE 3306
```

**Explicación:**
- Documenta que MySQL escucha 3306
- No expone realmente (ver EXPOSE en Dockerfile.frontend)

**En docker-compose:**
```yaml
ports:
  - "3306:3306"  # Expone (SOLO interna en sigmav2_internal)
```

---

## 📄 SIGMAV2-SERVICES/Dockerfile

Archivo: `SIGMAV2-SERVICES/Dockerfile`

### Stage 1: Builder (Maven)

```dockerfile
FROM maven:3.9.6-eclipse-temurin-21 AS builder
```

**Explicación:**
- `maven:3.9.6` = Maven 3.9.6 (build tool Java)
- `eclipse-temurin-21` = JDK 21 (OpenJDK mantenido por Eclipse Foundation)
- `AS builder` = Nombre etapa

**Por qué Maven + JDK:**
- `pom.xml` = Descriptor proyecto Maven
- Maven descarga dependencias, compila, empaqueta
- Necesita JDK completo (compilador javac)

---

```dockerfile
WORKDIR /app
```

(Misma explicación que Dockerfile.frontend)

---

```dockerfile
COPY pom.xml .
COPY src ./src
```

**Explicación:**
- `pom.xml` = Descriptor proyecto (dependencias, versión, etc)
- `src/` = Código fuente Java
- `.` = Destino `/app/`

**Estructura esperada:**
```
SIGMAV2-SERVICES/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/mx/com/tokai/...
│   │   └── resources/
│   └── test/
```

---

```dockerfile
RUN mvn clean package -DskipTests
```

**Explicación:**
- `mvn clean` = Limpia build previos (target/)
- `mvn package` = Compila, empaqueta a JAR
- `-DskipTests` = Omite tests (para build rápido)
  - En PROD: omitir flag para ejecutar tests

**Proceso Maven:**
1. Resuelve dependencias (descarga POMs)
2. Compila: `javac` fuentes a `.class`
3. Ejecuta tests (si no `-DskipTests`)
4. Empaqueta: `.class` + recursos → `target/*.jar`

**Output:**
```
target/SIGMAV2-0.0.1-SNAPSHOT.jar  (~50 MB)
```

**Tiempo:**
- Primera build: 3-5 minutos (descarga dependencias)
- Build subsecuentes: 1-2 minutos (caché Maven)

---

### Stage 2: Runtime (JRE)

```dockerfile
FROM eclipse-temurin:21-jre
```

**Explicación:**
- `eclipse-temurin:21-jre` = JRE 21 (solo runtime, sin compilador)
- `jre` vs `jdk`:
  - `jdk` = Java Development Kit (compilador, herramientas) ~400 MB
  - `jre` = Java Runtime Environment (solo VM) ~150 MB

**Ventaja:**
- Imagen final pequeña (~150 MB)
- Sin herramientas de compilación (no needed en runtime)

**Alternativa (con SDK):**
```dockerfile
FROM eclipse-temurin:21-jdk
# Image final = ~400 MB (incluye compilador, tools)
```

---

```dockerfile
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
```

**Explicación:**
- `--from=builder` = Copia desde etapa 1
- `/app/target/*.jar` = JAR compilado (result pom.xml)
- `app.jar` = Nombre en runtime stage

**Glob `*.jar`:**
- Patrón wildcard (expande a archivo específico)
- Ej: `SIGMAV2-0.0.1-SNAPSHOT.jar` → `app.jar`

**Resultado en imagen final:**
```
/app/
└── app.jar  (~50 MB)
```

---

```dockerfile
EXPOSE 8080
```

(Misma explicación que Dockerfile.frontend, puerto 8080)

---

```dockerfile
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Explicación:**
- `ENTRYPOINT` = Comando principal (vs `CMD`)
- `["java", "-jar", "app.jar"]` = Ejecuta JAR con JVM
- Sintaxis JSON (vs shell)

**Qué ocurre:**
1. Contenedor inicia
2. Ejecuta: `java -jar /app/app.jar`
3. Spring Boot arranca
4. Escucha puerto 8080 (configurado en application.yml)

**Proceso Spring Boot:**
```
java -jar
  ↓
Classpath = JAR
  ↓
Spring Boot detecta Spring jars
  ↓
Inicializa contexto Spring
  ↓
Conecta a BD (SPRING_DATASOURCE_URL)
  ↓
Levanta Tomcat (embedded web server)
  ↓
Escucha 0.0.0.0:8080
  ↓
Listo para requests REST
```

**Tiempo startup:** 10-20 segundos

**Alternativa (CMD):**
```dockerfile
CMD ["java", "-jar", "app.jar"]
# Permite override: docker run -it backend bash
# ENTRYPOINT = más restrictivo (siempre ejecuta java)
```

---

## 🔧 Optimizaciones Dockerfile

### 1. Ordre de COPY (cache optimization)

**Malo:**
```dockerfile
COPY . .
RUN npm install
RUN npm run build
```
- Cambio en `src/` → invalida caché
- `npm install` re-ejecuta (innecesario)

**Bueno:**
```dockerfile
COPY package*.json .
RUN npm install
COPY src .
RUN npm run build
```
- Cambio en `src/` → solo rebuild
- package*.json no cambió → `npm install` cached

### 2. .dockerignore

**Crear archivo:**
```
.git
.gitignore
.env*
node_modules/
dist/
target/
.idea/
__pycache__/
```

**Efecto:**
- Reduce COPY .
- Más rápido build

### 3. Usar imágenes alpine

**Comparación:**
```
node:22              = 1 GB
node:22-alpine      = 150 MB  ← Usar esto

nginx                = 150 MB
nginx:alpine        = 50 MB   ← Usar esto

mysql:8.0           = 600 MB (predefinido, no hay alpine)
```

---

## 📊 Build Process Completo

```
docker-compose up -d
       ↓
═══════════════════════════════════════
BUILD: sigmav2-frontend
═══════════════════════════════════════
Stage 1 (Builder):
  FROM node:22-alpine
  COPY package*.json
  RUN npm install          (1-2 min primera vez)
  COPY src/
  RUN npm run build        (1 min)
  
  Output: /app/dist (~500 KB)
       ↓
Stage 2 (Runtime):
  FROM nginx:alpine
  COPY --from=builder /app/dist
  COPY nginx config
  
  Final image: ~50 MB
       ↓
Image: sigmav2-server-biuld-sigmav2-frontend:latest

═══════════════════════════════════════
BUILD: sigmav2-backend
═══════════════════════════════════════
Stage 1 (Builder):
  FROM maven:3.9.6-eclipse-temurin-21
  COPY pom.xml
  RUN mvn clean package    (2-5 min)
  
  Output: /app/target/*.jar (~50 MB)
       ↓
Stage 2 (Runtime):
  FROM eclipse-temurin:21-jre
  COPY --from=builder JAR
  
  Final image: ~150 MB
       ↓
Image: sigmav2-server-biuld-sigmav2-backend:latest

═══════════════════════════════════════
BUILD: sigmav2-db
═══════════════════════════════════════
  FROM mysql:8.0 (pull official)
  COPY SQL init script
  
  Final image: ~600 MB
       ↓
Image: mysql:8.0 (reused, no build)

═══════════════════════════════════════
Total images: ~800 MB
Tiempo build: 5-10 min (primera vez)
Tiempo build subsecuentes: 1-2 min (cached)
```

---

**Última actualización:** 2025-02-18  
**Versión:** 1.0

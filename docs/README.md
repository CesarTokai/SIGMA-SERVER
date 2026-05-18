# 📚 SIGMAV2 - Documentación de Despliegue Completa

Índice y guía de toda la documentación técnica del despliegue.

---

## 📖 Contenido

### 1. **01-ARCHITECTURE.md** - Arquitectura General
   
**Para entender:** Cómo funciona todo en conjunto

**Temas:**
- Diagrama general de la arquitectura
- 4 contenedores y cómo se comunican
- 2 redes Docker (privada y compartida)
- 2 volúmenes persistentes (datos)
- Flujos de datos (usuario → frontend → API → BD)
- Seguridad por capas
- Escalabilidad futura

**Cuándo leer:**
- Primera vez que depliegas
- Necesitas entender el big picture
- Planeas cambios arquitectónicos

---

### 2. **02-DOCKERFILES.md** - Explicación de Dockerfiles

**Para entender:** Cómo se construyen las imágenes

**Temas:**
- `Dockerfile.frontend` (Node → Vite → Nginx) - línea por línea
- `Dockerfile.database` (MySQL) - inicialización
- `SIGMAV2-SERVICES/Dockerfile` (Maven → Spring Boot) - compilación Java
- Multi-stage builds (optimizar tamaño)
- Caching de layers
- Órdenes de COPY (optimizaciones)
- Tamaños finales de imágenes

**Cuándo leer:**
- Necesitas modificar un Dockerfile
- Cambios de dependencias (package.json, pom.xml)
- Problemas en build
- Optimizar imágenes

---

### 3. **03-DOCKER-COMPOSE.md** - Orquestación Completa

**Para entender:** docker-compose.yml línea por línea

**Temas:**
- Estructura general (services, volumes, networks)
- Cada servicio detallado:
  - BD: variables env, volumen, healthcheck
  - Backend: build, env, ports, depends_on
  - Frontend: build args, ports
  - Nginx: volumes, ports
- Networks (sigmav2_internal vs proxy_network)
- Volúmenes y persistencia
- Flujo startup completo
- Comandos útiles

**Cuándo leer:**
- Necesitas cambiar configuración
- Agregar nuevo servicio
- Modificar puertos o volúmenes
- Debug de conectividad

---

### 4. **04-NGINX-CONFIG.md** - Configuración Nginx

**Para entender:** Cómo Nginx routing y proxy

**Temas:**
- `nginx.conf` - configuración principal
  - Worker processes, logging, gzip, timeouts
  - MIME types, buffer sizes
- `conf.d/sigmav2.conf` - rutas del proxy
  - location /sigmav2 → frontend
  - location /sigmav2/api/ → backend
  - Headers proxy (X-Real-IP, etc)
  - Caching static assets
- `sigmav2-frontend.conf` - config SPA
  - try_files para Vue Router
  - Caching HTML vs assets
- Orden evaluación locations
- Testing configuración

**Cuándo leer:**
- Cambios de rutas o dominios
- Problemas de CORS
- Caching issues
- Performance optimization
- Agregar HTTPS/SSL

---

### 5. **05-SCRIPTS.md** - Scripts de Deployment

**Para entender:** Scripts bash línea por línea

**Temas:**
- `deploy.sh` - primer despliegue
  - Validación .env
  - Health check MySQL
  - Output final
- `restart.sh` - reiniciar servicios
  - Case statement para seleccionar servicio
  - --build flag para reconstruir
- `logs.sh` - ver logs
  - Filtrar por servicio
  - Limitar líneas
- `status.sh` - estado del sistema
  - docker ps, docker stats
  - Health checks
  - URLs acceso
- `stop.sh` - detener servicios
- `rebuild.sh` - reconstruir desde cero
- Mejores prácticas bash

**Cuándo leer:**
- Necesitas modificar scripts
- Debug de deployment
- Automatización
- CI/CD integration

---

## 🎯 Guías por Objetivo

### Primer Despliegue

1. Leer: `DEPLOY_QUICK_START.md` (en raíz repo)
2. Seguir: 3 pasos (config, deploy, verify)
3. Si problemas: leer `04-NGINX-CONFIG.md` + `05-SCRIPTS.md`

### Cambiar Código

**Frontend:**
1. Commit cambios a `SIGMAV2-APPFRONT-END/SIGMAV2-APP`
2. `./scripts/restart.sh frontend --build`
3. Leer: `02-DOCKERFILES.md` (Dockerfile.frontend si hay errores)

**Backend:**
1. Commit cambios a `SIGMAV2-SERVICES`
2. `./scripts/restart.sh backend --build`
3. Leer: `02-DOCKERFILES.md` (Backend Dockerfile si hay errores)

**BD:**
1. Cambios en `BD_SIGMAV2/SIGMAV2_2.sql`
2. `./scripts/rebuild.sh` (necesita reinit completa)

### Problemas

**Frontend en blanco:**
- Leer: `04-NGINX-CONFIG.md` (try_files, SPA routing)
- Comando: `./scripts/logs.sh frontend`

**Backend 500 errors:**
- Leer: `03-DOCKER-COMPOSE.md` (environment variables)
- Comando: `./scripts/logs.sh backend`

**BD no conecta:**
- Leer: `01-ARCHITECTURE.md` (redes, sigmav2_internal)
- Comando: `./scripts/logs.sh db`

**Nginx proxy issues:**
- Leer: `04-NGINX-CONFIG.md` (location blocks, proxy_pass)
- Comando: `./scripts/logs.sh proxy`

**Performance lento:**
- Leer: `04-NGINX-CONFIG.md` (caching, gzip)
- Comando: `./scripts/status.sh` (ver recursos)

### Cambios Arquitectónicos

**Agregar servicio:**
1. Leer: `03-DOCKER-COMPOSE.md` (structure)
2. Leer: `01-ARCHITECTURE.md` (networks)
3. Modificar docker-compose.yml

**Multi-node deployment:**
1. Leer: `01-ARCHITECTURE.md` (escalabilidad futura)

**HTTPS/SSL:**
1. Leer: `04-NGINX-CONFIG.md` (configuración)

---

## 🔗 Tabla de Referencia Rápida

| Documento | Focus | Cuándo Leer |
|-----------|-------|-----------|
| 01-ARCHITECTURE | Big picture | Primero siempre |
| 02-DOCKERFILES | Construcción imágenes | Cambios deps, problemas build |
| 03-DOCKER-COMPOSE | Orquestación | Cambios config, conectividad |
| 04-NGINX-CONFIG | Routing y proxy | Problemas acceso, CORS, cache |
| 05-SCRIPTS | Deployment scripts | Modificar scripts, automatizar |

---

## 📋 Niveles de Profundidad

### 📍 Nivel 1 - Usuario Final

**Necesita saber:**
- Cómo ejecutar `./scripts/deploy.sh`
- Cómo ver logs: `./scripts/logs.sh`
- URLs de acceso

**Lee:**
- `DEPLOY_QUICK_START.md` (raíz)

---

### 🔧 Nivel 2 - Operador/DevOps

**Necesita saber:**
- Cómo funciona arquitectura completa
- Cómo cambiar configuración
- Cómo troubleshoot
- Cómo monitorear

**Lee:**
- 01-ARCHITECTURE
- 03-DOCKER-COMPOSE
- 04-NGINX-CONFIG
- 05-SCRIPTS

---

### 🏗️ Nivel 3 - Ingeniero Deployment

**Necesita saber:**
- Cómo modificar Dockerfiles
- Cómo optimizar imágenes
- Cómo escalar
- Cómo integrar CI/CD

**Lee:**
- Todo (todos documentos)
- Además: Dockerfile best practices, Kubernetes, CI/CD docs

---

## 🔎 Búsqueda por Tema

### Networking/DNS
- 01-ARCHITECTURE.md → Redes Docker
- 03-DOCKER-COMPOSE.md → Networks sección
- 05-SCRIPTS.md → depends_on

### Caching
- 04-NGINX-CONFIG.md → gzip, expires, proxy_cache_valid

### Performance
- 01-ARCHITECTURE.md → Recursos utilizados
- 04-NGINX-CONFIG.md → Timeouts, buffer
- 05-SCRIPTS.md → status.sh

### Logging
- 04-NGINX-CONFIG.md → log_format, access_log
- 05-SCRIPTS.md → logs.sh

### Seguridad
- 01-ARCHITECTURE.md → Seguridad por capas
- 03-DOCKER-COMPOSE.md → environment, .env

### Volúmenes/Persistencia
- 01-ARCHITECTURE.md → Volúmenes persistentes
- 03-DOCKER-COMPOSE.md → volumes sección

### Health Checks
- 03-DOCKER-COMPOSE.md → healthcheck
- 05-SCRIPTS.md → deploy.sh (MySQL health)

### Build/Compilación
- 02-DOCKERFILES.md → Multi-stage builds
- 05-SCRIPTS.md → restart.sh --build

### Reescritura URLs
- 04-NGINX-CONFIG.md → proxy_pass, try_files

### Headers HTTP
- 04-NGINX-CONFIG.md → proxy_set_header

---

## 🎓 Learning Path Recomendado

Para principiantes:
```
1. DEPLOY_QUICK_START.md (raíz)
   ↓
2. 01-ARCHITECTURE.md (overview)
   ↓
3. 03-DOCKER-COMPOSE.md (orquestación)
   ↓
4. 04-NGINX-CONFIG.md (routing)
   ↓
5. 02-DOCKERFILES.md (construcción)
   ↓
6. 05-SCRIPTS.md (automation)
```

Para expertos:
```
1. Salta 01-ARCHITECTURE (asume entendimiento)
2. Va directo a secciones específicas según necesidad
```

---

## 📞 Cuando Leer Cada Documento

```
"Cómo depliego"
  └─→ DEPLOY_QUICK_START.md + 05-SCRIPTS.md

"Quiero entender arquitectura"
  └─→ 01-ARCHITECTURE.md

"Necesito cambiar config BD"
  └─→ 03-DOCKER-COMPOSE.md (sección sigmav2-db)

"Problemas de conectividad"
  └─→ 01-ARCHITECTURE.md (networks)
  └─→ 03-DOCKER-COMPOSE.md (networks)

"Problemas de acceso web"
  └─→ 04-NGINX-CONFIG.md

"Quiero optimizar build"
  └─→ 02-DOCKERFILES.md

"Necesito agregar HTTPS"
  └─→ 04-NGINX-CONFIG.md

"Quiero escalar a múltiples instancias"
  └─→ 01-ARCHITECTURE.md (escalabilidad futura)
  └─→ 03-DOCKER-COMPOSE.md (scale command)

"Problemas en logs"
  └─→ 05-SCRIPTS.md (logs.sh)
  └─→ 04-NGINX-CONFIG.md (log_format)
```

---

## 🔄 Actualización Documentación

Esta documentación fue creada: **2025-02-18**

Actualizar cuando:
- [ ] Cambios en Dockerfiles
- [ ] Cambios en docker-compose.yml
- [ ] Cambios en nginx config
- [ ] Cambios en scripts

---

## 📊 Estadísticas Documentación

```
Documentos:    5 archivos
Secciones:     ~50 subsecciones
Código:        ~200 bloques de código
Palabras:      ~15,000
Tiempo lectura: ~2-3 horas completa
```

---

## ✅ Checklist Antes Producción

Antes de usar en producción, asegurate de haber leído:

- [ ] 01-ARCHITECTURE.md (understand architecture)
- [ ] 03-DOCKER-COMPOSE.md (understand config)
- [ ] 04-NGINX-CONFIG.md (understand routing)
- [ ] 05-SCRIPTS.md (understand deployment)
- [ ] DEPLOY_QUICK_START.md (understand quick start)
- [ ] DEPLOYMENT.md en raíz (complete guide)

---

**Última actualización:** 2025-02-18  
**Versión:** 1.0  
**Audiencia:** Desarrolladores, DevOps, Operadores

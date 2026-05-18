# 🚀 SIGMAV2 - Despliegue en Docker

Guía completa para desplegar SIGMAV2 en Ubuntu 22.04 con Docker, Docker Compose y Nginx.

## 📋 Tabla de Contenidos

1. [Estructura del Proyecto](#estructura)
2. [Requisitos](#requisitos)
3. [Configuración Inicial](#configuración)
4. [Despliegue](#despliegue)
5. [Operación](#operación)
6. [Troubleshooting](#troubleshooting)

---

## 📁 Estructura del Proyecto {#estructura}

```
sigmav2-repo/
├── SIGMAV2-APPFRONT-END/          # Frontend Vue 3
│   └── SIGMAV2-APP/
├── SIGMAV2-SERVICES/              # Backend Spring Boot
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── BD_SIGMAV2/                    # Base de datos
│   └── SIGMAV2_2.sql
├── sigmav2_scanner_mobile/        # App móvil
│
├── docker-compose.yml             # Orquestación completa
├── Dockerfile.frontend            # Build para Frontend
├── Dockerfile.database            # Build para BD
├── .env.example                   # Template de configuración
│
├── nginx/                         # Configuración Nginx
│   ├── nginx.conf                # Config principal
│   ├── sigmav2-frontend.conf     # Frontend routing
│   └── conf.d/
│       └── sigmav2.conf          # API y proxy rules
│
└── scripts/                       # Scripts de operación
    ├── deploy.sh                 # Primer despliegue
    ├── restart.sh                # Reiniciar servicios
    ├── rebuild.sh                # Reconstruir desde cero
    ├── stop.sh                   # Detener servicios
    ├── logs.sh                   # Ver logs
    └── status.sh                 # Estado del sistema
```

---

## ⚙️ Requisitos {#requisitos}

**En servidor Ubuntu 22.04:**

```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Docker Compose
sudo apt-get install docker-compose-plugin

# Git (si no está instalado)
sudo apt-get install git
```

**Verificar instalación:**

```bash
docker --version
docker compose version
```

---

## 🔧 Configuración Inicial {#configuración}

### 1. Clonar Repositorio

```bash
cd /home/deployments
git clone <tu-repo> sigmav2-repo
cd sigmav2-repo
```

### 2. Crear Archivo .env

```bash
cp .env.example .env
nano .env
```

**Valores críticos a cambiar:**

```env
# IP pública del servidor
SERVER_IP=tu-ip-publica.com

# Contraseña MySQL (segura, 32+ caracteres)
DB_ROOT_PASSWORD=genera_aqui_con_openssl

# JWT Secret (seguro, 64+ caracteres)
JWT_SECRET=genera_aqui_con_openssl
```

### 3. Generar Valores Seguros

```bash
# Contraseña segura (32 bytes)
openssl rand -base64 32

# JWT Secret (64 bytes)
openssl rand -base64 64
```

**Ejemplo de valores seguros:**
```
DB_ROOT_PASSWORD=aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890
JWT_SECRET=aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890abcdefghijklmnopqrstuvwxyzABCD
```

---

## 🚀 Despliegue {#despliegue}

### Primer Despliegue (Nuevo)

```bash
./scripts/deploy.sh
```

**Qué hace:**
1. Valida que `.env` esté configurado
2. Verifica variables críticas (no defaults)
3. Levanta todos los servicios
4. Espera a que MySQL esté listo
5. Muestra URLs de acceso

**Tiempo esperado:** 5-10 minutos

**Salida esperada:**
```
✅ .env configurado
✅ Variables de entorno validadas
🚀 Construyendo e iniciando servicios...
✅ MySQL está listo
✅ Despliegue completado

📍 URLs de acceso:
   Frontend: http://tu-ip/sigmav2
   API: http://tu-ip/sigmav2/api
   Health: http://tu-ip/sigmav2/api/health
```

---

## 🔄 Operación {#operación}

### Ver Estado

```bash
./scripts/status.sh
```

Muestra:
- Estado de contenedores (UP/DOWN)
- Uso de CPU/memoria
- Tests de conectividad
- URLs de acceso

### Ver Logs

```bash
# Todos los logs
./scripts/logs.sh

# Solo backend
./scripts/logs.sh backend

# Solo BD
./scripts/logs.sh db

# Frontend
./scripts/logs.sh frontend

# Proxy
./scripts/logs.sh proxy
```

### Reiniciar Servicios

```bash
# Todos
./scripts/restart.sh

# Solo backend
./scripts/restart.sh backend

# Backend (reconstruir)
./scripts/restart.sh backend --build

# Solo frontend
./scripts/restart.sh frontend

# Con rebuild
./scripts/restart.sh frontend --build
```

### Detener Servicios

```bash
./scripts/stop.sh
```

**Nota:** Conserva volúmenes, datos persisten

### Reconstruir desde Cero

```bash
./scripts/rebuild.sh
```

**Qué hace:**
1. Detiene contenedores
2. Elimina imágenes Docker
3. Reconstruye todo
4. Mantiene BD intacta

**Usar cuando:** cambios grandes, limpiar caché

---

## 🐳 Servicios Docker

### Contenedores

| Nombre | Puerto | Función | Estado |
|--------|--------|---------|--------|
| `sigmav2_db` | 3306 | MySQL 8.0 | Interno |
| `sigmav2_backend` | 8080 | Spring Boot | Interno |
| `sigmav2_frontend` | 3000 | Nginx (Vue 3) | Interno |
| `nginx_proxy` | 80, 443 | Proxy principal | Público |

### Volúmenes (Persistencia)

```
sigmav2_mysql_data        → /var/lib/mysql
sigmav2_uploads_data      → /app/uploads
```

Ubicación en host:
```
/var/lib/docker/volumes/sigmav2_mysql_data/_data
/var/lib/docker/volumes/sigmav2_uploads_data/_data
```

---

## 🌐 Rutas de Acceso

```
Frontend:     http://SERVER_IP/sigmav2
API:          http://SERVER_IP/sigmav2/api
Health Check: http://SERVER_IP/sigmav2/api/health
```

### Probar Conectividad

```bash
# Frontend
curl http://localhost/sigmav2

# API Health
curl http://localhost/sigmav2/api/health

# Base de datos
docker exec sigmav2_db mysql -uroot -p$DB_ROOT_PASSWORD -e "SHOW DATABASES;"
```

---

## 💾 Backup y Restauración

### Backup de Base de Datos

```bash
docker exec sigmav2_db mysqldump -uroot -p$DB_ROOT_PASSWORD sigmav2 > backup_$(date +%Y%m%d).sql
```

### Backup de Uploads

```bash
sudo tar -czf sigmav2_uploads_backup_$(date +%Y%m%d).tar.gz \
  /var/lib/docker/volumes/sigmav2_uploads_data/_data
```

### Restaurar BD

```bash
docker exec -i sigmav2_db mysql -uroot -p$DB_ROOT_PASSWORD sigmav2 < backup.sql
```

---

## 🔐 Seguridad

### Variables Secretas

⚠️ **Nunca commiteá:**
```
.env
.env.*.local
```

Verificar `.gitignore`:
```bash
cat .gitignore | grep -E "\.env|\.env\."
```

### Cambiar Secretos

1. Editar `.env` con nuevos valores
2. Reiniciar servicios:
```bash
./scripts/rebuild.sh
```

### Copias de Seguridad de Secretos

Guardar `.env` en lugar seguro (no en git, no en repo):
```bash
cp .env ~/.sigmav2.env.backup
chmod 600 ~/.sigmav2.env.backup
```

---

## 🐛 Troubleshooting {#troubleshooting}

### MySQL no responde

```bash
# Ver logs
./scripts/logs.sh db

# Reiniciar
./scripts/restart.sh db

# Verificar salud
docker exec sigmav2_db mysqladmin ping -h localhost
```

### Frontend en blanco

```bash
# Limpiar caché
./scripts/restart.sh frontend --build

# Verificar logs
./scripts/logs.sh frontend
```

### Backend 401/403 (auth)

```bash
# Verificar JWT_SECRET
grep JWT_SECRET .env

# Comparar con logs
./scripts/logs.sh backend | grep JWT
```

### Puertos ocupados

```bash
# Encontrar proceso en puerto 80
sudo lsof -i :80

# Encontrar proceso en puerto 3306
sudo lsof -i :3306

# Detener si es necesario
sudo kill -9 <PID>
```

### Disco lleno

```bash
# Ver uso
docker system df

# Limpiar
docker system prune -a
docker volume prune
```

### Cambios de código no se ven

```bash
# Reconstruir todo
./scripts/rebuild.sh
```

### Logs muy grandes

```bash
# Ver últimas 100 líneas
./scripts/logs.sh all 100

# Ver en tiempo real
docker logs -f sigmav2_backend
```

---

## 📊 Estadísticas y Monitoreo

### Uso de recursos

```bash
docker stats --no-stream
```

### Historial de cambios

```bash
docker ps -a --no-trunc
```

### Inspeccionar contenedor

```bash
docker inspect sigmav2_backend
```

### Acceder a contenedor

```bash
docker exec -it sigmav2_backend /bin/bash
docker exec -it sigmav2_db mysql -uroot -p$DB_ROOT_PASSWORD
```

---

## 🔄 Flujos Comunes

### Actualizar código Frontend

```bash
cd SIGMAV2-APPFRONT-END/SIGMAV2-APP
git pull origin main
cd ../..
./scripts/restart.sh frontend --build
```

### Actualizar código Backend

```bash
cd SIGMAV2-SERVICES
git pull origin main
cd ..
./scripts/restart.sh backend --build
```

### Actualizar todo

```bash
git pull origin main
./scripts/rebuild.sh
```

### Agregar nuevas migraciones BD

1. Agregar SQL a `BD_SIGMAV2/`
2. Actualizar `SIGMAV2_2.sql`
3. `./scripts/rebuild.sh`

---

## 📞 Soporte

### Logs importantes

```bash
# Todos
./scripts/logs.sh all

# Específicos
./scripts/logs.sh backend
./scripts/logs.sh frontend
./scripts/logs.sh db
./scripts/logs.sh proxy
```

### Estado del sistema

```bash
./scripts/status.sh
```

### Comandos Docker útiles

```bash
# Ver contenedores
docker ps -a --filter "label=com.docker.compose.project=sigmav2-repo"

# Ver volúmenes
docker volume ls | grep sigmav2

# Ver redes
docker network ls | grep sigmav2

# Estadísticas
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

**Última actualización:** 2025-02-18
**Versión:** 1.0

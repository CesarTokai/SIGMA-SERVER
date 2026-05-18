# 🚀 SIGMAV2 - Inicio Rápido de Despliegue

Despliegue en 3 pasos en Ubuntu 22.04.

## 1️⃣ Preparar Configuración

```bash
cd /home/deployments/sigmav2-repo

cp .env.example .env

nano .env
```

**Cambiar valores:**
```
SERVER_IP=tu-ip-publica
DB_ROOT_PASSWORD=genera_con_openssl_rand_-base64_32
JWT_SECRET=genera_con_openssl_rand_-base64_64
```

**Generar secretos:**
```bash
openssl rand -base64 32   # DB_ROOT_PASSWORD
openssl rand -base64 64   # JWT_SECRET
```

## 2️⃣ Desplegar

```bash
./scripts/deploy.sh
```

**Tiempo:** 5-10 minutos  
**Espera:** El script valida y espera a MySQL automáticamente

## 3️⃣ Verificar

```bash
./scripts/status.sh
```

**URLs:**
- Frontend: `http://SERVER_IP/sigmav2`
- API: `http://SERVER_IP/sigmav2/api`
- Health: `http://SERVER_IP/sigmav2/api/health`

---

## 📖 Operación

| Comando | Función |
|---------|---------|
| `./scripts/status.sh` | Ver estado actual |
| `./scripts/logs.sh` | Ver logs (backend, frontend, db, proxy) |
| `./scripts/restart.sh` | Reiniciar servicios |
| `./scripts/stop.sh` | Detener servicios |
| `./scripts/rebuild.sh` | Reconstruir desde cero |

**Ejemplos:**
```bash
./scripts/logs.sh backend          # Ver logs backend
./scripts/restart.sh frontend --build  # Rebuild frontend
./scripts/stop.sh                  # Detener todo
```

---

## 🔧 Actualizar Código

```bash
# Frontend
./scripts/restart.sh frontend --build

# Backend
./scripts/restart.sh backend --build

# Todo
./scripts/rebuild.sh
```

---

## 📚 Documentación Completa

Ver `DEPLOYMENT.md` para:
- Estructura de proyecto
- Troubleshooting
- Backup/Restauración
- Seguridad
- Comandos Docker

---

## ⚠️ Importante

- **Never commit `.env`** (ya en .gitignore)
- Generar valores seguros con `openssl rand`
- Guardá respaldo de `.env` en lugar seguro
- Ver logs si algo falla: `./scripts/logs.sh all`

---

**¿Problemas?** Ver `DEPLOYMENT.md` sección "Troubleshooting"

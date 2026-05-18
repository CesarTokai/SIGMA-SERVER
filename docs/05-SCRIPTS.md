# 🔧 SIGMAV2 - Scripts de Deployment Detallado

Explicación línea por línea de todos los scripts.

---

## 📄 deploy.sh (Primer Despliegue)

Archivo: `scripts/deploy.sh`

### Header y Setup

```bash
#!/bin/bash
```

**Explicación:**
- Shebang: Indica intérprete bash
- Required primera línea
- Permite ejecutar: `./scripts/deploy.sh`

---

```bash
set -e
```

**Explicación:**
- `set -e` = Exit si CUALQUIER comando falla (exit code ≠ 0)
- Detiene ejecución automática en errores
- Evita continuar si hay problemas

**Ejemplo:**
```bash
./scripts/deploy.sh
  ↓
docker-compose up -d (falla)
  ↓
set -e → Script termina inmediatamente
```

**Sin set -e:**
```
docker-compose up -d (falla)
docker exec ...      (ejecuta de todas formas)
Script completa ❌
```

---

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
```

**Explicación:**
- `${BASH_SOURCE[0]}` = Ruta actual script
- `dirname` = Directorio (scripts/)
- `/.." && pwd` = Sube nivel, obtiene path absoluto
- `$SCRIPT_DIR` = Raíz repo (donde está docker-compose.yml)

**Ejemplo:**
```
Script: /home/deployments/sigmav2-repo/scripts/deploy.sh
  ↓
dirname = /home/deployments/sigmav2-repo/scripts
  ↓
/.. = /home/deployments/sigmav2-repo
  ↓
SCRIPT_DIR = /home/deployments/sigmav2-repo
```

---

### Validación .env

```bash
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env no encontrado en $SCRIPT_DIR"
    echo "📝 Copia .env.example a .env y completa los valores:"
    echo "   cp .env.example .env"
    echo "   nano .env"
    exit 1
fi
```

**Explicación:**
- `[ ! -f ]` = Si archivo NO existe
- `-f` = Es archivo regular
- `!` = Negación

**Flujo:**
```
¿.env existe?
  No → Muestra error → exit 1
  Sí → Continúa
```

**exit 1:**
- Termina script con código error
- Comunica a shell: despliegue falló

---

```bash
echo "✅ .env configurado"
export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
```

**Explicación:**
- `cat .env` = Muestra contenido
- `grep -v '^#'` = Excluye líneas comentadas
- `xargs` = Convierte a variables bash
- `export` = Hace variables disponibles a procesos hijos

**Ejemplo:**
```
.env:
  DB_ROOT_PASSWORD=xxxxx
  DB_NAME=sigmav2
  JWT_SECRET=yyyyy
  
Después export:
  $DB_ROOT_PASSWORD = xxxxx
  $DB_NAME = sigmav2
  $JWT_SECRET = yyyyy
  
docker-compose lee estas variables
```

---

### Validación Variables Críticas

```bash
if [ -z "$DB_ROOT_PASSWORD" ] || [ "$DB_ROOT_PASSWORD" = "change_me_securely_32_chars_min" ]; then
    echo "❌ Error: DB_ROOT_PASSWORD no está configurado correctamente"
    exit 1
fi
```

**Explicación:**
- `[ -z ]` = Si variable está vacía
- `||` = O (operador lógico)
- `=` = Comparación string

**Lógica:**
```
¿$DB_ROOT_PASSWORD está vacío?     O
¿$DB_ROOT_PASSWORD = default?      →
  → Error (usuario no cambió valor)
```

**Por qué importante:**
```
Si se ejecuta con defaults:
  ❌ BD sin contraseña segura
  ❌ JWT_SECRET predecible
  ❌ Sistema vulnerable
```

---

### Cambiar a Directorio

```bash
cd "$SCRIPT_DIR"
```

**Explicación:**
- Cambia directorio al root repo
- `docker-compose.yml` está aquí
- `docker-compose` busca archivo en CWD

---

### Docker Compose Up

```bash
docker-compose up -d
```

**Explicación:**
- `docker-compose up` = Arranca servicios
- `-d` = Detached (background, no muestra logs)

**Qué hace:**
```
1. Crea redes (proxy_network, sigmav2_internal)
2. Crea volúmenes (sigmav2_mysql_data, sigmav2_uploads_data)
3. Build imágenes (Frontend: 2-3 min, Backend: 3-5 min, DB: instant)
4. Arranca contenedores en orden (depends_on)
5. Retorna (servicios corren en background)
```

---

### Health Check MySQL

```bash
MAX_RETRIES=40
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if docker exec sigmav2_db mysqladmin ping -h localhost -uroot -p"${DB_ROOT_PASSWORD}" &> /dev/null; then
        echo "✅ MySQL está listo"
        break
    fi
    RETRY=$((RETRY + 1))
    echo "  Intento $RETRY/$MAX_RETRIES..."
    sleep 3
done
```

**Explicación:**
- `while [ condition ]` = Loop mientras condición true
- `RETRY=$((RETRY + 1))` = Incrementa contador
- `sleep 3` = Espera 3 segundos

**Flujo:**
```
Intento 1: ¿MySQL responde? No → Intento 2
Intento 2: ¿MySQL responde? No → Intento 3
...
Intento 14 (40s después): ¿MySQL responde? Sí → Break
```

**Por qué importante:**
```
docker-compose up levanta MySQL
  ↓
MySQL necesita 5-10 segundos para inicializar
  ↓
Si Backend se conecta antes:
  connection_refused → error
  
Con health check:
  Backend NO arranca hasta DB lista
  (depends_on: condition: service_healthy)
```

---

### Timeout Check

```bash
if [ $RETRY -eq $MAX_RETRIES ]; then
    echo "❌ MySQL no respondió después de $MAX_RETRIES intentos"
    exit 1
fi
```

**Explicación:**
- `-eq` = Igual (comparison numérico)
- Si no logró conectar después 40 intentos (120 segundos)
- Error crítico → exit 1

---

### Output Final

```bash
echo ""
echo "✅ Despliegue completado"
echo ""
echo "📍 URLs de acceso:"
echo "   Frontend: http://${SERVER_IP}/sigmav2"
echo "   API: http://${SERVER_IP}/sigmav2/api"
echo "   Health: http://${SERVER_IP}/sigmav2/api/health"
```

**Explicación:**
- Muestra URLs de acceso
- ${SERVER_IP} interpolado de .env

---

## 📄 restart.sh (Reiniciar Servicios)

Archivo: `scripts/restart.sh`

### Parsing Argumentos

```bash
SERVICE=${1:-all}
BUILD_FLAG=${2:-}
```

**Explicación:**
- `${1:-all}` = Primer argumento, default "all" si no se pasa
- `${2:-}` = Segundo argumento, default "" si no se pasa

**Uso:**
```bash
./scripts/restart.sh                 # SERVICE=all, BUILD_FLAG=""
./scripts/restart.sh backend         # SERVICE=backend, BUILD_FLAG=""
./scripts/restart.sh backend --build # SERVICE=backend, BUILD_FLAG="--build"
```

---

### Case Statement

```bash
case "$SERVICE" in
    backend)
        echo "🔄 Reiniciando backend..."
        if [ "$BUILD_FLAG" = "--build" ]; then
            docker-compose up -d --build sigmav2-backend
        else
            docker-compose restart sigmav2-backend
        fi
        echo "✅ Backend reiniciado"
        ;;
```

**Explicación:**
- `case` = Switch/case statement
- `;;` = Fin de case
- `|` = O (multiple patterns)

**Lógica:**
```
¿SERVICE = backend?  Sí
  ¿--build?          Sí → up -d --build (reconstruye)
                     No → restart (solo reinicia)
```

---

## 📄 logs.sh (Ver Logs)

Archivo: `scripts/logs.sh`

```bash
LINES=${2:-50}
```

**Explicación:**
- Segundo argumento = número líneas
- Default 50 líneas

**Uso:**
```bash
./scripts/logs.sh backend           # Últimas 50 líneas
./scripts/logs.sh backend 100       # Últimas 100 líneas
./scripts/logs.sh all 200           # Todo, 200 líneas
```

---

```bash
docker logs --tail=$LINES sigmav2_backend
```

**Explicación:**
- `docker logs` = Muestra stdout/stderr contenedor
- `--tail=$LINES` = Últimas N líneas

**Alternativas:**
```bash
docker logs -f sigmav2_backend      # Follow (en tiempo real)
docker logs --since 10m sigmav2_backend  # Últimos 10 minutos
docker logs --until 5m sigmav2_backend   # Hasta hace 5 minutos
```

---

## 📄 status.sh (Ver Estado)

Archivo: `scripts/status.sh`

```bash
docker-compose ps
```

**Explicación:**
- Muestra estado todos servicios
- Output: NAME, IMAGE, COMMAND, STATUS, PORTS

---

```bash
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

**Explicación:**
- `docker stats` = Uso CPU/memoria de contenedores
- `--no-stream` = Una sola línea (no continuo)
- `--format` = Personaliza output

**Output:**
```
CONTAINER         CPUPERC    MEMUSAGE
sigmav2_db        2.5%       256MB / 1GB
sigmav2_backend   5.1%       512MB / 2GB
sigmav2_frontend  0.2%       25MB / 512MB
nginx_proxy       0.1%       15MB / 256MB
```

---

```bash
echo -n "  Backend health: "
if curl -s http://localhost:8080/api/health > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ No responde"
fi
```

**Explicación:**
- `echo -n` = Sin salto de línea
- `curl -s` = Silent (sin output)
- `> /dev/null 2>&1` = Descarta output y errores
- `$?` = Exit code comando anterior

**Flujo:**
```
curl http://localhost:8080/api/health
  ↓
¿Retorna 200 OK?  Sí → if true → echo "✅"
                  No → if false → echo "❌"
```

---

## 📄 rebuild.sh (Reconstruir Cero)

Archivo: `scripts/rebuild.sh`

```bash
read -p "¿Continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado"
    exit 1
fi
```

**Explicación:**
- `read -p` = Pregunta interactiva
- `-n 1` = Una sola carácter
- `-r` = Raw input (no interpreta backslash)
- `=~` = Regex match
- `^[Ss]$` = Comienza con S o s, nada más

**Flujo:**
```
Pregunta usuario
¿Responde "s" o "S"?  Sí → Continúa
                      No → Cancelado
```

---

```bash
docker-compose down
```

**Explicación:**
- Detiene y elimina contenedores
- Mantiene volúmenes (datos persisten)

**Vs down:**
```
docker-compose stop      → Solo detiene
docker-compose down      → Detiene + elimina contenedores
docker-compose down -v   → Detiene + elimina + volúmenes ⚠️
```

---

```bash
docker rmi sigmav2-server-biuld-sigmav2-backend:latest 2>/dev/null || true
```

**Explicación:**
- `docker rmi` = Remove image
- `2>/dev/null` = Descarta errores
- `|| true` = Si falla, continúa (no exit 1)

**Por qué:**
```
Si imagen no existe:
  docker rmi falla (exit 1)
  Pero queremos continuar (rebuild todo)
  
Con || true:
  Si falla → ignora, continúa
  Si éxito → continúa igual
```

---

## 🔄 stop.sh (Detener)

Archivo: `scripts/stop.sh`

```bash
docker-compose stop
```

**Explicación:**
- Detiene contenedores sin eliminarlos
- Volúmenes persisten
- Puedes reiniciar: `docker-compose start`

---

## 📊 Mejores Prácticas Scripts

### 1. Siempre usar `set -e`

```bash
#!/bin/bash
set -e  ← Crítico
```

Evita continuar en errores

---

### 2. Manejar paths con quotes

```bash
# Malo
cd $SCRIPT_DIR

# Bueno
cd "$SCRIPT_DIR"
```

Espacios en path pueden quebrar

---

### 3. Validar entradas

```bash
# Malo
SERVICE=$1
docker-compose restart $SERVICE

# Bueno
SERVICE=${1:-all}
case "$SERVICE" in
    backend|frontend|all) ... ;;
    *) echo "Error"; exit 1 ;;
esac
```

---

### 4. Usar funciones para código repetido

```bash
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "Error: $1 no instalado"
        exit 1
    fi
}

check_command docker
check_command docker-compose
```

---

### 5. Mostrar progreso

```bash
# Malo
docker-compose up -d

# Bueno
echo "🚀 Iniciando servicios..."
docker-compose up -d
echo "✅ Servicios iniciados"
```

---

## 🧪 Testing Scripts

```bash
# Syntax check (no ejecuta)
bash -n scripts/deploy.sh
bash -n scripts/restart.sh

# Ejecutar con debug
bash -x scripts/deploy.sh  # Muestra cada línea

# Test en entorno limpio
docker-compose down
./scripts/deploy.sh
./scripts/status.sh
```

---

## 🔗 Flujo Completo

```
Usuario:
  ./scripts/deploy.sh
      ↓
Script:
  1. Encuentra raíz repo (cd)
  2. Valida .env existe
  3. Carga variables de .env
  4. Valida secretos no son defaults
  5. docker-compose up -d
  6. Espera MySQL (healthcheck)
  7. Muestra URLs acceso
      ↓
Resultado:
  ✅ Frontend: http://IP/sigmav2
  ✅ API: http://IP/sigmav2/api
  ✅ Servicios corriendo
```

---

**Última actualización:** 2025-02-18  
**Versión:** 1.0

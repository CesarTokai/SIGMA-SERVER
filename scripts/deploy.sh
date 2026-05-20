#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo "================================"
echo "SIGMAV2 - Despliegue Inicial"
echo "================================"

# Verificar que .env existe
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env no encontrado en $SCRIPT_DIR"
    echo "📝 Copia .env.example a .env y completa los valores:"
    echo "   cp .env.example .env"
    echo "   nano .env"
    exit 1
fi

echo "✅ .env configurado"

# Cargar variables de entorno
export $(cat "$ENV_FILE" | grep -v '^#' | xargs)

# Verificar que las variables críticas están configuradas
if [ -z "$DB_ROOT_PASSWORD" ] || [ "$DB_ROOT_PASSWORD" = "change_me_securely_32_chars_min" ]; then
    echo "❌ Error: DB_ROOT_PASSWORD no está configurado correctamente"
    exit 1
fi

if [ -z "$JWT_SECRET" ] || [ "$JWT_SECRET" = "change_me_securely_64_chars_min" ]; then
    echo "❌ Error: JWT_SECRET no está configurado correctamente"
    exit 1
fi

if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" = "tu-ip-publica.com" ]; then
    echo "❌ Error: SERVER_IP no está configurado correctamente"
    exit 1
fi

echo "✅ Variables de entorno validadas"

# Construir e iniciar contenedores
echo ""
echo "🚀 Construyendo e iniciando servicios..."
cd "$SCRIPT_DIR"

docker-compose up -d

# Esperar a que MySQL esté listo
echo ""
echo "⏳ Esperando a que MySQL esté disponible..."
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

if [ $RETRY -eq $MAX_RETRIES ]; then
    echo "❌ MySQL no respondió después de $MAX_RETRIES intentos"
    exit 1
fi

# Verificar que los servicios están corriendo
echo ""
echo "✅ Despliegue completado"
echo ""
echo "📍 URLs de acceso:"
echo "   Frontend: http://${SERVER_IP}/sigmav2"
echo "   API: http://${SERVER_IP}/sigmav2/api"
echo "   Health: http://${SERVER_IP}/sigmav2/api/health"
echo ""
echo "📊 Ver estado: ./scripts/status.sh"
echo "📝 Ver logs: ./scripts/logs.sh"

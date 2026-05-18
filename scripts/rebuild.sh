#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================"
echo "SIGMAV2 - Reconstruir desde Cero"
echo "================================"

echo ""
echo "⚠️  Esto eliminará las imágenes Docker y reconstruirá todo"
echo "    Los datos en BD se conservan"
echo ""

read -p "¿Continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado"
    exit 1
fi

cd "$SCRIPT_DIR"

echo ""
echo "⏹️  Deteniendo servicios..."
docker-compose down

echo "🗑️  Eliminando imágenes Docker..."
docker rmi sigmav2-server-biuld-sigmav2-backend:latest 2>/dev/null || true
docker rmi sigmav2-server-biuld-sigmav2-frontend:latest 2>/dev/null || true
docker rmi sigmav2-server-biuld-sigmav2-db:latest 2>/dev/null || true

echo ""
echo "🚀 Reconstruyendo todo..."
docker-compose up -d --build

echo ""
echo "⏳ Esperando a que MySQL esté listo..."
MAX_RETRIES=40
RETRY=0

export $(cat "$SCRIPT_DIR/.env" | grep -v '^#' | xargs)

while [ $RETRY -lt $MAX_RETRIES ]; do
    if docker exec sigmav2_db mysqladmin ping -h localhost -uroot -p"${DB_ROOT_PASSWORD}" &> /dev/null; then
        echo "✅ MySQL está listo"
        break
    fi
    RETRY=$((RETRY + 1))
    echo "  Intento $RETRY/$MAX_RETRIES..."
    sleep 3
done

echo ""
echo "✅ Reconstrucción completada"
echo ""
echo "./scripts/status.sh"

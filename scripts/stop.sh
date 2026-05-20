#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================"
echo "SIGMAV2 - Detener Servicios"
echo "================================"

cd "$SCRIPT_DIR"

echo "⏹️  Deteniendo todos los servicios..."
docker-compose stop

echo ""
echo "✅ Servicios detenidos"
echo "ℹ️  Los volúmenes y datos persisten"
echo ""
echo "Para iniciar nuevamente:"
echo "   ./scripts/deploy.sh"

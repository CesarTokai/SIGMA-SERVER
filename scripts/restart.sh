#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE=${1:-all}
BUILD_FLAG=${2:-}

echo "================================"
echo "SIGMAV2 - Reiniciar Servicios"
echo "================================"

cd "$SCRIPT_DIR"

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
    frontend)
        echo "🔄 Reiniciando frontend..."
        if [ "$BUILD_FLAG" = "--build" ]; then
            docker-compose up -d --build sigmav2-frontend
        else
            docker-compose restart sigmav2-frontend
        fi
        echo "✅ Frontend reiniciado"
        ;;
    db)
        echo "⚠️  Reiniciando base de datos..."
        docker-compose restart sigmav2-db
        echo "✅ BD reiniciada"
        ;;
    proxy)
        echo "🔄 Reiniciando proxy Nginx..."
        docker-compose restart nginx-proxy
        echo "✅ Proxy reiniciado"
        ;;
    all)
        echo "🔄 Reiniciando todos los servicios..."
        docker-compose restart
        echo "✅ Todos los servicios reiniciados"
        ;;
    *)
        echo "❌ Servicio desconocido: $SERVICE"
        echo "Uso: ./restart.sh [backend|frontend|db|proxy|all] [--build]"
        exit 1
        ;;
esac

echo ""
echo "📊 Estado actual:"
./scripts/status.sh

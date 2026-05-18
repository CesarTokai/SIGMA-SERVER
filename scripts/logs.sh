#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE=${1:-all}
LINES=${2:-50}

cd "$SCRIPT_DIR"

case "$SERVICE" in
    backend)
        echo "📋 Logs Backend (últimas $LINES líneas)"
        docker logs --tail=$LINES sigmav2_backend
        ;;
    frontend)
        echo "📋 Logs Frontend (últimas $LINES líneas)"
        docker logs --tail=$LINES sigmav2_frontend
        ;;
    db)
        echo "📋 Logs Base de Datos (últimas $LINES líneas)"
        docker logs --tail=$LINES sigmav2_db
        ;;
    proxy)
        echo "📋 Logs Nginx Proxy (últimas $LINES líneas)"
        docker logs --tail=$LINES nginx_proxy
        ;;
    all)
        echo "📋 Logs Todos los Servicios (últimas $LINES líneas de cada uno)"
        echo ""
        echo "=== SIGMAV2 DB ==="
        docker logs --tail=$LINES sigmav2_db
        echo ""
        echo "=== SIGMAV2 BACKEND ==="
        docker logs --tail=$LINES sigmav2_backend
        echo ""
        echo "=== SIGMAV2 FRONTEND ==="
        docker logs --tail=$LINES sigmav2_frontend
        echo ""
        echo "=== NGINX PROXY ==="
        docker logs --tail=$LINES nginx_proxy
        ;;
    *)
        echo "❌ Servicio desconocido: $SERVICE"
        echo "Uso: ./logs.sh [backend|frontend|db|proxy|all] [líneas]"
        exit 1
        ;;
esac

echo ""
echo "💡 Para logs en tiempo real, use: docker logs -f <container_name>"

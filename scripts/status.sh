#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================"
echo "SIGMAV2 - Estado del Sistema"
echo "================================"

cd "$SCRIPT_DIR"

echo ""
echo "🐳 CONTENEDORES:"
docker-compose ps

echo ""
echo "💾 VOLÚMENES:"
docker volume ls | grep sigmav2

echo ""
echo "🔗 REDES:"
docker network ls | grep sigmav2

echo ""
echo "📊 USO DE RECURSOS:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "sigmav2|nginx_proxy|CONTAINER"

echo ""
echo "🔍 PRUEBAS DE CONECTIVIDAD:"

# Health check backend
echo -n "  Backend health: "
if curl -s http://localhost:8080/api/health > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ No responde"
fi

# Health check proxy
echo -n "  Frontend acceso: "
if curl -s http://localhost/sigmav2 > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ No responde"
fi

# Database check
echo -n "  BD conexión: "
if docker exec sigmav2_db mysqladmin ping -hlocalhost > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ No responde"
fi

echo ""
echo "📍 URLS DE ACCESO:"
if [ -f "$SCRIPT_DIR/.env" ]; then
    SERVER_IP=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" | cut -d '=' -f2)
    echo "   Frontend: http://$SERVER_IP/sigmav2"
    echo "   API: http://$SERVER_IP/sigmav2/api"
    echo "   Health: http://$SERVER_IP/sigmav2/api/health"
fi

echo ""
echo "📝 COMANDOS ÚTILES:"
echo "   Ver logs: ./scripts/logs.sh"
echo "   Reiniciar: ./scripts/restart.sh"
echo "   Detener: ./scripts/stop.sh"

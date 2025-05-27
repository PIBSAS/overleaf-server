#!/bin/bash

echo "🛑 Deteniendo y eliminando todos los contenedores Docker..."
docker stop $(docker ps -aq) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null

echo "🧼 Eliminando redes Docker no utilizadas..."
docker network prune -f

echo "🗑️ Eliminando volúmenes Docker no utilizados..."
docker volume prune -f

echo "🧹 Eliminando imágenes Docker (esto puede tardar)..."
docker rmi $(docker images -q) 2>/dev/null

echo "📁 Eliminando directorio overleaf-toolkit..."
sudo rm -rf $HOME/overleaf-toolkit

eliminar_cron_inicio() {
    echo "🧹 Eliminando entrada de cron para Overleaf..."
    local CRON_LINE="@reboot cd \$HOME/overleaf-toolkit && ./bin/up -d"

    # Filtra la línea correspondiente y reescribe el crontab sin ella
    crontab -l 2>/dev/null | grep -vF "$CRON_LINE" | crontab -
    echo "✅ Cron eliminado."
}

eliminar_cron_inicio
echo "✅ Entorno limpiado completamente."

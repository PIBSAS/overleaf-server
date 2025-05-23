#!/bin/bash

set -e

echo "🛑 Deteniendo y eliminando todos los contenedores Docker..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

echo "🧼 Eliminando redes Docker no utilizadas..."
docker network prune -f || true

echo "🗑️ Eliminando volúmenes Docker no utilizados..."
docker volume prune -f || true

echo "🧹 Eliminando imágenes Docker (esto puede tardar)..."
docker rmi $(docker images -q) 2>/dev/null || true

echo "📁 Eliminando directorio overleaf-toolkit..."
sudo rm -rf ~/overleaf-toolkit

echo "🧹 Eliminando entrada de cron para Overleaf..."
CRON_LINE="@reboot cd \$HOME/overleaf-toolkit && ./bin/up -d"
(crontab -l 2>/dev/null | grep -vF "$CRON_LINE") | crontab -
echo "✅ Cron eliminado."

echo "🐳 Desinstalando Docker..."
sudo apt-get remove --purge -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io || true
sudo apt-get autoremove -y
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

echo "👥 Quitando al usuario '$USER' del grupo 'docker'..."
sudo gpasswd -d "$USER" docker || true

# Verificar si el grupo docker queda vacío y eliminarlo
if [ -z "$(getent group docker | cut -d: -f4)" ]; then
    echo "🗑️ Eliminando grupo 'docker' (vacío)..."
    sudo groupdel docker
else

echo "🗑️ Eliminando configuración local de Docker (~/.docker)..."
rm -rf ~/.docker

    echo "ℹ️ El grupo 'docker' aún tiene miembros, no se elimina."
fi

echo "✅ Limpieza total completada. Podés reiniciar si quitaste al usuario del grupo 'docker'."

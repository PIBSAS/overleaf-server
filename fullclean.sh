#!/bin/bash

set -e

echo "🧹 Deteniendo y eliminando contenedores de Overleaf..."
docker compose -f "$HOME/overleaf-toolkit/docker-compose.yml" down || true

echo "🧹 Eliminando carpeta overleaf-toolkit..."
rm -rf "$HOME/overleaf-toolkit"

echo "🧹 Eliminando entrada de cron para Overleaf..."
CRON_LINE="@reboot cd \$HOME/overleaf-toolkit && ./bin/up -d"
crontab -l 2>/dev/null | grep -vF "$CRON_LINE" | crontab -

echo "🗑️ Desinstalando Docker..."
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
    echo "ℹ️ El grupo 'docker' aún tiene miembros, no se elimina."
fi

echo "✅ Limpieza total completada. Podés reiniciar si quitaste al usuario del grupo 'docker'."

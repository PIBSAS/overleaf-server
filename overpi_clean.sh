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
sudo rm -rf ~/overleaf-toolkit

echo "✅ Entorno limpiado completamente. Podés ejecutar ./inso.sh"

#!/bin/bash
set -euo pipefail

# Función para verificar grupo docker
check_docker_group() {
    if ! groups | grep -qw docker; then
        echo "[!] Usuario no está en el grupo docker"
        return 1
    fi
    return 0
}

# Configuración inicial de Docker
if ! check_docker_group; then
    echo "=== Instalando dependencias ==="
    sudo apt update
    sudo apt install git -y

    # Detectar sistema operativo
    read -p "¿Usas Ubuntu (u) o Raspberry Pi OS (r)? " os_choice
    case "$os_choice" in
        u|U)
            echo "Instalando Docker para Ubuntu..."
            sudo apt install docker.io docker-compose docker-buildx -y
            ;;
        r|R)
            echo "Instalando Docker para Raspberry Pi..."
            sudo apt install docker.io docker-compose -y
            ;;
        *)
            echo "Opción inválida. Saliendo."
            exit 1
            ;;
    esac

    # Agregar usuario a grupo docker
    sudo usermod -aG docker "$USER"
    echo -e "\n[!] Reinicia el sistema con: sudo reboot"
    echo "Ejecuta este script nuevamente después de reiniciar"
    exit 0
fi

# ==============================
# Continuación después del reinicio
# ==============================

echo "=== Clonando repositorios ==="
if [ ! -d "overleaf" ]; then
    git clone https://github.com/PIBSAS/overleaf.git
fi

if [ ! -d "overleaf-toolkit" ]; then
    git clone https://github.com/overleaf/toolkit.git overleaf-toolkit
fi

echo "=== Construyendo imágenes Docker ARM64 ==="
cd overleaf/server-ce/ || exit
export DOCKER_BUILDKIT=1
docker build -t local-sharelatex-base:arm64 -f Dockerfile-base .

# Modificar Dockerfile
sed -i 's/^FROM \$OVERLEAF_BASE_TAG$/FROM local-sharelatex-base:arm64/' Dockerfile

# Construir imagen principal
cd "$HOME/overleaf" || exit
docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .

echo "=== Configurando Overleaf Toolkit ==="
cd "$HOME/overleaf-toolkit" || exit
./bin/init

# Editar configuración
sed -i \
    -e 's/^# OVERLEAF_IMAGE_NAME=.*$/OVERLEAF_IMAGE_NAME=local-sharelatex:arm64/' \
    -e 's/^OVERLEAF_LISTEN_IP=127.0.0.1$/OVERLEAF_LISTEN_IP=0.0.0.0/' \
    config/overleaf.rc

# Modificar funciones compartidas
sed -i \
    -e 's|image_name="quay.io/sharelatex/sharelatex-pro"|image_name="quay.io/sharelatex/sharelatex-pro:$version"|' \
    -e 's|image_name="sharelatex/sharelatex"|image_name="sharelatex/sharelatex:$version"|' \
    -e 's/export IMAGE="$image_name:$version"/export IMAGE="$image_name"/' \
    lib/shared-functions.sh

echo "=== Iniciando servicios Overleaf ==="
if ! ./bin/up; then
    echo "[!] Error al iniciar, reintentando..."
    docker rm -f overleaf sharelatex redis mongo
    docker rmi local-sharelatex:arm64
    cd "$HOME/overleaf" || exit
    docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .
    cd "$HOME/overleaf-toolkit" || exit
    ./bin/up
fi

echo "=== Instalando paquetes adicionales ==="
docker exec sharelatex bash -c "\
    apt update && \
    apt install -y hunspell-es && \
    tlmgr install babel-spanish hyphen-spanish collection-langspanish && \
    tlmgr update --all"

echo "=== Reiniciando servicios ==="
./bin/restart

# Mostrar información de acceso
IP=$(hostname -I | awk '{print $1}')
echo -e "\n[+] Instalación completada!"
echo -e "Accede a Overleaf en: http://${IP}:80"
echo -e "Crea el usuario admin en: http://${IP}/launchpad\n"

# Overleaf Server
Pasos completos!


# Ubuntu Server 25.04 y Pi OS Lite o Desktop en Raspberry Pi


## Script que utiliza una imagen de docker ya creada con los pasos descriptos mas abajo:
  Primero debemos crear el grupo docker y agregar nuestro usuario al grupo.
- ````
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ````
  En Ubuntu Desktop debemos instalar curl:
  ````
  sudo apt install curl -y
  ````

  Reiniciar y ejecutar la siguiente linea:
- ````
  curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi.sh | bash
  ````


### Limpieza por si te falla algo y queres reintentar:
- ````
  curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi_clean.sh | bash
  ````

#### Pasos que realiza:
- ````
  docker stop $(docker ps -aq) 2>/dev/null
  docker rm $(docker ps -aq) 2>/dev/null
  docker network prune -f
  ````
  Luego:
- ````
  docker rmi $(docker images -q) 2>/dev/null
  ````
  Y:
- ````
  sudo rm -rf ~/overleaf-toolkit
  ````
  Finalmente:
- ````
  docker volume prune -f
  ````


## Script instalación construyendo imagen docker para ARM64:
  Primero debemos crear el grupo docker y agregar nuestro usuario al grupo.
- ````
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ````
  En Ubuntu Desktop debemos instalar curl:
  ````
  sudo apt install curl -y
  ````

  Reiniciar y ejecutar la siguiente linea:
- ````
  curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overleaf.sh | bash
  ````


# Ubuntu Server/Desktop 25.04 y Pi OS Lite o Desktop en Raspberry Pi
  En Ubuntu Desktop necesitamos instalar curl.
  
## Requisitos:
- Git:
  ````
  sudo apt install git curl -y
  ````
- Docker-Compose Ubuntu:
  Docker con root:
- ````
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
  ````
  Docker rootless:
  ````
  sudo apt install uidmap -y
  curl -fsSL https://get.docker.com/rootless | sh
  echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
  echo 'export DOCKER_HOST=unix:///run/user/1000/docker.sock' >> ~/.bashrc
  source ~/.bashrc
  ````
  Si se desea desinstalar:
  ````
  dockerd-rootless-setuptool.sh uninstall
  rootlesskit rm -rf ~/.local/share/docker.
  sed -i '/export PATH=\$HOME\/bin:\$PATH/d' ~/.bashrc
  sed -i '/export DOCKER_HOST=unix:\/\/\/run\/user\/1000\/docker.sock/d' ~/.bashrc
  source ~/.bashrc
  cd ~/bin
  rm -f containerd containerd-shim containerd-shim-runc-v2 ctr docker docker-init docker-proxy dockerd dockerd-rootless-setuptool.sh dockerd-rootless.sh rootlesskit rootlesskit-docker-proxy runc vpnkit
  ````
  
  sudo apt install docker.io docker-compose docker-buildx -y
  ````
- Docker-Compose Pi OS:
  ````
  sudo apt install docker.io docker-compose -y
  ````

- Agregar usuario al grupo docker:
  ````
  sudo usermod -aG docker $USER
  ````
- Reiniciar:
  ````
  reboot
  ````
- Clone Overleaf:
  ````
  gh repo clone overleaf/overleaf
  ````
  or
  ````
  git clone https://github.com/overleaf/overleaf.git
  ````
- Clonar Overleaf Toolkit:
  ````
  git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit
  ````

# Portar a ARM64 para Raspberry Pi:
  
- ````
  latest=$(curl -sSL https://api.github.com/repos/docker/buildx/releases/latest | grep -oP '"tag_name":\s*"v\K[0-9.]+' | head -n1) && \
  mkdir -p ~/.docker/cli-plugins && \
  curl -L "https://github.com/docker/buildx/releases/download/v${latest}/buildx-v${latest}.linux-arm64" -o ~/.docker/cli-plugins/docker-buildx && \
  chmod +x ~/.docker/cli-plugins/docker-buildx
  ````
- ````
  cd overleaf/server-ce/
  ````
- ````
  DOCKER_BUILDKIT=1 docker build -t sharelatex-base:arm64 -f Dockerfile-base .
  ````
  Y si pensamos subirla a Docker Hub indicamos nuestro nombre de usuario(mi usuario en Docker Hub es pibsas):
- ````
  DOCKER_BUILDKIT=1 docker build -t pibsas/sharelatex-base:arm64 -f Dockerfile-base .
  ````
  
- Modificar el ``Dockerfile`` para que use el port creado.
  Localmente:
- ````
  cd "$HOME/overleaf/server-ce"
  sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=sharelatex-base:arm64|' Dockerfile
  awk '/^EXPOSE/ {
      print;
      print "# Paquetes adicionales para soporte en español";
      print "RUN apt-get update && apt-get install -y hunspell-es && \\";
      print "    tlmgr install babel-spanish hyphen-spanish collection-langspanish && \\";
      print "    tlmgr update --all && \\";
      print "    apt-get clean && \\";
      print "    rm -rf /var/lib/apt/lists/*";
      next
  }1' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile
  ````
  Para Docker Hub:
- ````
  cd "$HOME/overleaf/server-ce"
  sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=pibsas/sharelatex-base:arm64|' Dockerfile
  awk '/^EXPOSE/ {
      print;
      print "# Paquetes adicionales para soporte en español";
      print "RUN apt-get update && apt-get install -y hunspell-es && \\";
      print "    tlmgr install babel-spanish hyphen-spanish collection-langspanish && \\";
      print "    tlmgr update --all && \\";
      print "    apt-get clean && \\";
      print "    rm -rf /var/lib/apt/lists/*";
      next
  }1' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile

  ````
- Construimos localmente:
- ````
  cd $HOME/overleaf
  docker build -t sharelatex:arm64 -f server-ce/Dockerfile .
  ````
- Construimos para Docker Hub:
- ````
  cd $HOME/overleaf
  docker build -t pibsas/sharelatex:arm64 -f server-ce/Dockerfile .
  ````
# Iniciamos Overleaf Toolkit para crear el archivo de configuracion:
  ````
  cd && cd ./overleaf-toolkit
  ./bin/init
  ````
- Una vez iniciado editamos `` overleaf.rc ``:
- ````
  rc_file="$TOOLKIT_DIR/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ````
- Descomentar y modificar:
- ````
  # OVERLEAF_IMAGE_NAME=sharelatex/sharelatex
  ````

- Cambiar a :
- ````
  OVERLEAF_IMAGE_NAME=local-sharelatex:arm64
  ````
- Y:
- ``OVERLEAF_LISTEN_IP=127.0.0.1`` a:
  ``
  OVERLEAF_LISTEN_IP=0.0.0.0
  ``

- Modificar:
  ``
  nano overleaf-toolkit/lib/shared-functions.sh
  ``
  
- Agregamos ``:$version`` en el if else:
  - `` image_name="quay.io/sharelatex/sharelatex-pro" ``
  - `` image_name="sharelatex/sharelatex" ``
  
- Y a ``export IMAGE="$image_name:$version" `` se lo quitamos:
  ````
  export IMAGE="$image_name"
  ````
- Quedando asi:
- ````
  function set_server_pro_image_name() {
    local version=$1
    local image_name
    if [[ -n ${OVERLEAF_IMAGE_NAME:-} ]]; then
      image_name="$OVERLEAF_IMAGE_NAME"
    else
      if [[ $SERVER_PRO == "true" ]]; then
        image_name="quay.io/sharelatex/sharelatex-pro:$version"
      else
        image_name="sharelatex/sharelatex:$version"
      fi
    fi
    export IMAGE="$image_name"
    }
  ````

## Levantar Overleaf Toolkit:
- ````
  cd ..
  ./bin/up
  ````

- Si falla remover y levantar:
- ````
  docker rm -f overleaf sharelatex redis mongo
  ````
- ````
  docker rmi local-sharelatex:arm64
  ````
- Si dice que esta en uso detener con la id y repetir:
- ````
  docker stop 30ff1a83345e25
  ````
- ````
  docker rmi local-sharelatex:arm64
  ````
- Reconstruir:
- ````
  cd ../overleaf
  docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .
  ````
- Levantar overleaf:
- ````
  cd ../overleaf-toolkit
  ./bin/up
  ````

# Entrar:
- ````
  http://IP:80/
  ````

Si ves el login, anda aca y crea la cuenta:
- ````
  http://IP/launchpad
  ````

# Actualizar o instalar extras en el docker creado:
- ````
  docker exec -it sharelatex bash
  apt update
  apt install hunspell-es
  tlmgr install babel-spanish hyphen-spanish collection-langspanish
  tlmgr update --all
  exit
  ````
- Reiniciar Overleaf Toolkit:
- ````
  cd ~/overleaf-toolkit
  ./bin/restart
  ````
  O:
- ````
  docker restart sharelatex
  ````

# Limpieza total, desinstalamos todo!:
  - Desinstala Docker, las imagenes, los volumenes, las redes, la carpeta clonada, elimina al usuario del grupo docker, elimina al grupo docker, elimina el cron del booteo que inicia el server al bootear.
- ````
  curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/fullclean.sh | bash
  ````

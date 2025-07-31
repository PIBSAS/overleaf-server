.<h1 align="center"> Overleaf Community Edition Server en Raspberry Pi</h1>

<p align="center">
  <img src="overleaf.png" />
</p>
<h3 align="center"> Pasos completos!</h3>

# Ubuntu Server 25.04 y Pi OS Lite o Desktop en Raspberry Pi


## Script que utiliza una imagen de docker ya creada con los pasos descriptos mas abajo:
  Primero debemos crear el grupo docker y agregar nuestro usuario al grupo. Con este script solo levantamos el servidor listo para usar, usando la imagen que comparto en Docker Hub.
- ````
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ````
  En Ubuntu Desktop debemos instalar curl y gawk:
  ````
  sudo apt install curl gawk -y && sudo reboot
  ````

  Reiniciar y ejecutar la siguiente linea:
- ````
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi.sh)"
  ````


### Limpieza por si te falla algo y queres reintentar:
- ````
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi_clean.sh)"
  ````


## Script instalación construyendo imagen docker para el port ARM64 para Raspberry Pi:
  Primero debemos crear el grupo docker y agregar nuestro usuario al grupo. Con este script hacemos todo el proceso, portar Overleaf a ARM64 y levantar el servidor usando la imagen creada localmente.
- ````
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ````
  Instalar curl y gawk:
  ````
  sudo apt install curl gawk-y && sudo reboot
  ````
  
### Una vez reiniciado el sistema ejecutar la siguiente línea, indicando tu usuario de Docker Hub(o reusas mi imagen):
- ````
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overleaf.sh)"
  ````


# Ubuntu Server/Desktop 25.04 y Pi OS Lite o Desktop en Raspberry Pi
  En Ubuntu Desktop necesitamos instalar curl.
  
## Requisitos:
- Git, Curl, Uidmap, Docker Compose V2:
  ````
  sudo apt install git curl uidmap gawk -y
  ````
  
- Docker:
- ````
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
  ````

- Obtenemos la última version de buildx.
- ````
  latest=$(curl -sSL https://api.github.com/repos/docker/buildx/releases/latest | grep -oP '"tag_name":\s*"v\K[0-9.]+' | head -n1) && \
  mkdir -p ~/.docker/cli-plugins && \
  curl -L "https://github.com/docker/buildx/releases/download/v${latest}/buildx-v${latest}.linux-arm64" -o ~/.docker/cli-plugins/docker-buildx && \
  chmod +x ~/.docker/cli-plugins/docker-buildx
  ````

- Agregar usuario al grupo docker:
  ````
  sudo usermod -aG docker $USER
  ````

- Reiniciar:
  ````
  reboot
  ````


# Portar Overleaf a ARM64 para Raspberry Pi:
- Clonar Overleaf:
  ````
  git clone https://github.com/overleaf/overleaf.git
  ````

- Nos movemos al directorio:
- ```bash
  cd "$HOME/overleaf/server-ce"
  ```

- Modificar el ``Dockerfile-base`` para agregar soporte en español y paquetes adicionales de LaTeX.
- ```bash
  sed -i 's/\(qpdf \)\\/\1hunspell-es \\/' Dockerfile-base
  sed -i '/^[[:space:]]*xetex[[:space:]]*\\$/a\
      babel-spanish \\ \
      hyphen-spanish \\ \
      collection-langspanish \\ \
      newunicodechar \\ \
      float \\ \
      jknapltx \\ \
      tools \\ \
      collection-mathscience \\ \
      mathtools \\ \
      amsmath \\ \
      amsfonts \\ \
      enumitem \\ \
      cancel \\ \
      microtype \\ \
      tcolorbox \\' Dockerfile-base
  ```
  
- Construimos la imagen para ARM64, uso local y Docker Hub:
- ````
  DOCKER_BUILDKIT=1 docker build -t sharelatex-base:arm64 -f Dockerfile-base .
  ````
  
- Modificar el ``Dockerfile`` para que use el port creado.
  Local:
- ````bash
  cd "$HOME/overleaf/server-ce"
  sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=sharelatex-base:arm64|' Dockerfile
  ````
 
- Construimos la imagen principal de sharelatex localmente y para Docker hub:
- ````
  cd $HOME/overleaf
  docker build -t sharelatex -f server-ce/Dockerfile .
  ````
  
#  Subir imagen a Docker Hub (3 pasos)


  1. Iniciar sesión en Docker Hub:
     ````
     docker login
     ````
  2. Etiquetar la imagen, usamos la etiqueta requerida por overleaf-tooolkit e ingresamos nuestro usuario, ejemplo: mi usuario es pibsas en Docker hub:
     ````
     USER_DOCK=pibsas
     TAG=$(cat "$HOME/overleaf-toolkit/lib/config-seed/version")
     docker tag sharelatex $USER_DOCK/sharelatex:$TAG
     ````
  3. Subirla a Docker Hub:
     ````
     docker push $USER_DOCK/sharelatex:$TAG
     ````
     
# Tu imagen estará disponible para reutilizar:
- Haciendo un `` docker pull usuario/sharelatex:tag ``, donde usuario será el tuyo y tag será el indicado por overleaf-toolkit que puede variar con el paso del tiempo, obviamente deberas rehacer la imagen o clonar la version que use el tag que hayas definido. Pero usaremos overleaf-toolkit asi que no usaremos esto:
  ````
  docker pull $USER_DOCK/sharelatex:$TAG
  ````


# Iniciamos Overleaf Server mediante el uso de Overleaf-Toolkit:


- Clonar Overleaf Toolkit:
  ````
  git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit
  ````
  
### Editamos en Overleaf Toolkit el archivo de configuracion:
- Editamos `` overleaf.rc `` Para imagen Local:
- ````
  cd
  DOCKER_IMAGE=sharelatex
  rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ````

- Editamos `` overleaf.rc `` Para Docker Hub:
- ````
  cd
  DOCKER_IMAGE=$USER_DOCK/sharelatex
  rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ````


# Iniciamos Overleaf Toolkit para crear el archivo de configuración:


  ````
  cd && cd ./overleaf-toolkit
  ./bin/init
  ````

## Levantar el servidor:
- ````
  ./bin/up -d
  ````
  Listo!
  
### Si falla remover y levantar:
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
  cd $HOME/overleaf
  docker build -t local-sharelatex -f server-ce/Dockerfile .
  ````
- Levantar overleaf server:
- ````
  cd $HOME/overleaf-toolkit
  ./bin/up -d
  ````

# Entrar:
- ````
  http://IP:80/
  ````

Si ves el login, anda aca y crea la cuenta:
- ````
  http://IP/launchpad
  ````

# Actualizar o instalar extras en el docker creado entrando en su Shell:
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
  cd $HOME/overleaf-toolkit
  ./bin/restart
  ````
  O:
- ````
  docker restart sharelatex
  ````

  
# Agregar a cron para que se inicie el servidor al iniciar la raspberry pi:

  ````
  (crontab -l 2>/dev/null | grep -vF '@reboot cd ~/overleaf-toolkit && ./bin/up -d'; echo '@reboot cd  ~/overleaf-toolkit && ./bin/up -d') | crontab -
  ````


# Si reutilizas la imagen que subiste a Docker Hub los pasos se reducen a esto:


- Cumplir la sección [Requisitos](#requisitos)

# Iniciamos Overleaf Server mediante el uso de Overleaf-Toolkit:

- Clonar Overleaf Toolkit:
  ````
  git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit
  ````

### Editamos en Overleaf Toolkit el archivo de configuracion:

- Editamos `` overleaf.rc ``:
- ````
  cd
  DOCKER_IMAGE=$USER_DOCK/sharelatex
  rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ````
  
# Iniciamos Overleaf Toolkit para crear el archivo de configuracion:
  ````
  cd && cd ./overleaf-toolkit
  ./bin/init
  ````

## Levantar el servidor:
- ````
  ./bin/up -d
  ````
  Listo!

# Creación y subida a Docker Hub de la imagen mediante Script:
- Creamos el grupo docker y agregamos al usuario:
  ````
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ````

- Dependencias del Script:
  ````
  sudo apt install curl gawk -y && sudo reboot
  ````

- Tras haberse reiniciado la Raspberry Pi:
  Nos logueamos en Docker Hub.
  ````
  docker login
  ````

- Una vez iniciada la sesión, ejecutamos el script indicando nuestro nombre de usuario:
  Al estar logueados la imagen se creara y luego se subirá con el tag adecuado
  ````
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/dockerhub.sh)"
  ````


# Limpieza total, desinstalamos todo!:


- Desinstala Docker, las imagenes, los volumenes, las redes, la carpeta clonada, elimina al usuario del grupo docker, elimina al grupo docker, elimina el cron del booteo que inicia el server al bootear.

- ````
  curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/fullclean.sh | bash
  ````


# Visita para más tutoriales: [Luciano's tech](https://sites.google.com/view/lucianostech/docker-compose)


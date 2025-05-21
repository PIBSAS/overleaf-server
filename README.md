# overleaf-server
Pasos completos!


# Ubuntu Server 25.04 Raspberry Pi

## Requisitos:
- Git: ``sudo apt install git -y``
- Docker-Compose: ```sudo apt install docker.io docker-compose docker-buildx -y```
- Add user to docker group: ```sudo usermod -aG docker $USER```
- Reboot: ```reboot```
- fork & Clone Overleaf: ``gh repo clone PIBSAS/overleaf`` or ``git clone https://github.com/PIBSAS/overleaf.git``
- Clone Overleaf Toolkit:
  ````
  git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit
  ````

Portar a ARM64 para Raspberry Pi
- ``cd overleaf/server-ce/``
- ``export DOCKER_BUILDKIT=1``
- ``docker build -t local-sharelatex-base:arm64 -f Dockerfile-base .``
- Modificar el ``Dockerfile`` para que use el port creado.
- ``nano Dockerfile``
- Editamos ``FROM local-sharelatex-base:arm64`` Guardamos
- ``
  cd ~/overleaf
  ``.
- ``
  docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .
  ``
- Iniciamos Overleaf Toolkit para crear el archivo de configuracion:
  ``
  cd & cd ./overleaf-toolkit
  bin/init
  ``
- Una vez iniciado editamos `` overleaf.rc ``
  
  ``
  cd && nano overleaf-toolkit/config/overleaf.rc
  ``
- Descomentar y modificar:
  ``
  # OVERLEAF_IMAGE_NAME=sharelatex/sharelatex
  ``

- y cambiar a :
  ``
  OVERLEAF_IMAGE_NAME=local-sharelatex:arm64
  ``
- Y:
- ``OVERLEAF_LISTEN_IP=127.0.0.1`` a:
  ``
  OVERLEAF_LISTEN_IP=0.0.0.0
  ``

- Modificar:
  ``
  nano overleaf-toolkit/lib/shared-functions.sh
  ``
  
  Agregamos ``:$version`` en el if else lo siguiente:
  - `` image_name="quay.io/sharelatex/sharelatex-pro" ``
  - `` image_name="sharelatex/sharelatex" ``
  - 
  Y a ``export IMAGE="$image_name:$version" `` se lo quitamos:
  ``
  export IMAGE="$image_name"
  ``

  Quedando asi:
  
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

Si falla remover y levantar:
- ``docker rm -f overleaf sharelatex redis mongo``
- ``docker rmi local-sharelatex:arm64``
- Si dice que esta en uso detener con la id y repetir:
- ``docker stop 30ff1a83345e25``
- ``docker rmi local-sharelatex:arm64``
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

Èntrar:
- ``http://IP:80/``

Si ves el login, anda aca y crea la cuenta:
- ``http://IP/launchpad``

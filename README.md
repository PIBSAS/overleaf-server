# overleaf-server
Pasos completos!


# Ubuntu

## Requisitos:
- Git: ``sudo apt install git -y``
- Docker-Compose: ```sudo apt install docker.io docker-compose docker-buildx -y```
- fork & Clone Overleaf: ``gh repo clone PIBSAS/overleaf``
- entrar en la  clonacion: ``cd overleaf``


¡Excelente! Encontramos los `Dockerfile` base y el principal. El archivo `Dockerfile-base` que has compartido es el que construye la imagen `sharelatex/sharelatex-base`, la cual contiene las dependencias básicas y TeX Live. El archivo `Dockerfile` (sin el sufijo `-base`) construirá la imagen `sharelatex/sharelatex` (la "community" image) extendiendo la imagen base.

**Nuestro enfoque ahora será intentar construir estas imágenes para ARM64.**

**Plan de Acción:**

1.  **Intentar construir la imagen base (`sharelatex/sharelatex-base`) para ARM64:**
    * **Modificar `Dockerfile-base`:**
        * **Imagen Base (`FROM`):** `phusion/baseimage:noble-1.0.0` podría tener soporte multiarquitectura. Lo dejaremos por ahora, pero si falla, podríamos intentar una base Ubuntu ARM64 (`arm64v8/ubuntu:noble`).
        * **Dependencias:** Revisaremos las dependencias instaladas con `apt-get install`. La mayoría deberían estar disponibles en ARM64 con el mismo nombre. Sin embargo, si hay alguna específica de AMD64, necesitaremos buscar alternativas o eliminarlas si no son cruciales para la base.
        * **Node.js:** La instalación de Node.js parece usar `deb.nodesource.com`, que generalmente ofrece binarios para diferentes arquitecturas. Debería funcionar.
        * **TeX Live:** La instalación de TeX Live descarga binarios precompilados. Intentaremos mantener la configuración actual, pero si hay problemas, podríamos investigar si hay mirrors de TeX Live optimizados para ARM64 (aunque es poco probable que sea necesario).
    * **Construir la imagen base:** Desde el directorio `server-ce/` del repositorio clonado, intentaremos construir la imagen base:
        ```bash
        docker build -t local-sharelatex-base:arm64 -f ../Dockerfile-base .
        ```
        **Nota:** Ajusta la ruta al `Dockerfile-base` si es necesario.

2.  **Intentar construir la imagen community (`sharelatex/sharelatex`) para ARM64:**
    * **Encontrar el `Dockerfile`:** Busca el archivo `Dockerfile` que construye la imagen `sharelatex/sharelatex`. Debería estar en el mismo directorio o un directorio cercano a `Dockerfile-base`.
    * **Modificar el `Dockerfile`:**
        * **Imagen Base (`FROM`):** Debería comenzar con `FROM sharelatex/sharelatex-base`. La cambiaremos a `FROM local-sharelatex-base:arm64` para que use la imagen base que intentamos construir localmente.
        * **Código y Servicios de Overleaf:** Este `Dockerfile` agregará el código específico de Overleaf. Es aquí donde podrían surgir más problemas de compatibilidad si hay dependencias o binarios precompilados para AMD64. Tendremos que analizar este archivo cuando lo encontremos.
    * **Construir la imagen community:** Desde el directorio `server-ce/`, intentaremos construir la imagen community:
        ```bash
        docker build -t local-sharelatex:arm64 -f ../Dockerfile .
        ```
        **Nota:** Ajusta la ruta al `Dockerfile` si es necesario.

3.  **Configurar el `overleaf-toolkit`:** Una vez que tengamos (o intentemos tener) las imágenes locales construidas, configuraremos el `overleaf-toolkit` para usarlas:
    ```
    OVERLEAF_IMAGE_NAME=local-sharelatex:arm64
    ```
    en `~/overleaf-toolkit/config/overleaf.rc`.

4.  **Intentar iniciar el servidor:**
    ```bash
    cd ~/overleaf-toolkit
    bin/up
    ```

**¡Empecemos por intentar construir la imagen base!** Navega al directorio `server-ce/` dentro del repositorio `overleaf/overleaf` que clonaste y ejecuta el comando de construcción para la imagen base. Observa atentamente la salida para cualquier error. Si hay errores, compártelos conmigo y trataremos de resolverlos.

**Es importante tener paciencia, ya que la construcción de TeX Live puede llevar bastante tiempo.**

¡Adelante con la construcción de la imagen base!

Portar a ARM64 para Raspberry Pi
- cd overleaf/server-ce/
- export DOCKER_BUILDKIT=1
- docker build -t local-sharelatex-base:arm64 -f Dockerfile-base .
- Modificar el ``Dockerfile`` para que use el port creado.
- nano ``Dockerfile``
- Editamos ``FROM local-sharelatex-base:arm64`` Guardamos
- ``cd ~/overleaf``
- ``docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .``
- ``cd && nano overleaf-toolkit/config/overleaf.rc``
- Descomentar: ``# OVERLEAF_IMAGE_NAME=sharelatex/sharelatex``
- y cambiar a : ``OVERLEAF_IMAGE_NAME=local-sharelatex:arm64``
- Modificar:
- ``nano lib/shared-functions.sh``
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

- Cambiar:
- ``nano config/overleaf.rc``
- ``OVERLEAF_LISTEN_IP=127.0.0.1`` a ``OVERLEAF_LISTEN_IP=0.0.0.0``

## Levantar Overleaf:
- ````cd ..
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

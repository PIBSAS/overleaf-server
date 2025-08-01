<h1 align="center"> Overleaf Community Edition Server en Raspberry Pi</h1>

<p align="center">
  <img src="overleaf.png" />
</p>
<h3 align="center"> Pasos completos!</h3>

# Ubuntu Server 25.04 y Pi OS Lite o Desktop en Raspberry Pi


## LOS SIGUIENTES PASOS SON PARA USUARIO FINAL, QUE NO DESEA APRENDER, SOLO INSTALAR Y USAR EL SERVIDOR

---

## Script que utiliza una imagen de docker ya creada (Luciano's tech) con los pasos descriptos mas abajo:

El usuario debe realizar estos pasos si o sí:

- ```bash
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ```
  En Ubuntu Desktop debe instalar curl y gawk, finalmente reinicia el dispositivo. Si no usa Ubuntu saltear este comando:
  ```bash
  sudo apt install curl gawk -y && sudo reboot
  ```

  Tras reiniciar, abrir la Terminal y ejecutar la siguiente línea, puede copiar y pegar:
- ```bash
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi.sh)"
  ```


### Limpieza por si falla algo (se cortó internet, hubo algun falló humano) y necesita reintentar, tras esto, intenta el paso anterior nuevamente:
- ```bash
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi_clean.sh)"
  ```
Disfrute!

----

## LOS SIGUIENTES PASOS SON PARA USUARIO DESARROLLADOR, QUE DESEA APRENDER, Y NO SOLO INSTALAR Y USAR EL SERVIDOR

- Requiere crear una cuenta gratuita en Docker Hub, así obtendras tu usuario y lo usarás en el comando ``USER_DOCK=el_usuario_que_creaste``


---


## Script de instalación y construcción de imagen Docker para el port ARM64 para Raspberry Pi:

  Primero debemos crear el grupo docker y agregar nuestro usuario al grupo. Con este script hacemos todo el proceso, portar Overleaf a ARM64 y levantar el servidor usando la imagen creada localmente.
- ```bash
  sudo groupadd docker
  sudo usermod -aG docker $USER
  ```
  Instalar curl y gawk:
  ```bash
  sudo apt install curl gawk-y && sudo reboot
  ```
  
### Una vez reiniciado el sistema ejecutar la siguiente línea, indicando tu usuario de Docker Hub(o reusas mi imagen dejando USER_DOCK=pibsas):
- ```bash
  USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overleaf.sh)"
  ```

----

## LOS SIGUIENTES PASOS SON PARA USUARIO QUE REALMENTE DESEA APRENDER, NO SOLO EJECUTAR UN SCRIPT.

----


# Ubuntu Server/Desktop 25.04 y Pi OS Lite o Desktop en Raspberry Pi
  En Ubuntu Desktop necesitamos instalar curl.
  
## Requisitos:
- Git, Curl, Uidmap, Docker Compose V2:
  ```bash
  sudo apt install git curl uidmap gawk -y
  ```
  
- ### Docker:

  Debes crearte una cuenta en Docker Hub para obtener un usuario.

- ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
  ```

- Obtenemos la última version de buildx (Opcional).
- ```bash
  latest=$(curl -sSL https://api.github.com/repos/docker/buildx/releases/latest | grep -oP '"tag_name":\s*"v\K[0-9.]+' | head -n1) && \
  mkdir -p ~/.docker/cli-plugins && \
  curl -L "https://github.com/docker/buildx/releases/download/v${latest}/buildx-v${latest}.linux-arm64" -o ~/.docker/cli-plugins/docker-buildx && \
  chmod +x ~/.docker/cli-plugins/docker-buildx
  ```

- Agregar usuario al grupo docker:
  ```bash
  sudo usermod -aG docker $USER
  ```

- Reiniciar:
  ```bash
  reboot
  ```


# Portar Overleaf a ARM64 para Raspberry Pi:
- Clonar Overleaf:
  ```bash
  git clone https://github.com/overleaf/overleaf.git
  ```

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
  
- Construimos la imagen base para ARM64, uso local y Docker Hub:
  Esta imagen contiene la parte principal de Overleaf, ell TexLive y el sistema operativo en el que corre el contenedor, actualmente es Ubuntu noble.

- ```bash
  DOCKER_BUILDKIT=1 docker build -t sharelatex-base:arm64 -f Dockerfile-base .
  ```
  
  Tras construirse, editamos el ``Dockerfile`` para indicarle que use nuestra imagen recién creada.

- Modificar el ``Dockerfile`` para que use el port creado.

- ```bash
  cd "$HOME/overleaf/server-ce"
  sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=sharelatex-base:arm64|' Dockerfile
  ```
 
- Construimos la imagen principal de Overleaf, esto agrega la parte de Overleaf, interfaz web y todo lo que tiene que ver con el servidor, a la base que contiene TeXLive:

- ```bash
  cd "$HOME/overleaf"
  docker build -t sharelatex -f server-ce/Dockerfile .
  ```

Tras construirse exitosamente, si pensamos en usar la imagen localmente en nuestro dispositivo, debemos cambiar la etiqueta ``latest`` por la versión que exige Overleaf Toolkit para levantar el servidor, como esto cambia muy seguido, mejor parametrizarlo, asi siempre servira, mientras no cambien la forma de indicar la versión.

- Cambiamos el Tag latest por el requerido por Overleaf-toolkit:

- ```bash
  TAG=$(cat "$HOME/overleaf-toolkit/lib/config-seed/version")
  docker tag sharlatex:latest sharelatex:${TAG}
  ```
  
  Si solo vas a usar tu imagen de Docker en forma local, salteate el siguiente paso!

  Si vas a subir la imagen a tu Docker Hub continúa con este paso. Debes haber creado la cuenta. 


#  Subir imagen a Docker Hub (3 pasos)


  1. Iniciar sesión en Docker Hub:

   - ```bash
     docker login
     ```
  2. Etiquetar la imagen, usamos la etiqueta requerida por overleaf-tooolkit e ingresamos nuestro usuario, ejemplo: mi usuario es ``pibsas`` en Docker hub:

   - ```bash
     USER_DOCK=pibsas
     TAG=$(cat "$HOME/overleaf-toolkit/lib/config-seed/version")
     docker tag sharelatex $USER_DOCK/sharelatex:$TAG
     ```
  3. Subirla a Docker Hub:

   - ```bash
     docker push $USER_DOCK/sharelatex:$TAG
     ```
     
# Tu imagen estará disponible para reutilizar:

- Haciendo un `` docker pull usuario/sharelatex:tag ``, donde usuario será el tuyo y tag será el indicado por overleaf-toolkit que puede variar con el paso del tiempo, obviamente deberas rehacer la imagen o clonar la version que use el tag que hayas definido. Pero usaremos overleaf-toolkit asi que no usaremos esto:
- ```bash
  docker pull $USER_DOCK/sharelatex:$TAG
  ```

----

## LOS SIGUIENTES PASOS SON TANTO SI USAS TU IMAGEN LOCAL O LA QUE SUBISTE A TU DOCKER HUB

---


# Iniciamos Overleaf Server mediante el uso de Overleaf-Toolkit:

Para ello necesitamos clonar dicho repositorio.

- Clonar Overleaf Toolkit:
  - ```bash
    git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit
    ```
  

### Editamos en Overleaf Toolkit el archivo de configuración:

#### SI USAS TU IMAGEN LOCAL HACE ESTO:

- Editamos `` overleaf.rc ``:
- ```bash
  cd
  DOCKER_IMAGE=sharelatex
  rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ```

----


#### SI USAS TU IMAGEN ALOJADA EN TU CUENTA DE DOCKER HUB HACE ESTO (recordá indicar tu USER_DOCK, si cerraste la terminal, debes volver a declararlo):
- Editamos `` overleaf.rc ``:
- ```bash
  cd
  DOCKER_IMAGE=$USER_DOCK/sharelatex
  rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ```

----


# Iniciamos Overleaf Toolkit para crear el archivo de configuración:


- ```bash
  cd && cd ./overleaf-toolkit
  ./bin/init
  ```

## Levantar el servidor:
- ```bash
  ./bin/up -d
  ```
  Listo a disfrutar realizando documentos de LaTeX!


----


### SI TUVISTE ALGUN PROBEMA:

----


### Si falla remover y levantar:
- ```bash
  docker rm -f overleaf sharelatex redis mongo
  ```

- ```bash
  docker rmi local-sharelatex:arm64
  ```

- Si dice que esta en uso detener con la id y repetir. EJ:
- ```bash
  docker stop 30ff1a83345e25
  ```

- ```bash
  docker rmi local-sharelatex:arm64
  ```

- Reconstruir:
- ```bash
  cd $HOME/overleaf
  docker build -t local-sharelatex -f server-ce/Dockerfile .
  ```

- Levantar overleaf server:
- ```bash
  cd $HOME/overleaf-toolkit
  ./bin/up -d
  ```


---


# Entrar al Server:
- ```bash
  http://IP:80/
  ```

Si ves el login, anda acá y crea la cuenta:
Pones un mail, y una contraseña de mas de 8 carácteres, al no estar configurado el SMTP, no es más que una cuenta local, puede ser inventado el mail.

- ```bash
  http://IP/launchpad
  ```

---

## SI DESEAS AGREGAR OTROS PAQUETES DE LATEX O SOFTWARE NECESARIO DEBES INGRESAR A LA SHELL DEL CONTENEDOR


---


Esto se realiza abriendo otra Terminal e indicando el siguiente comando:

- ```bash
  docker exec -it sharelatex bash
  ```

  Y cerramos el shell con:
- ```bash
  exit
  ```

## Un ejemplo:

### Actualizar o instalar extras en el docker creado entrando en su Shell:

- ```bash
  docker exec -it sharelatex bash
  apt update
  apt install hunspell-es
  tlmgr install babel-spanish hyphen-spanish collection-langspanish
  tlmgr update --all
  exit
  ```

- Reiniciar Overleaf Toolkit:
- ```bash
  cd $HOME/overleaf-toolkit
  ./bin/restart
  ```

  O:
- ```bash
  docker restart sharelatex
  ```

---


## OPCIONAL:

# Agregar a Cron para que se inicie el servidor al iniciar la Raspberry Pi:

- ```bash
  (crontab -l 2>/dev/null | grep -vF '@reboot cd ~/overleaf-toolkit && ./bin/up -d'; echo '@reboot cd  ~/overleaf-toolkit && ./bin/up -d') | crontab -
  ```


# RESUMEN:

### Si reutilizas la imagen que subiste a Docker Hub los pasos se reducen a esto:
Tene en cuenta que Overleaf-toolkit se actualiza seguído, inicie este repo con la versión 5.4.1 y hoy es la versión 5.5.3, lo cuál te obliga a actualizar tus imagenes en una reinstalacción, pero los pasos están bastante parametrizados para sortear esa dificultad, pero siempre tendras que volver a subir tu nueva imagen a tu Docker Hub. Es por eso que este repositorio genera mediante un GitHub Actions una construcción semanal, que si cambia la versión, se crea una nueva imagen, obviamente, esto lo hace una vez a la semana, al momento de crear el Actions estaba la versión 5.5.2, y a las horas estaba la versión 5.5.3, con lo cuál debía esperar 6 días aún para que se ejecutará solo, o hacerlo manualmente, pero eso requiere tiempo. Pero para el usuario "final" eso será un atasco hasta que pasen unos días o lo ejecute manualmente. Para el Usuario avanzado, esto jamás será un problema, porque hará cada paso. Para vos usuario avanzado podes ver en la carpeta ``.github/workflows`` el action.



- Cumplir la sección [Requisitos](#requisitos)


### Iniciamos Overleaf Server mediante el uso de Overleaf-Toolkit:

- Clonar Overleaf Toolkit:

  - ```bash
    git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit
    ```

### Editamos en Overleaf Toolkit el archivo de configuración:

- Editamos `` overleaf.rc ``:

- ```bash
  cd
  DOCKER_IMAGE=$USER_DOCK/sharelatex
  rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
  sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
  sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
  sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"
  ```
  
# Iniciamos Overleaf Toolkit para crear el archivo de configuracion:

- ```bash
  cd && cd ./overleaf-toolkit
  ./bin/init
  ```

## Levantar el servidor:
- ```bash
  ./bin/up -d
  ```
  Listo!


---


# Creación y subida a Docker Hub de las imagenes mediante Script:

- Creamos el grupo docker y agregamos al usuario:
  
  - ```bash
    sudo groupadd docker
    sudo usermod -aG docker $USER
    ```

- Dependencias del Script:
  
  - ```bash
    sudo apt install curl gawk -y && sudo reboot
    ```

- Tras haberse reiniciado la Raspberry Pi:
  Nos logueamos en Docker Hub.
  - ```bash
    docker login
    ```

- Una vez iniciada la sesión, ejecutamos el script indicando nuestro nombre de usuario:
  Al estar logueados la imagen se creara y luego se subirá con el tag adecuado.

  - ```bash
    USER_DOCK=pibsas bash -c "$(curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/dockerhub.sh)"
    ```

Solo te restará iniciar el Overleaf Toollkit.

- ```bash
     cd && cd ./overleaf-toolkit
    ./bin/init
    ./bin/up -d
  ```


---


# EL SIGUIENTE SCRIPT ES UNA LIMPIEZA ABSOLUTA, SI TE ARREPENTISTE Y NO QUERES SABER NADA DE LATEX NI OVERLEAF


# Limpieza total, desinstalamos todo!:


- Desinstala Docker, las imagenes, los volumenes, las redes, la carpeta clonada, elimina al usuario del grupo docker, elimina al grupo docker, elimina el cron del booteo que inicia el server al bootear.

- ```bash
  curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/fullclean.sh | bash
  ```


# Para más tutoriales visita: [Luciano's tech](https://sites.google.com/view/lucianostech/docker-compose)


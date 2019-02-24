#!/usr/bin/env sh

# Set the HOME directory
dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
echo "OK: Your path is $dir"

# Set script params
if [ -z $1 ]; then
  echo "WARNING: No domain was set."
else
  DOMAIN=$1
  export DOMAIN
  SERVER_HOSTNAME=$DOMAIN

fi

detect_os () {

  if cat /etc/*release | grep ^NAME | grep CentOS; then
      echo "==============================================="
      echo "Installing packages on CentOS"
      echo "==============================================="
      YUM_PACKAGE_NAME="true"
      export YUM_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Amazon; then
      echo "==============================================="
      echo "Installing packages on Amazon Linux"
      echo "==============================================="
      YUM_PACKAGE_NAME="true"
      export YUM_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Red; then
      echo "==============================================="
      echo "Installing packages on RedHat"
      echo "==============================================="
      YUM_PACKAGE_NAME="true"
      export YUM_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Fedora; then
      echo "================================================"
      echo "Installing packages on Fedorea"
      echo "================================================"
      YUM_PACKAGE_NAME="true"
      export YUM_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Ubuntu; then
      echo "==============================================="
      echo "Installing packages on Ubuntu"
      echo "==============================================="
      DEB_PACKAGE_NAME="true"
      export DEB_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Debian ; then
      echo "==============================================="
      echo "Installing packages on Debian"
      echo "==============================================="
      DEB_PACKAGE_NAME="true"
      export DEB_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Mint ; then
      echo "============================================="
      echo "Installing packages on Mint"
      echo "============================================="
      DEB_PACKAGE_NAME="true"
      export DEB_PACKAGE_NAME
  elif cat /etc/*release | grep ^NAME | grep Knoppix ; then
      echo "================================================="
      echo "Installing packages on Kanoppix"
      echo "================================================="
      DEB_PACKAGE_NAME="true"
      export DEB_PACKAGE_NAME
  else
      echo "OS NOT DETECTED, couldn't install package service"
      exit 1;
  fi

}

#---------------------------------------------------------------------
# update the host operating system
#---------------------------------------------------------------------

install_deb () {

  echo "OK: Installing OS updates..."

  # Update the base OS
  apt-get upgrade -y
  # Clean out current install
  apt-get remove docker docker-engine docker.io

  # Install software
  apt-get install \
          apt-transport-https \
          ca-certificates \
          curl \
          dnsutils \
          software-properties-common -y \
          git

  # Install Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  add-apt-repository \
          "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) \
          stable"
  apt-get update -y
  apt-get install docker-ce -y

  # Start Docker
  systemctl enable docker
  systemctl start docker

}

install_yum () {

  echo "OK: Installing OS updates..."
  # Update the base OS
  yum install update -y
  yum install epel-release -y
  yum -y install docker bind-utils htop
  # Start Docker
  service docker start

}

install_docker () {

  # Install Docker and Compose
  curl -L "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  # Pull Docker images
  echo "OK: Downloding Docker services..."
  docker pull alpine:3.8
  docker pull mariadb
  docker pull redis:alpine
  docker pull certbot/certbot

}

install_host () {

  # Set ENV variables for hostname
  if [ -f $dir/host.txt ]; then

    # User has supplied host information in advance of setup.
    echo "OK: $dir/host.txt is present. Continue..."
    DNS_USERDATA=yes
    export DNS_USERDATA
    SERVER_HOSTNAME=${1}
    export SERVER_HOSTNAME

  else

    # User has NOT supplied any host info. We will attempt to create it for them
    echo "WARNING: The host is not set. Make sure $dir/host.txt exists and contains your domain variable SERVER_HOSTNAME=whateveryourhost.com" > $dir/HOSTERROR.txt

    # We need to lookup the public IP
    SERVER_IP=$(curl http://ifconfig.me/ip)
    printf "%s " SERVER IP is $SERVER_IP
    SERVER_HOSTNAME=$(dig +noall +answer -x $SERVER_IP @8.8.8.8 | awk '{ print $(NF) }' | sed -r 's/\.$//' )
    echo "SERVER_HOSTNAME=$SERVER_HOSTNAME" > $dir/host.txt

    # We do not have any user supplied host information
    DNS_USERDATA=no
    export DNS_USERDATA
    export SERVER_HOSTNAME

    if [ -z $SERVER_HOSTNAME ]; then
      echo "ERROR: We could not determine your hostname.
            This could be due to your hosting provider not setting
            a default DNS entry for the server IP. Please create a
            host file here $dir/host.txt that contains
            SERVER_HOSTNAME=whateveryourhost.com" && exit 1
    else
      echo "SERVER_HOSTNAME=$SERVER_HOSTNAME" > $dir/host.txt
      # If we do not have a proper host/ip combination, we cant call Letsencrypt so we default to self-signs SSL certs
      if [ ! -f $dir/wordpress.yml ]; then cp $dir/wordpress-no-ssl.yml $dir/wordpress.yml; fi
    fi

  fi

}

#---------------------------------------------------------------------
# configure the docker compose yaml file
#---------------------------------------------------------------------

install_yaml () {

  #source $dir/host.txt
  echo "OK: Setting up YAML configuration files with a hostname set to $1......"

  INSTANCE_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | sed 1q)

  if [ ! -f $dir/.env ]; then
    if [ -z ${INSTANCE_TYPE} ]; then INSTANCE_TYPE=wordpress; fi
    # Generate a password for wordpress and mariadb
    if [ -z ${WORDPRESS_DB_ROOT_PASSWORD} ]; then WORDPRESS_DB_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | sed 1q) && export WORDPRESS_DB_ROOT_PASSWORD; fi
    if [ -z ${WORDPRESS_DB_PASSWORD} ]; then WORDPRESS_DB_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 1q) && export WORDPRESS_DB_PASSWORD; fi
    if [ -z ${WORDPRESS_ADMIN_PASSWORD} ]; then WORDPRESS_ADMIN_PASSWORD=${INSTANCE_ID} && export WORDPRESS_ADMIN_PASSWORD; fi
    if [ -z ${AUTH_KEY} ]; then AUTH_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export AUTH_KEY; fi
    if [ -z ${AUTH_SALT} ]; then AUTH_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export AUTH_SALT; fi
    if [ -z ${LOGGED_IN_KEY} ]; then LOGGED_IN_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export LOGGED_IN_KEY; fi
    if [ -z ${LOGGED_IN_SALT} ]; then LOGGED_IN_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export LOGGED_IN_SALT; fi
    if [ -z ${NONCE_KEY} ]; then NONCE_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export NONCE_KEY; fi
    if [ -z ${SECURE_AUTH_KEY} ]; then SECURE_AUTH_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export SECURE_AUTH_KEY; fi
    if [ -z ${SECURE_AUTH_SALT} ]; then SECURE_AUTH_SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) && export SECURE_AUTH_SALT; fi

    WORDPRESS_ADMIN=admin
    WORDPRESS_DB_USER=wordpress
    export WORDPRESS_ADMIN
    export WORDPRESS_DB_USER

  else
    echo "OK: .env is already installed"
  fi

}

#---------------------------------------------------------------------
# configure and install runtime environment variables
#---------------------------------------------------------------------

install_env () {

  echo "OK: Setting up Docker ENV file with a hostname set to $1..."

  # If the ENV file exists we want to use it rather that overwrite
  if [ ! -f $dir/.env ]; then
    {
          echo '# Nginx Server'
          echo 'NGINX_SERVER_NAME={{SERVER_HOSTNAME}}'
          echo 'NGINX_APP_PLUGIN=wordpress'
          echo 'NGINX_CONFIG=php'
          echo 'NGINX_DEV_INSTALL={{INSTALL_DEV_SSL}}'
          echo 'NGINX_DOCROOT=/usr/share/nginx/html'
          echo
          echo '# Wordpress Settings'
          echo 'WORDPRESS_DB_ROOT_PASSWORD={{WORDPRESS_DB_ROOT_PASSWORD}}'
          echo 'WORDPRESS_DB_PASSWORD={{WORDPRESS_DB_PASSWORD}}'
          echo 'WORDPRESS_DB_NAME=wordpress'
          echo 'WORDPRESS_DB_USER=wordpress'
          echo 'WORDPRESS_ADMIN=admin'
          echo 'WORDPRESS_VERSION=latest'
          echo 'WORDPRESS_ADMIN_PASSWORD={{WORDPRESS_ADMIN_PASSWORD}}'
          echo 'WORDPRESS_ADMIN_EMAIL=manticarodrigo@gmail.com'
          echo 'AUTH_KEY={{AUTH_KEY}}'
          echo 'AUTH_SALT={{AUTH_SALT}}'
          echo 'LOGGED_IN_KEY={{LOGGED_IN_KEY}}'
          echo 'LOGGED_IN_SALT={{LOGGED_IN_SALT}}'
          echo 'NONCE_KEY={{NONCE_KEY}}'
          echo 'SECURE_AUTH_KEY={{SECURE_AUTH_KEY}}'
          echo 'SECURE_AUTH_SALT={{SECURE_AUTH_SALT}}'
          echo 'WP_DEBUG=false'
          echo
          echo '# PHP Configuration'
          echo 'APP_DOCROOT=/usr/share/nginx/html'
          echo 'PHP_START_SERVERS=8'
          echo 'PHP_MIN_SPARE_SERVERS=4'
          echo 'PHP_MAX_SPARE_SERVERS=8'
          echo 'PHP_MEMORY_LIMIT=128'
          echo 'PHP_OPCACHE_ENABLE=1'
          echo 'PHP_OPCACHE_MEMORY_CONSUMPTION=64'
          echo 'PHP_MAX_CHILDREN=8'
          echo
          echo '# Upstream Servers'
          echo 'WORDPRESS_DB_HOST=mariadb:3306'
          echo 'WORDPRESS_REDIS_HOST=redis:6379'
          echo 'NGINX_PROXY_UPSTREAM=localhost:8080'
          echo 'REDIS_UPSTREAM=redis:6379'
          echo 'PHP_FPM_UPSTREAM=php:9000'
          echo 'PHP_FPM_PORT=9000'
    } | tee $dir/.env

    # Set the variables for the ENV file
    sed -i 's|{{SERVER_HOSTNAME}}|'${1:?}'|g' $dir/.env
    sed -i 's|{{WORDPRESS_DB_ROOT_PASSWORD}}|'${2:?}'|g' $dir/.env
    sed -i 's|{{WORDPRESS_DB_PASSWORD}}|'${3:?}'|g' $dir/.env
    sed -i 's|{{WORDPRESS_ADMIN_PASSWORD}}|'${4:?}'|g' $dir/.env
    sed -i 's|{{AUTH_KEY}}|'${5:?}'|g' $dir/.env
    sed -i 's|{{AUTH_SALT}}|'${6:?}'|g' $dir/.env
    sed -i 's|{{LOGGED_IN_KEY}}|'${7:?}'|g' $dir/.env
    sed -i 's|{{LOGGED_IN_SALT}}|'${8:?}'|g' $dir/.env
    sed -i 's|{{NONCE_KEY}}|'${9:?}'|g' $dir/.env
    sed -i 's|{{SECURE_AUTH_KEY}}|'${10:?}'|g' $dir/.env
    sed -i 's|{{SECURE_AUTH_SALT}}|'${11:?}'|g' $dir/.env

  fi

}

#---------------------------------------------------------------------
# install lets encrypt resources
#---------------------------------------------------------------------

install_letsencrypt () {

  #source $dir/host.txt

  echo "OK: Checking for Letsencrypt install on host ${1}..."

  # First, we check to see if Letsencrypt is already setup on this host
  if [ -f /etc/letsencrypt/live/${1}/fullchain.pem ] && [ ${2} = yes ]; then
    echo "OK: We found Letsencrypt SSL certs within /etc/letsencrypt/live/${1}. We will use these certs and set the use of self-signed SSL certs for ${1} to false..."

    INSTALL_DEV_SSL=false
    export INSTALL_DEV_SSL

  # Next, we check to see if Letsencrypt should be installed but is not.
elif [ ! -f /etc/letsencrypt/live/${1}/fullchain.pem ] && [ ${2} = yes ]; then
    echo "OK: Letsencrypt needs to be installed on this host. Running certbot..."
    docker_command=$(docker run --rm -p 80:80 -p 443:443 --privileged --name certbot -v "/etc/letsencrypt:/etc/letsencrypt" -v "/var/lib/letsencrypt:/var/lib/letsencrypt" certbot/certbot certonly -n --debug --agree-tos --email manticarodrigo@gmail.com --standalone -d ${1})
    echo "OK: Certbot output is: $docker_command"

    INSTALL_DEV_SSL=false
    export INSTALL_DEV_SSL

  # Lastly, if all out attempts to install Letsencrypt fail, we revert to self-signed SSL certs.
  else
    echo "OK: We could not locate your Letsencrypt SSL certs within /etc/letsencrypt/live/${1}. Installing self-signed SSL certs instead..."

    INSTALL_DEV_SSL=true
    export INSTALL_DEV_SSL

  fi

  # Set the variables for the Docker compose file
  sed -i 's|{{INSTALL_DEV_SSL}}|'${INSTALL_DEV_SSL:?}'|g' $dir/.env
  sleep 5

}

#---------------------------------------------------------------------
# start containers
#---------------------------------------------------------------------

start_containers () {

  echo "OK: Starting Docker services for host ${1}..."
  # Start containers...
  /usr/local/bin/docker-compose -f $dir/docker-compose.yml up -d --remove-orphans

}

#---------------------------------------------------------------------
# run all functions
#---------------------------------------------------------------------

run() {

  detect_os
  if [ $YUM_PACKAGE_NAME = 'true' ]; then install_yum; elif [ $DEB_PACKAGE_NAME = 'true' ]; then install_deb; else echo "OS NOT DETECTED, couldn't install package service" && exit 1; fi
  install_docker
  install_host $SERVER_HOSTNAME
  install_yaml $SERVER_HOSTNAME $WORDPRESS_ADMIN_PASSWORD $WORDPRESS_DB_PASSWORD
  install_env $SERVER_HOSTNAME $WORDPRESS_DB_ROOT_PASSWORD $WORDPRESS_DB_PASSWORD $WORDPRESS_ADMIN_PASSWORD $AUTH_KEY $AUTH_SALT $LOGGED_IN_KEY $LOGGED_IN_SALT $NONCE_KEY $SECURE_AUTH_KEY $SECURE_AUTH_SALT
  install_letsencrypt $SERVER_HOSTNAME $DNS_USERDATA
  start_containers $SERVER_HOSTNAME

  echo "OK: Wordpress system environment installation is now complete."

}

# If .env is present, it indicates a previous install. We will exit vs overwrite.
if [ ! -f $dir/.env ]; then run && exit 0; else echo "OK: Wordpress already installed. Exiting installer." && exit 0; fi

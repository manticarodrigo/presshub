#!/usr/bin/env bash

#---------------------------------------------------------------------
# start image compression and watchers in the media uploads directory
#---------------------------------------------------------------------

function convert_media() {

  echo "Starting media upload compression... "
  
	/usr/bin/webp-convert ${APP_DOCROOT}/wp-content/uploads

}

#---------------------------------------------------------------------
# start image compression and watchers in the media uploads directory
#---------------------------------------------------------------------

function watch_media() {

  echo "Starting media upload watchers... "
	/usr/bin/webp-watchers ${APP_DOCROOT}/wp-content/uploads

}

#---------------------------------------------------------------------
# run all the functions to start the services
#---------------------------------------------------------------------

function run() {
  convert_media
  watch_media
}

run

# exec "$@"
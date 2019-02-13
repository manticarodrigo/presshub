FROM alpine:3.8
MAINTAINER Rodrigo Mantica (manticarodrigo@gmail.com)

RUN apk update && \
    apk add --no-cache --update \
    inotify-tools \
    libwebp \
    libwebp-tools \
    ca-certificates \
    grep \
    bash \
    && rm -rf /var/cache/apk/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY webp-convert.sh /usr/bin/webp-convert
COPY webp-watchers.sh /usr/bin/webp-watchers

RUN chmod +x /docker-entrypoint.sh /usr/bin/webp-convert /usr/bin/webp-watchers

ENTRYPOINT ["/docker-entrypoint.sh"]
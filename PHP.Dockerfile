FROM php:7.4-fpm-alpine

LABEL maintainer="Ruslan Gindullin <ruslan@giru.ru>"

ENV TZ Europe/Moscow

ARG OPENRESTY_VERSION
ENV OPENRESTY_VERSION openresty-1.17.8.2

ENV JWT_KEY KEY

ENV PHP_INDEX_DIR /www
ENV PHP_INDEX_FILE index.php

ENV PASSWORD_RECOVERIES_PER_DAY 2

RUN apk --update --no-cache add \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    imagemagick \
    imagemagick-dev \
    perl \
    curl \
    supervisor \
    build-base \
    autoconf \
    tzdata \
    dnsmasq \
    icu-dev \
    luajit \
    gettext && \
    mkdir -p /tmp/src /var/log/nginx /etc/nginx/conf.d /www && \
    cd /tmp/src && \
    curl https://openresty.org/download/${OPENRESTY_VERSION}.tar.gz -s --output ${OPENRESTY_VERSION}.tar.gz && \
    tar -zxf ${OPENRESTY_VERSION}.tar.gz && \
    cd /tmp/src/${OPENRESTY_VERSION} && \
    ./configure \
        --with-pcre-jit \
        --user=www-data \
        --group=www-data \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --with-http_gzip_static_module \
        --with-http_iconv_module && \
    make && \
    make install && \
    pecl channel-update pecl.php.net && \
    pecl install imagick mongodb apcu && \
    docker-php-ext-configure intl && \
    docker-php-ext-enable imagick mongodb apcu && \
    docker-php-ext-install pdo_mysql bcmath sockets intl opcache && \
    apk del build-base autoconf && \
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/src && \
    ln -s /usr/local/openresty/bin/opm /usr/local/bin/opm && \
    ln -s /usr/local/openresty/bin/resty /usr/local/bin/resty

RUN opm get ledgetech/lua-resty-http SkyLothar/lua-resty-jwt

EXPOSE 80 8080

STOPSIGNAL SIGTERM

COPY lua/includes /usr/local/openresty/site/lualib/nginx/auth
COPY lua/*.lua /usr/local/openresty/nginx/auth/
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/
COPY proxy.php.conf.template /etc/nginx/conf.d/proxy.conf.template
COPY supervisord.conf /etc/supervisord.conf
COPY php.ini /usr/local/etc/php/php.ini
COPY fpm.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY openresty.sh /
ADD --chown=www-data:www-data www /www

RUN curl -sS https://getcomposer.org/installer | php -- \
    --filename=composer \
    --install-dir=/usr/local/bin

WORKDIR /www

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
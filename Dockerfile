FROM alpine:latest

LABEL maintainer="Ruslan Gindullin <ruslan@giru.ru>"

ENV TZ Europe/Moscow

ARG OPENRESTY_VERSION
ENV OPENRESTY_VERSION openresty-1.15.8.2

ENV JWT_KEY KEY

ENV PASSWORD_RECOVERIES_PER_DAY 2

RUN apk --update --no-cache add \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    perl \
    curl \
    build-base \
    autoconf \
    tzdata \
    dnsmasq \
    icu-dev \
    gettext \
    luajit && \
    mkdir -p /tmp/src /var/log/nginx /etc/nginx/conf.d && \
    cd /tmp/src && \
    curl https://openresty.org/download/${OPENRESTY_VERSION}.tar.gz -s --output ${OPENRESTY_VERSION}.tar.gz && \
    tar -zxf ${OPENRESTY_VERSION}.tar.gz && \
    cd /tmp/src/${OPENRESTY_VERSION} && \
    ./configure \
        --with-pcre-jit \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --with-http_gzip_static_module \
        --with-http_iconv_module && \
    make && \
    make install && \
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
COPY proxy.conf.template /etc/nginx/conf.d/
COPY openresty.sh /

CMD ["/openresty.sh"]

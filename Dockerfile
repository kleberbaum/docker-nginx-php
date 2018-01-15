FROM alpine:latest

LABEL description "nginx is a full-featured open-source webserver and php is kinda cancer"

# this fork is maintained by kleberbaum
MAINTAINER Florian Kleber <kleberbaum@erebos.xyz>

ARG BUILD_CORES

ARG NGINX_VER=1.13.7
ARG PHP_VER=7.1.13
ARG LIBICONV_VERSION=1.15

ARG PHP_MIRROR=http://ch1.php.net

ARG NGINX_CONF=" \
    --prefix=/nginx \
    --sbin-path=/usr/local/sbin/nginx \
    --http-log-path=/nginx/logs/access.log \
    --error-log-path=/nginx/logs/error.log \
    --pid-path=/nginx/run/nginx.pid \
    --lock-path=/nginx/run/nginx.lock \
    --with-threads \
    --with-file-aio \
    --without-http_geo_module \
    --without-http_autoindex_module \
    --without-http_split_clients_module \
    --without-http_memcached_module \
    --without-http_empty_gif_module \
    --without-http_browser_module"

ARG PHP_CONF=" \
    --prefix=/usr \
    --libdir=/usr/lib/php \
    --datadir=/usr/share/php \
    --sysconfdir=/php/etc \
    --localstatedir=/php/var \
    --with-pear=/usr/share/php \
    --with-config-file-scan-dir=/php/conf.d \
    --with-config-file-path=/php \
    --with-pic \
    --disable-short-tags \
    --without-readline \
    --enable-bcmath=shared \
    --enable-fpm \
    --disable-cgi \
    --enable-mysqlnd \
    --enable-mbstring \
    --with-curl \
    --with-libedit \
    --with-openssl \
    --with-iconv=/usr/local \
    --with-gd \
    --with-jpeg-dir \
    --with-png-dir \
    --with-webp-dir \
    --with-xpm-dir=no \
    --with-freetype-dir \
    --enable-gd-native-ttf \
    --disable-gd-jis-conv \
    --with-zlib"

ARG PHP_EXT_LIST=" \
    mysqli \
    ctype \
    dom \
    json \
    xml \
    mbstring \
    posix \
    xmlwriter \
    zip \
    zlib \
    sqlite3 \
    pdo_sqlite \
    pdo_pgsql \
    pdo_mysql \
    pcntl \
    curl \
    fileinfo \
    bz2 \
    intl \
    mcrypt \
    openssl \
    ldap \
    simplexml \
    pgsql \
    ftp \
    exif \
    gmp \
    imap"

ARG CUSTOM_BUILD_PKGS=" \
    freetype-dev \
    openldap-dev \
    gmp-dev \
    libmcrypt-dev \
    icu-dev \
    postgresql-dev \
    libpng-dev \
    libwebp-dev \
    gd-dev \
    libjpeg-turbo-dev \
    libxpm-dev \
    libedit-dev \
    libxml2-dev \
    libressl-dev \
    libbz2 \
    sqlite-dev \
    imap-dev"

ARG CUSTOM_PKGS=" \
    freetype \
    openldap \
    gmp \
    libmcrypt \
    bzip2-dev \
    icu \
    libpq \
    c-client"

COPY rootfs /

RUN echo "## Installing base ##" && \
    echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories && \
    apk upgrade --update-cache --available && \
    \
    NB_CORES=${BUILD_CORES-$(getconf _NPROCESSORS_CONF)} && \
    BUILD_DEPS=" \
    linux-headers \
    libtool \
    build-base \
    pcre-dev \
    zlib-dev \
    wget \
    gnupg \
    autoconf \
    gcc \
    g++ \
    libc-dev \
    make \
    pkgconf \
    curl-dev \
    ca-certificates \
    ${CUSTOM_BUILD_PKGS}" && \
    apk add --force \
    ${BUILD_DEPS} \
    s6 \
    su-exec \
    curl \
    libedit \
    libxml2 \
    libressl \
    libwebp \
    gd \
    pcre \
    zlib \
    ${CUSTOM_PKGS} \
    && echo "## Source downloading ##" \
    && wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz -O /tmp/nginx-${NGINX_VER}.tar.gz \
    && wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz.asc -O /tmp/nginx-${NGINX_VER}.tar.gz.asc \
    && wget ${PHP_MIRROR}/get/php-${PHP_VER}.tar.gz/from/this/mirror -O /tmp/php-${PHP_VER}.tar.gz \
    && wget ${PHP_MIRROR}/get/php-${PHP_VER}.tar.gz.asc/from/this/mirror -O /tmp/php-${PHP_VER}.tar.gz.asc \
    && wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz -O /tmp/libiconv-${LIBICONV_VERSION}.tar.gz \
    && mkdir -p /php/conf.d \
    && mkdir -p /usr/src \
    && tar xzf /tmp/nginx-${NGINX_VER}.tar.gz -C /usr/src \
    && tar xzvf /tmp/php-${PHP_VER}.tar.gz -C /usr/src \
    && tar xzf /tmp/libiconv-${LIBICONV_VERSION}.tar.gz -C /usr/src \
    \
    && echo "## Source downloading ##" \
    && cd /usr/src/nginx-${NGINX_VER} \
    && ./configure --with-cc-opt="-O3 -fPIE -fstack-protector-strong" ${NGINX_CONF} \
    && make -j ${NB_CORES} \
    && make install \
    \
    && echo "## GNU Libiconv installation ##" \
    && cd /usr/src/libiconv-${LIBICONV_VERSION} \
    && ./configure --prefix=/usr/local \
    && make && make install && libtool --finish /usr/local/lib \
    \
    && echo "## PHP installation ##" \
    && mv /usr/src/php-${PHP_VER} /usr/src/php \
    && cd /usr/src/php \
    && ./configure CFLAGS="-O3 -fstack-protector-strong" ${PHP_CONF} \
    && make -j ${NB_CORES} \
    && make install \
    \
    && echo "## Strip, clean, install modules ##" \
    && { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    && make clean \
    && chmod u+x /usr/local/bin/* /etc/s6.d/*/* \
    && docker-php-ext-install ${PHP_EXT_LIST} \
    && apk del ${BUILD_DEPS} \
    && rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*
    && mkdir -p /nginx/logs /nginx/run /php/php-fpm.d /php/logs /php/run /php/session

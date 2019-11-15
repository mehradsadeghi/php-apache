FROM php:7.2-apache

RUN apt-get update --fix-missing

# 1. development packages
RUN apt-get install -y \
    git \
    zip \
    curl \
    sudo \
    unzip \
    nano \
    libicu-dev \
    libbz2-dev \
    libmcrypt-dev \
    libreadline-dev \
    g++ \
    zlib1g-dev

# 2. apache configs + document root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 3. mod_rewrite for URL rewrite and mod_headers for .htaccess extra headers like Access-Control-Allow-Origin-
RUN a2enmod rewrite headers

# activating expires module
RUN ln -s /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/

# 4. start with base php config, then add extensions
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN docker-php-ext-install \
    bz2 \
    intl \
    iconv \
    bcmath \
    opcache \
    calendar \
    mbstring \
    pdo \
    pdo_mysql \
    mysqli \
    zip

# 5. composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 6. installing gd and related packages
RUN apt-get install -y build-essential libssl-dev zlib1g-dev libpng-dev libjpeg-dev libfreetype6-dev libwebp-dev

RUN docker-php-ext-configure gd --with-gd --with-webp-dir --with-jpeg-dir=/usr/include/ \
    --with-png-dir --with-freetype-dir=/usr/include/ \
    --enable-gd-native-ttf

RUN docker-php-ext-install gd

# 7. we need a user with the same UID/GID with host user
# so when we execute CLI commands, all the host file's ownership remains intact
# otherwise command from inside container will create root-owned files and directories
RUN useradd -G www-data,root -u 1000 -d /home/devuser devuser
RUN mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser

ADD ./php.ini /usr/local/etc/php
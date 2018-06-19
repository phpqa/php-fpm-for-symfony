# Set defaults

ARG BASE_IMAGE="php:7.2-fpm"
ARG PACKAGIST_NAME="symfony/symfony"
ARG PHPQA_NAME="php-fpm-for-symfony"
ARG VERSION="4.0.11"
ARG REQUIREMENTS_CHECKER_VERSION="1.1.1"
ARG TZ="UTC"

# Requirements for Symfony - https://symfony.com/doc/current/reference/requirements.html

# Required requirements - https://github.com/symfony/requirements-checker/blob/master/src/SymfonyRequirements.php
# - PHP version must be at least 5.5.9                                      => parent image
# - Vendor libraries must be installed                                      => depends on your project
# - var/cache/ directory must be writable                                   => depends on your project
# - var/log/ directory must be writable                                     => depends on your project
# - date.timezone setting must be set (if < PHP 7.0.0)                      => added below: TZ environment variable >>
# - iconv() must be available                                               => iconv extension is enabled by default
# - json_encode() must be available                                         => JSON extension is bundled and compiled by default as of PHP 5.2.0
# - session_start() must be available                                       => Session support is enabled by default
# - ctype_alpha() must be available                                         => Ctype functions are enabled by default as of PHP 4.2.0
# - token_get_all() must be available                                       => Tokenizer functions are enabled by default
# - simplexml_import_dom() must be available                                => SimpleXML extension is enabled by default as of PHP 5.1.2
# - detect_unicode should be disabled                                       => defaults to "1"
# - xdebug.show_exception_trace should be disabled                          => defaults to "0"
# - xdebug.scream should be disabled                                        => defaults to "0"
# - xdebug.max_nesting_level should be above 100 in php.ini                 => defaults to "256"
# - PCRE extension must be available                                        => The PCRE extension is a core PHP extension, so it is always enabled
# - string functions should not be overloaded (mbstring.func_overload)      => Function Overloading is disabled by default, deprecated as of PHP 7.2.0

# Optional requirements - https://github.com/symfony/requirements-checker/blob/master/src/SymfonyRequirements.php
# - PCRE extension should be at least version 8.0.
# - PHP-DOM and PHP-XML modules should be installed                         => The XML extension is enabled by default
# - mb_strlen() should be available                                         => added below: mbstring extension >>
# - utf8_decode() should be available                                       => The XML extension is enabled by default
# - filter_var() should be available                                        => The filter extension is enabled by default as of PHP 5.2.0
# - intl extension should be available                                      => added below: intl extension >>
# - intl ICU version should be at least 4+                                  => added below: intl extension >>
# - intl ICU version installed on your system is outdated (%s) and does not match the ICU data bundled with Symfony => added below: intl extension >>
# - intl.error_level should be 0 in php.ini                                 => defaults to "0"
# - a PHP accelerator should be installed                                   => added below: opcache extension >>
# - short_open_tag should be disabled                                       => defaults to "1"
# - magic_quotes_gpc should be disabled                                     => removed as of PHP 5.4.0
# - register_globals should be disabled                                     => removed as of PHP 5.4.0
# - session.auto_start should be disabled                                   => defaults to "0"
# - xdebug.max_nesting_level should be above 100 in php.ini                 => duplicate, see above
# - "memory_limit" should be greater than "post_max_size"                   => memory_limit defaults to "128M", post_max_size defaults to "8M"
# - "post_max_size" should be greater than "upload_max_filesize"            => post_max_size defaults to "8M", upload_max_filesize defaults to "2M"
# - PDO should be installed                                                 => PDO is enabled by default as of PHP 5.1.0
# - PDO should have some drivers installed                                  => PDO_SQLITE driver is enabled by default as of PHP 5.1.0, added below: pdo_mysql pdo_pgsql extensions >>

# Download & build ICU - http://site.icu-project.org/

FROM ${BASE_IMAGE} as icu
ARG VERSION
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:1.6.4 /usr/bin/composer /usr/bin/composer
RUN apt-get -yqq update && apt-get -yqq install git zip \
    && apt-get -yqq autoremove --purge && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && COMPOSER_HOME="/composer" \
        composer global require --prefer-dist --dev symfony/intl:${VERSION} \
    && icu_version="$(cat /composer/vendor/symfony/intl/Resources/data/version.txt)" \
    && icu_download_url=$(printf "http://download.icu-project.org/files/icu4c/%s/icu4c-%s-src.tgz" "${icu_version}" "$(printf ${icu_version} | sed 's/\./_/g')") \
    && curl -sS -o /tmp/icu.tar.gz -L ${icu_download_url} \
    && tar -zxf /tmp/icu.tar.gz -C /tmp \
    && cd /tmp/icu/source \
    && ./configure --prefix=/usr/local/icu \
    && make \
    && make install \
    && rm -rf /tmp/icu*

# Download Symfony Requirements Checker - https://github.com/symfony/requirements-checker/tree/master/src

FROM ${BASE_IMAGE} as requirements-checker
ARG REQUIREMENTS_CHECKER_VERSION
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:1.6.4 /usr/bin/composer /usr/bin/composer
RUN apt-get -yqq update && apt-get -yqq install git zip \
    && COMPOSER_HOME="/composer" \
        composer global require --prefer-dist --no-progress --dev symfony/requirements-checker:${REQUIREMENTS_CHECKER_VERSION}

# Build image

FROM ${BASE_IMAGE}
ARG PHPQA_NAME
ARG VERSION
ARG BUILD_DATE
ARG VCS_REF
ARG IMAGE_NAME
ARG TZ

# Set the TZ environment variable, which will be used in the docker-entrypoint-with-tz file to set the date.timezone

ENV TZ ${TZ}
COPY ./docker-entrypoint.sh /usr/local/bin/docker-php-entrypoint-with-tz
RUN chmod +x /usr/local/bin/docker-php-entrypoint-with-tz

# Install iconv extension

RUN docker-php-ext-install -j$(nproc) iconv

# Install mbstring extension

RUN docker-php-ext-install -j$(nproc) mbstring

# Install Intl extension with ICU

COPY --from=icu "/usr/local/icu" "/usr/local/icu"
RUN docker-php-ext-configure intl --with-icu-dir=/usr/local/icu \
    && docker-php-ext-install -j$(nproc) intl

# Install the OPcache extension

RUN docker-php-ext-install -j$(nproc) opcache

# Install PDO and PDO drivers

RUN apt-get update && apt-get install -y libpq-dev \
    && apt-get -yqq autoremove --purge && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
RUN docker-php-ext-install -j$(nproc) pdo pdo_mysql pdo_pgsql

# Add recommended php.ini settings

RUN printf "short_open_tag=0 \n" > /usr/local/etc/php/conf.d/symfony.ini

#/ Requirements

# Extra: Install GD extension with jpeg, png, freetype support

RUN apt-get update && apt-get install -y libjpeg-dev libpng-dev libfreetype6-dev \
    && apt-get -yqq autoremove --purge && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && docker-php-ext-configure gd --with-jpeg-dir=/usr/ --with-png-dir=/usr/ --with-freetype-dir=/usr/ \
    && docker-php-ext-install -j$(nproc) gd

# Extra: Install LDAP extension

RUN apt-get -yqq update && apt-get -yqq install libldap2-dev \
    && apt-get -yqq autoremove --purge && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install -j$(nproc) ldap

# Extra: Install zip extension

RUN apt-get -yqq update && apt-get -yqq install zlib1g-dev \
    && apt-get -yqq autoremove --purge && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && docker-php-ext-install -j$(nproc) zip

# Extra: Install git, curl, wget, zip, unzip tools

RUN apt-get -yqq update && apt-get -yqq install git curl wget zip unzip \
    && apt-get -yqq autoremove --purge && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Symfony Requirements Checker - https://github.com/symfony/requirements-checker/tree/master/src

COPY --from=requirements-checker "/composer/" "/composer/"
ENV PATH /composer/vendor/bin:${PATH}

# Install Blackfire - https://blackfire.io/docs/integrations/docker

RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
    && mv /tmp/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini

# Install Xdebug - https://github.com/xdebug/xdebug

RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > $PHP_INI_DIR/conf.d/xdebug.ini

# Add image labels

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.vendor="phpqa" \
      org.label-schema.name="${PHPQA_NAME}" \
      org.label-schema.version="${VERSION}" \
      org.label-schema.build-date="${BUILD_DATE}" \
      org.label-schema.url="https://github.com/phpqa/${PHPQA_NAME}" \
      org.label-schema.usage="https://github.com/phpqa/${PHPQA_NAME}/README.md" \
      org.label-schema.vcs-url="https://github.com/phpqa/${PHPQA_NAME}.git" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.docker.cmd="docker run --rm ${IMAGE_NAME} php-fpm --info"

# Package container

WORKDIR "/var/www/html"
ENTRYPOINT ["docker-php-entrypoint-with-tz"]
CMD ["php-fpm"]

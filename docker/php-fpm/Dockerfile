FROM php:8.4-fpm AS base

WORKDIR "/var/www/html"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        zip \
        unzip \
    && curl -sSL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o - | sh -s \
        curl gd intl ldap mbstring mysqli odbc pdo pdo_mysql soap sockets xml zip exif sqlite3 gettext bcmath csv event inotify redis \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && curl -sLS https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && apt-get install -q -y ssmtp mailutils \
    && echo "hostname=localhost.localdomain" > /etc/ssmtp/ssmtp.conf \
    && echo "root=root@example.org" >> /etc/ssmtp/ssmtp.conf \
    && echo "mailhub=mailpit:1025" >> /etc/ssmtp/ssmtp.conf \
    && echo "sendmail_path=/usr/sbin/ssmtp -t" >> /usr/local/etc/php/conf.d/php-sendmail.ini \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Development stage
FROM base AS development

RUN curl -sSL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o - | sh -s xdebug \
    && docker-php-ext-enable xdebug \
    && echo "alias ll=\"ls -al\"" >> /root/.bashrc \
    && echo "export XDEBUG_TRIGGER=1" >> /root/.bashrc \
    && echo "export PHP_IDE_CONFIG=\"serverName=host.docker.internal\"" >> /root/.bashrc

CMD ["bash", "docker/php-fpm/start-container"]

# Production stage
FROM base AS production

# Copy application files first (from project root)
COPY --chown=www-data:www-data composer.json composer.lock* /var/www/html/

# Install Composer dependencies for production
RUN cd /var/www/html \
    && composer install --optimize-autoloader --no-dev --no-interaction \
    && composer clear-cache

# Copy assets source and build configuration
COPY --chown=www-data:www-data package.json package-lock.json* gulpfile.js babel.config.json /var/www/html/
COPY --chown=www-data:www-data assets/ /var/www/html/assets/
RUN cd /var/www/html \
    && npm install \
    && npx gulp compile \
    && rm -rf node_modules package*.json gulpfile.js babel.config.json

# Install gosu for user switching in production
RUN apt-get update \
    && apt-get install -y gosu \
    && apt-get remove -y git \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -rf /usr/local/bin/composer

# Copy the rest of the application to a temporary location for volume initialization
COPY --chown=www-data:www-data . /tmp/app/

# Copy app files to default location
RUN cp -rf /tmp/app/* /var/www/html/ || true

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser \
    && mkdir -p /var/www/html/storage/logs \
    && chown -R appuser:appuser /var/www/html/storage \
    && chown -R appuser:appuser /tmp/app

# Copy production startup script
COPY --chown=root:root docker/php-fpm/start-production /usr/local/bin/start-production
RUN chmod +x /usr/local/bin/start-production

# Copy PHP-FPM configuration
COPY --chown=root:root docker/php-fpm/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY --chown=root:root docker/php-fpm/zz-override.conf /usr/local/etc/php-fpm.d/zz-override.conf

# Start as root to handle volume initialization, then start php-fpm via start script
CMD ["/usr/local/bin/start-production"]
FROM php:8.3-fpm-alpine AS builder

# Arguments
ARG AKAUNTING_DOCKERFILE_VERSION=0.1
ARG SUPPORTED_LOCALES="en_US.UTF-8"

# Add build dependencies
RUN apk add --update --no-cache \
    bash \
    freetype-dev \
    icu-dev \
    libarchive-tools \
    npm \
    optipng \
    pngquant \
    supervisor

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install PHP Extensions
RUN chmod +x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions gd zip intl imap xsl pgsql pdo_pgsql opcache bcmath pcntl

# Configure Extension
RUN docker-php-ext-configure \
    opcache --enable-opcache

# Installing composer
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -rf composer-setup.php

# Clear npm proxy
RUN npm config rm proxy 2>/dev/null || true && \
    npm config rm https-proxy 2>/dev/null || true

# Create working directory structure
RUN mkdir -p /var/www/akaunting && \
    chown -R www-data:www-data /var/www

# Setup Working Dir
WORKDIR /var/www/akaunting

# Copy Akaunting application source
COPY --chown=www-data:www-data . /var/www/akaunting

# Build application
USER www-data
RUN composer prod --no-interaction && \
    npm install && \
    npm run prod

# Production stage - minimal runtime image
FROM php:8.3-fpm-alpine

# Arguments
ARG AKAUNTING_DOCKERFILE_VERSION=0.1
ARG SUPPORTED_LOCALES="en_US.UTF-8"

# Add runtime dependencies only
RUN apk add --update --no-cache \
    bash \
    freetype \
    icu-libs \
    jpegoptim \
    libarchive-tools \
    optipng \
    pngquant \
    supervisor

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install PHP Extensions
RUN chmod +x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions gd zip intl imap xsl pgsql pdo_pgsql opcache bcmath pcntl

# Configure Extension
RUN docker-php-ext-configure \
    opcache --enable-opcache

# Setup Working Dir
WORKDIR /var/www/akaunting

# Copy built application from builder stage
COPY --from=builder --chown=www-data:www-data /var/www/akaunting /var/www/akaunting

# Create storage directories with correct ownership (as root, before switching user)
RUN mkdir -p /var/www/akaunting/storage/framework/{sessions,views,cache} && \
    mkdir -p /var/www/akaunting/storage/app/uploads && \
    chmod -R u=rwX,g=rX,o=rX /var/www/akaunting/storage

# Copy entrypoint script
COPY --chown=www-data:www-data files/akaunting-php-fpm.sh /usr/local/bin/akaunting-php-fpm.sh
RUN chmod +x /usr/local/bin/akaunting-php-fpm.sh

# Remove build artifacts and unnecessary files
RUN rm -rf \
    /var/www/akaunting/node_modules \
    /var/www/akaunting/.git \
    /var/www/akaunting/.github \
    /var/www/akaunting/tests \
    /var/www/akaunting/phpunit.xml \
    /var/www/akaunting/.dockerignore \
    /var/www/akaunting/Dockerfile \
    /var/www/akaunting/.env.example \
    /var/www/akaunting/README.md \
    /var/www/akaunting/SECURITY.md

# Switch to non-root user
USER www-data

EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/akaunting-php-fpm.sh"]
CMD ["--start"]

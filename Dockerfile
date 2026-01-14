FROM node:20.10.0 AS dev

LABEL org.opencontainers.image.description="roBrowser Legacy - Development Environment"

WORKDIR /app

# Install system dependencies
RUN apt-get update -y -q && \
    apt-get install -y -q build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g live-server wsproxy

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install || true

# Copy all files
COPY . .

# Set permissions
RUN chown -R node:node /app

# Switch to non-root user
USER node

EXPOSE 8001

# Start server
CMD ["npx", "live-server", ".", "--port=8001", "--host=0.0.0.0", "--no-browser", "--cors"]

# ============================================
# Production Stage
# ============================================

FROM php:8.3-apache AS dist-server

LABEL org.opencontainers.image.description="roBrowser Legacy - Production Server"

WORKDIR /var/www/html

USER root

# Install Apache modules
RUN apt-get update -y -qq && \
    a2enmod rewrite headers && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure Apache
RUN cat <<'EOF' > /etc/apache2/sites-enabled/dist.conf
<VirtualHost *:8080>
    ServerAdmin webmaster@robrowser.legacy
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "\.(html|htm|js|css|json|xml|txt|lua|png|jpg|jpeg|gif|svg|webp|ico|woff|woff2|ttf|otf|eot|mp4|webm|ogg|mp3|wav)$">
        Require all granted
    </FilesMatch>

    DirectoryIndex index.html demo.html

    # MIME types
    AddType application/javascript .js .mjs
    AddType text/css .css
    AddType application/json .json
    AddType text/plain .txt .lua

    RewriteEngine On

    # CORS
    <IfModule mod_headers.c>
        Header set Access-Control-Allow-Origin "*"
        Header set Access-Control-Allow-Methods "GET, POST, OPTIONS, HEAD"
        Header set Access-Control-Allow-Headers "*"
    </IfModule>
</VirtualHost>
EOF

RUN echo "Listen 8080" >> /etc/apache2/ports.conf

# Copy files
COPY --chown=www-data:www-data . /var/www/html/

# Set permissions
RUN chmod -R 755 /var/www/html

EXPOSE 8080

USER www-data

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1
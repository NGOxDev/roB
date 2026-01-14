FROM node:20.10.0 AS dev

LABEL org.opencontainers.image.description="roBrowser Legacy - Development Environment"

# Set working directory
WORKDIR /app

# Install system dependencies and tools
RUN apt-get update -y -q && \
    apt-get install -y -q build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g live-server wsproxy

# Copy package files first (if exists)
COPY package*.json ./

# Install npm dependencies (if package.json exists)
RUN npm install || true

# Copy all application files
COPY . .

# Verify files are copied (for debugging)
RUN echo "=== Checking copied files ===" && \
    ls -la /app/ && \
    echo "=== Checking src directory ===" && \
    ls -la /app/src/ && \
    echo "=== Checking UI Components ===" && \
    ls -la /app/src/UI/Components/PvpCount/ || echo "PvpCount directory not found"

# Set proper permissions
RUN chown -R node:node /app

# Switch to non-root user
USER node

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8001', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start live-server
CMD ["npx", "live-server", ".", "--port=8001", "--host=0.0.0.0", "--no-browser", "--cors", "--wait=100"]

# ============================================
# Production Stage (Apache + PHP)
# ============================================

FROM php:8.3-apache AS dist-server

LABEL org.opencontainers.image.description="roBrowser Legacy - Production Server"

WORKDIR /var/www/html

USER root

# Install and enable Apache modules
RUN apt-get update -y -qq && \
    apt-get install -y -qq libapache2-mod-security2 && \
    a2enmod rewrite headers && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure Apache
RUN cat <<'EOF' > /etc/apache2/sites-enabled/dist.conf
<VirtualHost *:8080>
    ServerAdmin webmaster@robrowser.legacy
    DocumentRoot /var/www/html
    ServerName localhost

    # Directory settings
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Security headers
        Header always set X-Frame-Options "SAMEORIGIN"
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-XSS-Protection "1; mode=block"
    </Directory>

    # Allow all common file types
    <FilesMatch "\.(html|htm|js|css|json|xml|txt|lua|png|jpg|jpeg|gif|svg|webp|ico|woff|woff2|ttf|otf|eot|mp4|webm|ogg|mp3|wav|pdf|zip)$">
        Require all granted
    </FilesMatch>

    # Default index files
    DirectoryIndex index.html demo.html

    # MIME types
    AddType application/javascript .js .mjs
    AddType application/x-javascript .js
    AddType text/javascript .js
    AddType text/css .css
    AddType application/json .json
    AddType application/xml .xml
    AddType text/plain .txt .lua
    AddType audio/mpeg .mp3
    AddType audio/wav .wav

    # Enable URL rewriting
    RewriteEngine On

    # CORS headers
    <IfModule mod_headers.c>
        Header set Access-Control-Allow-Origin "*"
        Header set Access-Control-Allow-Methods "GET, POST, OPTIONS, HEAD"
        Header set Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
        Header set Access-Control-Max-Age "3600"
    </IfModule>

    # Compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
    </IfModule>

    # Error log
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Add port 8080
RUN echo "Listen 8080" >> /etc/apache2/ports.conf

# Copy application files
COPY --chown=www-data:www-data . /var/www/html/

# Verify files
RUN ls -la /var/www/html/ && \
    ls -la /var/www/html/src/ || echo "src directory not found"

# Set permissions
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

# Expose port
EXPOSE 8080

# Switch to www-data user
USER www-data

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1
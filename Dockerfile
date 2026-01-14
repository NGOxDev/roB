FROM node:20.10.0 AS dev

LABEL org.opencontainers.image.description="Creates a environment to host the NodeJS and NPM environment."

USER root

RUN apt update -y -q && apt install build-essential -y -q && \
  mkdir -p /app && \
  npm install -g wsproxy live-server

WORKDIR /app

# Copy application files
COPY --chown=node:node . /app/

EXPOSE 8000

# Run live-server instead of sleep
CMD ["npx", "live-server", ".", "--port=8000", "--host=0.0.0.0", "--no-browser", "--cors"]

FROM php:8.3-apache AS dist-server

LABEL org.opencontainers.image.description="Creates a environment to serve the dist files using Apache"

WORKDIR /var/www/html

USER root

RUN apt-get update -y -qq && \
  a2enmod rewrite && \
  a2enmod headers

# For some IDEs this line is treated as wrongly configured, but this is a bug !
# This heredoc format is supported by Docker.
RUN cat <<EOF > /etc/apache2/sites-enabled/dist.conf
<VirtualHost *:8080>
    ServerAdmin webmaster@robrowser.legacy
    DocumentRoot /var/www/html

    # Allow directory access
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "\.(html|js|css|png|jpg|gif|svg|webp|ico|woff|woff2|ttf|otf|eot|mp4|webm|ogg|mp3|json|xml|txt|lua)$">
        Require all granted
    </FilesMatch>

    # Set default file
    DirectoryIndex index.html

    # MIME types for JavaScript and other files
    AddType application/javascript .js
    AddType application/x-javascript .js
    AddType text/javascript .js
    AddType text/css .css
    AddType application/json .json

    # Enable rewrite
    RewriteEngine On

    # Enable CORS if needed
    <IfModule mod_headers.c>
        Header set Access-Control-Allow-Origin "*"
        Header set Access-Control-Allow-Methods "GET, POST, OPTIONS, HEAD"
        Header set Access-Control-Allow-Headers "*"
    </IfModule>
</VirtualHost>
EOF

RUN echo "Listen 8080" >> /etc/apache2/ports.conf

# Copy application files - สำคัญ!
COPY --chown=www-data:www-data . /var/www/html/

EXPOSE 8080

USER www-data
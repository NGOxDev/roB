FROM php:8.3-apache AS dist-server

LABEL org.opencontainers.image.description="roBrowser Legacy Production"

WORKDIR /var/www/html

USER root

RUN apt-get update -y -qq && \
  a2enmod rewrite && \
  a2enmod headers

RUN cat <<EOF > /etc/apache2/sites-enabled/dist.conf
<VirtualHost *:8080>
    ServerAdmin webmaster@robrowser.legacy
    DocumentRoot /var/www/html

    # Allow access to entire html directory
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Set default file
    DirectoryIndex index.html

    # MIME types
    AddType application/javascript .js .mjs
    AddType text/css .css
    AddType application/json .json
    
    # Enable rewrite
    RewriteEngine On
    
    # Enable CORS
    <IfModule mod_headers.c>
        Header set Access-Control-Allow-Origin "*"
        Header set Access-Control-Allow-Methods "GET, POST, OPTIONS"
        Header set Access-Control-Allow-Headers "*"
    </IfModule>
</VirtualHost>
EOF

RUN echo "Listen 8080" >> /etc/apache2/ports.conf

# Copy ALL files including src/
COPY --chown=www-data:www-data . /var/www/html/

EXPOSE 8080

USER www-data
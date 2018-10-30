FROM php:5.6-apache
#7.0.31-zts-stretch
MAINTAINER KhrysRo

ENV PHPIPAM_SOURCE https://github.com/phpipam/phpipam/
ENV PHPIPAM_VERSION 1.3.2
ENV PHPMAILER_SOURCE https://github.com/PHPMailer/PHPMailer/
ENV PHPMAILER_VERSION 6.0.5
ENV PHPSAML_SOURCE https://github.com/onelogin/php-saml/
ENV PHPSAML_VERSION 2.14.0
ENV WEB_REPO /var/www/html

# Install required deb packages
RUN grep . /etc/apt/sources.list > /etc/apt/sources.list.1 && mv /etc/apt/sources.list.1 /etc/apt/sources.list
RUN sed -i /etc/apt/sources.list -e 's/$/ non-free'/ 
RUN apt-get update && apt-get -y upgrade 
RUN apt-get install -y libcurl4-gnutls-dev
RUN rm /etc/apt/preferences.d/no-debian-php 

RUN apt-get install -y libgmp-dev 
RUN apt-get install -y libmcrypt-dev 
RUN apt-get install -y libpng-dev 
RUN apt-get install -y libfreetype6-dev libfreetype6-dev libssl-dev
RUN apt-get install -y libjpeg-dev
RUN apt-get install -y libpng-dev 
RUN apt-get install -y libldap2-dev
RUN apt-get install -y libsnmp-dev
RUN apt-get install -y snmp-mibs-downloader 
RUN apt-get install -y libjpeg62-turbo-dev
#RUN apt-get install -y php7.0-gmp
#RUN apt-get install -y gmp
RUN apt-get install -y libgmp-dev

RUN apt-get update && \
	apt-get install -y git php-pear php5-curl php5-gd php5-mysql php5-json php5-gmp php5-mcrypt php5-ldap libpng-dev libgmp-dev libmcrypt-dev && \
	rm -rf /var/lib/apt/lists/*


RUN rm -rf /var/lib/apt/lists/*

# Create folders required for snmp
RUN mkdir /var/lib/mibs/ && mkdir /var/lib/mibs/ietf/

# Install required packages and files required for snmp
RUN curl -s ftp://ftp.cisco.com/pub/mibs/v2/CISCO-SMI.my -o /var/lib/mibs/ietf/CISCO-SMI.txt && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/CISCO-TC.my -o /var/lib/mibs/ietf/CISCO-TC.txt && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/CISCO-VTP-MIB.my -o /var/lib/mibs/ietf/CISCO-VTP-MIB.txt && \
    curl -s ftp://ftp.cisco.com/pub/mibs/v2/MPLS-VPN-MIB.my -o /var/lib/mibs/ietf/MPLS-VPN-MIB.txt

# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli #&& \
RUN    docker-php-ext-configure gd --enable-gd-native-ttf --with-freetype-dir=/usr/include/freetype2 --with-png-dir=/usr/include --with-jpeg-dir=/usr/include && \
    docker-php-ext-install gd && \
    docker-php-ext-install curl && \
    docker-php-ext-install json #&& \
RUN    docker-php-ext-install snmp && \
    docker-php-ext-install sockets && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install gettext # && \
RUN    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install mcrypt && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install ldap && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# Copy phpipam sources to web dir
ADD ${PHPIPAM_SOURCE}/archive/${PHPIPAM_VERSION}.tar.gz /tmp/
#RUN mkdir /var/www/ && mkdir ${WEB_REPO}
RUN tar -xzf /tmp/${PHPIPAM_VERSION}.tar.gz -C ${WEB_REPO}/ --strip-components=1
# Copy referenced submodules into the right directory
ADD ${PHPMAILER_SOURCE}/archive/v${PHPMAILER_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPMAILER_VERSION}.tar.gz -C ${WEB_REPO}/functions/PHPMailer/ --strip-components=1
ADD ${PHPSAML_SOURCE}/archive/v${PHPSAML_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPSAML_VERSION}.tar.gz -C ${WEB_REPO}/functions/php-saml/ --strip-components=1

# Use system environment variables into config.php
RUN cp ${WEB_REPO}/config.dist.php ${WEB_REPO}/config.php && \
    chown www-data /var/www/html/app/admin/import-export/upload && \
    sed -i -e "s/\['host'\] = 'localhost'/\['host'\] = getenv(\"MYSQL_ENV_MYSQL_HOST\") ?: \"mysql\"/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = getenv(\"MYSQL_ENV_MYSQL_USER\") ?: \"root\"/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\")/" \
    -e "s/\['port'\] = 3306;/\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_PASSWORD_FILE\");\nif(file_exists(\$password_file))\n\$db\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    ${WEB_REPO}/config.php

EXPOSE 80


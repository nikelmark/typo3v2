FROM registry.access.redhat.com/rhscl/php-70-rhel7

# This image provides an Apache+PHP environment for running PHP
# applications.

USER 0

EXPOSE 8080

ENV PHP_VERSION=7.0 \
    PATH=$PATH:/opt/rh/rh-php70/root/usr/bin \
    CONTENT_DIR=/var/www/html \
    APACHE_APP_ROOT=/opt/app-root/src \
    TP3_VERS=8.7.1 \ 
    TP3_FULL_FILE=typo3_src-\${TP3_VERS} \
    TYPO3_DL=https://get.typo3.org/8.7

ENV SUMMARY="Platform for building and running PHP $PHP_VERSION applications" \
    DESCRIPTION="PHP $PHP_VERSION available as docker container is a base platform for \
building and running various PHP $PHP_VERSION applications and frameworks. \
PHP is an HTML-embedded scripting language. PHP attempts to make it easy for developers \
to write dynamically generated web pages. PHP also offers built-in database integration \
for several commercial and non-commercial database management systems, so writing \
a database-enabled webpage with PHP is fairly simple. The most common use of PHP coding \
is probably as a replacement for CGI scripts."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$SUMMARY" \
      io.k8s.display-name="Apache 2.4 with PHP 7.0" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,php,php70,rh-php70" \
      name="rhscl/php-70-rhel7" \
      com.redhat.component="rh-php70-docker" \
      version="7.0" \
      release="5.0"

# Install Apache httpd and PHP
# To use subscription inside container yum command has to be run first (before yum-config-manager)
# https://access.redhat.com/solutions/1443553
RUN yum repolist > /dev/null && \
    yum-config-manager --enable rhel-server-rhscl-7-rpms && \
    yum-config-manager --enable rhel-7-server-optional-rpms && \
    INSTALL_PKGS="rh-php70 rh-php70-php rh-php70-php-mysqlnd rh-php70-php-pgsql rh-php70-php-bcmath && \
                  rh-php70-php-gd rh-php70-php-intl rh-php70-php-ldap rh-php70-php-mbstring rh-php70-php-pdo && \
                  rh-php70-php-process rh-php70-php-soap rh-php70-php-opcache rh-php70-php-xml && \
                  rh-php70-php-gmp" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image.
COPY ./root/ /

# In order to drop the root user, we have to make some directories world
# writeable as OpenShift default security model is to run the container under
# random UID.
RUN sed -i -f /opt/app-root/etc/httpdconf.sed /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf && \
    sed -i '/php_value session.save_path/d' /opt/rh/httpd24/root/etc/httpd/conf.d/rh-php70-php.conf && \
    head -n151 /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf | tail -n1 | grep "AllowOverride All" || exit && \
    echo "IncludeOptional /opt/app-root/etc/conf.d/*.conf" >> /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf && \
    mkdir /tmp/sessions && \
    chown -R 1001:0 /opt/app-root /tmp/sessions && \
    chmod -R a+rwx /tmp/sessions && \
    chmod -R ug+rwx /opt/app-root && \
    chmod -R a+rwx /etc/opt/rh/rh-php70 && \
    chmod -R a+rwx /opt/rh/httpd24/root/var/run/httpd
    mkdir -p ${CONTENT_DIR} && \
    cd ${CONTENT_DIR} && \
    wget https://get.typo3.org/${TP3_VERS} && \
    tar -xf ${TP3_VERS} && \
    mkdir -p typo3temp && \
    mkdir -p typo3conf && \
    mkdir -p fileadmin && \
    mkdir -p uploads && \
    ln -s typo3_src-* typo3_src && \
    ln -s typo3_src/index.php && \
    ln -s typo3_src/typo3 && \
    ln -s typo3_src/_.htaccess .htaccess && \
    touch FIRST_INSTALL && \
    chown -R 1001:0 ${CONTENT_DIR} ${APACHE_APP_ROOT} && \
    chmod 777 ${CONTENT_DIR} ${APACHE_APP_ROOT} && \
    chmod -R 777 ${CONTENT_DIR} /var/opt/rh/rh-php70/lib/php/session && \
    ln -s ${CONTENT_DIR}/$(basename $( echo ${TP3_FULL_FILE}|envsubst ) '') ${APACHE_APP_ROOT}/typo3_src && \
    cd ${APACHE_APP_ROOT} && \
    ln -s ${CONTENT_DIR}/$(basename $( echo ${TP3_FULL_FILE}|envsubst ) '') ${APACHE_APP_ROOT}/typo3_src && \
    cd ${APACHE_APP_ROOT} && \
    touch ${APACHE_APP_ROOT}/FIRST_INSTALL && \
    chmod -Rvf ug+rwx ${APACHE_APP_ROOT}/FIRST_INSTALL && \
    ln -s typo3_src/typo3 typo3 && \
    ln -s typo3_src/index.php index.php

USER 1001

VOLUME /var/www/html/fileadmin
VOLUME /var/www/html/typo3conf
VOLUME /var/www/html/typo3temp
VOLUME /var/www/html/uploads

COPY containerfiles/ /

RUN chmod +x /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]

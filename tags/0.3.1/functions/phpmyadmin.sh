#!/bin/sh

# Author: Zhang Huangbin <michaelbibby (at) gmail.com>

# -------------------------------------------------
# phpMyAdmin.
# -------------------------------------------------
phpmyadmin_install()
{
    cd ${MISC_DIR}

    extract_pkg ${PHPMYADMIN_TARBALL} ${HTTPD_SERVERROOT}

    ECHO_INFO "Set file permission for phpMyAdmin: ${PHPMYADMIN_HTTPD_ROOT}."
    chown -R root:root ${PHPMYADMIN_HTTPD_ROOT}
    chmod -R 0755 ${PHPMYADMIN_HTTPD_ROOT}

    ECHO_INFO "Create directory alias for phpMyAdmin in Apache: ${HTTPD_CONF_DIR}/phpmyadmin.conf."
    cat > ${HTTPD_CONF_DIR}/phpmyadmin.conf <<EOF
${CONF_MSG}
Alias /phpmyadmin "${PHPMYADMIN_HTTPD_ROOT}/"
EOF

    ECHO_INFO "Config phpMyAdmin: ${PHPMYADMIN_HTTPD_ROOT}/config.inc.php."
    cd ${PHPMYADMIN_HTTPD_ROOT}
    cp config.sample.inc.php config.inc.php

    export COOKIE_STRING="$(openssl passwd -1 ${PROG_NAME_LOWERCASE})"
    perl -pi -e 's#(.*blowfish_secret.*= )(.*)#${1}"$ENV{'COOKIE_STRING'}"; //${2}#' config.inc.php
    perl -pi -e 's#(.*Servers.*host.*=.*)localhost(.*)#${1}127.0.0.1${2}#' config.inc.php

    cat >> ${TIP_FILE} <<EOF
phpMyAdmin:
    * Configuration files:
        - ${PHPMYADMIN_HTTPD_ROOT}
        - ${PHPMYADMIN_HTTPD_ROOT}/config.inc.php
    * URL:
        - http://$(hostname)/phpmyadmin
    * See also:
        - ${HTTPD_CONF_DIR}/phpmyadmin.conf

EOF

    echo 'export status_phpmyadmin_install="DONE"' >> ${STATUS_FILE}
}
#!/bin/sh

# Author: Zhang Huangbin <michaelbibby (at) gmail.com>

# ---------------------------------------------------------
# SqruirrelMail.
# ---------------------------------------------------------
sm_install()
{
    cd ${MISC_DIR}

    # Extract source tarball.
    extract_pkg ${SM_TARBALL} ${HTTPD_SERVERROOT}

    # Create symbol link, so that we don't need to modify apache
    # conf.d/squirrelmail.conf file after upgrade this component.
    ln -s ${SM_HTTPD_ROOT} ${HTTPD_SERVERROOT}/squirrelmail 2>/dev/null

    cp -f ${SM_HTTPD_ROOT}/config/config_default.php ${SM_HTTPD_ROOT}/config/config.php

    ECHO_INFO "Set correct permission for squirrelmail: ${SM_HTTPD_ROOT}."
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_HTTPD_ROOT}
    chmod -R 755 ${SM_HTTPD_ROOT}
    chmod 0000 ${SM_HTTPD_ROOT}/{README,doc}

    ECHO_INFO "Create directory alias for squirrelmail in Apache: ${HTTPD_DOCUMENTROOT}/mail/."
    cat > ${HTTPD_CONF_DIR}/squirrelmail.conf <<EOF
${CONF_MSG}
Alias /squirrelmail "${HTTPD_SERVERROOT}/squirrelmail/"
Alias /squirrel "${HTTPD_SERVERROOT}/squirrelmail/"
<Directory "${HTTPD_SERVERROOT}/squirrelmail/">
    Options -Indexes
</Directory>
EOF

    # Make SquirrelMail can be accessed via HTTPS.
    sed -i 's#\(</VirtualHost>\)#Alias /squirrelmail '${HTTPD_SERVERROOT}/squirrelmail/'\n\1#' ${HTTPD_SSL_CONF}
    sed -i 's#\(</VirtualHost>\)#Alias /squirrel '${HTTPD_SERVERROOT}/squirrelmail/'\n\1#' ${HTTPD_SSL_CONF}

    if [ X"${USE_RCM}" != X"YES" ]; then
        cat >> ${HTTPD_CONF_DIR}/squirrelmail.conf <<EOF
Alias /mail "${HTTPD_SERVERROOT}/squirrelmail/"
Alias /webmail "${HTTPD_SERVERROOT}/squirrelmail/"
EOF

        # Make SquirrelMail can be accessed via HTTPS.
        sed -i 's#\(</VirtualHost>\)#Alias /mail '${SM_HTTPD_ROOT}'/\n\1#' ${HTTPD_SSL_CONF}
        sed -i 's#\(</VirtualHost>\)#Alias /webmail '${SM_HTTPD_ROOT}'/\n\1#' ${HTTPD_SSL_CONF}
    fi

    ECHO_INFO "Create directories to store data and attachments: ${SM_DATA_DIR}, ${SM_ATTACHMENT_DIR}."

    mkdir -p ${SM_DATA_DIR} ${SM_ATTACHMENT_DIR}
    chown ${HTTPD_USER}:${HTTPD_GROUP} ${SM_DATA_DIR} ${SM_ATTACHMENT_DIR}
    chmod 730 ${SM_ATTACHMENT_DIR}

    cat >> ${TIP_FILE} <<EOF
WebMail(SquirrelMail):
    * Configuration files:
        - ${SM_HTTPD_ROOT}
        - ${SM_HTTPD_ROOT}/config/config.php
        - ${HTTPD_CONF_DIR}/squirrelmail.conf
    * URL:
        - http://${HOSTNAME}/squirrel/
        - http://${HOSTNAME}/squirrelmail/
EOF

    if [ X"${USE_RCM}" != X"YES" ]; then
        cat >> ${TIP_FILE} <<EOF
        - http://${HOSTNAME}/mail/
        - http://${HOSTNAME}/webmail/

EOF
    fi

    echo 'export status_sm_install="DONE"' >> ${STATUS_FILE}
}

sm_config_basic()
{
    ECHO_INFO "Setting up configuration file for SquirrelMail."

    cat >> ${SM_LOCAL_CONF} <<EOF
${CONF_MSG}
# Set domain name displayed in squirrelmail.
\$domain = "${FIRST_DOMAIN}";

# IMAP server address.
\$imapServerAddress = "${IMAP_SERVER}";

# IMAP server type: dovecot.
\$imap_server_type = 'dovecot';

# SMTP server address.
\$smtpServerAddress = "${SMTP_SERVER}";

# Enable SMTP AUTH while sending email.
\$smtp_auth_mech = 'login';

# attachment_dir
\$attachment_dir = "${SM_ATTACHMENT_DIR}";

# data_dir
\$data_dir = "${SM_DATA_DIR}";
    
# squirrelmail_default_language
\$squirrelmail_default_language = "${DEFAULT_LANG}";

# default_charset
\$default_charset = "${SM_DEFAULT_CHARSET}";

# Disable multiple identities.
\$edit_identity = false;

# Hide SM version number and other attributions in login page.
\$hide_sm_attributions = true;

# Folder name.
\$trash_folder = 'Trash';
\$sent_folder = 'Sent';
\$draft_folder = 'Draft';

EOF

    echo 'export status_sm_config_basic="DONE"' >> ${STATUS_FILE}
}

# Configuration for LDAP address book.
sm_config_ldap_address_book()
{
    ECHO_INFO "Setting up global LDAP address book."
    ${SM_CONF_PL} >/dev/null <<EOF
6
2
y
1
+
${LDAP_SERVER_HOST}
${LDAP_BASEDN}
${LDAP_SERVER_PORT}
utf-8
Global LDAP Address Book

${LDAP_BINDDN}
${LDAP_BINDPW}
3
d
S

Q
EOF

    echo 'export status_sm_config_ldap_address_book="DONE"' >> ${STATUS_FILE}
}

#
# For SquirrelMail translations.
#

convert_translation_locale()
{
    # convert_locale zh_CN zh_CN.GB2312 zh_CN.UTF8 gb2312 utf-8
    #                $1    $2           $3         $4     $5
    export language="$1"
    export locale_old="$2"
    export locale_new="$3"
    export charset_old="$4"
    export charset_new="$5"

    ECHO_INFO "Convert translation locale: $language"
    ECHO_INFO "LOCALE: $2 -> $3. CHARSET: $4 -> $5."

    if [ -d ${SM_HTTPD_ROOT}/locale/${language}/ ]; then
        cd ${SM_HTTPD_ROOT}/locale/${language}/LC_MESSAGES/
        cp squirrelmail.po squirrelmail.po.${charset_old}
        iconv -f ${charset_old} -t ${charset_new} squirrelmail.po.${charset_old} > squirrelmail.po

        cd ${SM_HTTPD_ROOT}/locale/${language}/
        cp setup.php setup.php.bak
        perl -pi -e 's/(.*)$ENV{"charset_old"}(.*)/$1$ENV{"charset_new"}$2/' setup.php
        perl -pi -e 's/(.*)$ENV{"locale_old"}(.*)/$1$ENV{"locale_new"}$2/' setup.php
    fi

    if [ -d ${SM_HTTPD_ROOT}/help/${language} ]; then

        cd ${SM_HTTPD_ROOT}/help/${language}

        for i in $(ls *); do
            cp $i $i.bak
            iconv -f ${charset_old} -t ${charset_new} $i.bak >$i
        done
    fi

    cd ${SM_HTTPD_ROOT}/functions/
    cp i18n.php i18n.php.bak
    perl -pi -e 's/(.*)$ENV{"charset_old"}(.*)/$1$ENV{"charset_new"}$2/' i18n.php
    perl -pi -e 's/(.*)$ENV{"locale_old"}(.*)/$1$ENV{"locale_new"}$2/' i18n.php

    echo 'export status_convert_translation_locale="DONE"' >> ${STATUS_FILE}
}

sm_translations()
{
    cd ${MISC_DIR}

    extract_pkg ${SM_TRANSLATIONS_TARBALL} /tmp
    
    ECHO_INFO "Copy SquirrelMail translations to ${SM_HTTPD_ROOT}/"
    cp -rf /tmp/locale/* ${SM_HTTPD_ROOT}/locale/
    cp -rf /tmp/images/* ${SM_HTTPD_ROOT}/images/
    cp -rf /tmp/help/* ${SM_HTTPD_ROOT}/help/

    convert_translation_locale 'zh_CN' 'zh_CN.GB2312' 'zh_CN.UTF8' 'gb2312' 'utf-8'
    convert_translation_locale 'zh_TW' 'zh_CN.BIG5' 'zh_CN.UTF8' 'big5' 'utf-8'

    echo 'export status_sm_translations="DONE"' >> ${STATUS_FILE}
}

#
# For squirrelmail plugin: compatibility.
#

sm_plugin_compatibility()
{
    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_COMPATIBILITY_TARBALL} ${SM_PLUGIN_DIR}

    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/compatibility/
    chmod -R 0755 ${SM_PLUGIN_DIR}/compatibility/

    echo 'export status_sm_plugin_compatibility="DONE"' >> ${STATUS_FILE}
}

#
# For squirrelmail plugin: Check Quota.
#

sm_plugin_check_quota()
{
    # Installation.
    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_CHECK_QUOTA_TARBALL} ${SM_PLUGIN_DIR}

    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/check_quota/
    chmod -R 0755 ${SM_PLUGIN_DIR}/check_quota/

    # Configure.
    ECHO_INFO "Generate configuration file for plugin: check_quota."
    cp ${SM_PLUGIN_DIR}/check_quota/config.sample.php ${SM_PLUGIN_DIR}/check_quota/config.php
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/check_quota/config.php
    chmod -R 0755 ${SM_PLUGIN_DIR}/check_quota/config.php

    ECHO_INFO "Configure plugin: check_quota."
    perl -pi -e 's/(.*)(quota_type)(.*)0;/${1}${2}${3}1;/' ${SM_PLUGIN_DIR}/check_quota/config.php

    echo 'export status_sm_plugin_check_quota="DONE"' >> ${STATUS_FILE}
}

#
# For SquirrelMail plugin: select_language.
#

sm_plugin_select_language()
{
    ECHO_INFO "Install SquirrelMail plugin: select language."

    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_SELECT_LANGUAGE_TARBALL} ${SM_PLUGIN_DIR}
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/select_language
    chmod -R 755 ${SM_PLUGIN_DIR}/select_language

    echo 'export status_sm_plugin_select_language="DONE"' >> ${STATUS_FILE}
}

#
# For SquirrelMail plugin: autosubscribe.
#
sm_plugin_autosubscribe()
{
    ECHO_INFO "Install SquirrelMail plugin: autosubscribe."

    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_AUTOSUBSCRIBE_TARBALL} ${SM_PLUGIN_DIR}
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/autosubscribe
    chmod -R 755 ${SM_PLUGIN_DIR}/autosubscribe

    cat > ${SM_PLUGIN_DIR}/autosubscribe/config.php <<EOF
<?php
\$autosubscribe_folders='Junk';
\$autosubscribe_special_folders='Sent,Drafts,Trash';
\$autosubscribe_all_delay = 0;
?>
EOF

    echo 'export status_sm_plugin_autosubscribe="DONE"' >> ${STATUS_FILE}
}

#
# For SquirrelMail plugin: email_footer.
#
sm_plugin_email_footer()
{
    ECHO_INFO "Install SquirrelMail plugin: Email Footer."

    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_EMAIL_FOOTER_TARBALL} ${SM_PLUGIN_DIR}
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/email_footer
    chmod -R 755 ${SM_PLUGIN_DIR}/email_footer

    cd ${SM_PLUGIN_DIR}/email_footer/ && \
    cp config.sample.php config.php && \
    perl -pi -e 's#^(=.*)#="";#' config.php && \
    perl -pi -e 's#^(\..*)##' config.php

    echo 'export status_sm_plugin_email_footer="DONE"' >> ${STATUS_FILE}
}

#
# For SquirrelMail plugin: login_auto.
#
sm_plugin_login_auto()
{
    ECHO_INFO "Install SquirrelMail plugin: login_auto."

    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_LOGIN_AUTO} ${SM_PLUGIN_DIR}
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/login_auto
    chmod -R 755 ${SM_PLUGIN_DIR}/login_auto

    cd ${SM_PLUGIN_DIR}/login_auto/ && \
    cp config.php.sample config.php && \
    perl -pi -e 's#(.*login_.*=.*)#//${1}#' config.php && \
    chmod 0000 *sample INSTALL README version

    echo 'export status_sm_plugin_login_auto="DONE"' >> ${STATUS_FILE}
}

#
# For squirrelmail plugin: add_address.
#

sm_plugin_add_address()
{
    ECHO_INFO "Install SquirrelMail plugin: add_address."

    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_ADD_ADDRESS} ${SM_PLUGIN_DIR}
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/add_address/
    chmod -R 0755 ${SM_PLUGIN_DIR}/add_address/

    echo 'export status_sm_plugin_add_address="DONE"' >> ${STATUS_FILE}
}

#
# For SquirrelMail plugin: avelsieve.
#
sm_plugin_avelsieve()
{
    ECHO_INFO "Install SquirrelMail plugin: avelsieve."

    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_AVELSIEVE} ${SM_PLUGIN_DIR}
    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}/avelsieve
    chmod -R 755 ${SM_PLUGIN_DIR}/avelsieve

    # Patch file reference:
    # http://woozle.org/list-archives/pysieved/msg00227.html
    cd ${SM_PLUGIN_DIR}/avelsieve/ && \
    cp config_sample.php config.php && \
    perl -pi -e 's#(.*preferred_mech.*=.*)(PLAIN)(";)#${1}LOGIN${3}#' config.php && \
    patch -p0 < ${PATCH_DIR}/squirrelmail/sieve-php.lib.php.patch >/dev/null

    echo 'export status_sm_plugin_avelsieve="DONE"' >> ${STATUS_FILE}
}

#
# LDAP backend.
#
# For squirrelmail plugin: change_ldappass.
#

sm_plugin_change_ldappass()
{
    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_CHANGE_LDAPPASS_TARBALL} ${SM_PLUGIN_DIR}

    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}
    chmod -R 0755 ${SM_PLUGIN_DIR}

    cd ${SM_PLUGIN_DIR}/change_ldappass/

    ECHO_INFO "Generate configration file: ${SM_PLUGIN_DIR}/change_ldappass/config.php."
    cat >${PLUGIN_CHANGE_LDAPPASS_CONFIG} <<EOF
<?php
${CONF_MSG}
\$ldap_server = 'ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}';
\$ldap_protocol_version = ${LDAP_BIND_VERSION};
\$ldap_password_field = "${LDAP_ATTR_USER_PASSWD}";
\$ldap_user_field = "${LDAP_ATTR_USER_RDN}";
\$ldap_base_dn = '${LDAP_BASEDN}';
\$ldap_filter = "(&(objectClass=${LDAP_OBJECTCLASS_MAILUSER})(${LDAP_ATTR_ACCOUNT_STATUS}=${LDAP_STATUS_ACTIVE})(${LDAP_ENABLED_SERVICE}=${LDAP_SERVICE_MAIL}))";
\$query_dn="${LDAP_BINDDN}";
\$query_pw="${LDAP_BINDPW}";
\$ldap_bind_as_manager = false;
\$ldap_bind_as_manager = false;
\$ldap_manager_dn='';
\$ldap_manager_pw='';
\$change_smb=false;
\$debug=false;
?>
EOF

    chown ${HTTPD_USER}:${HTTPD_GROUP} ${PLUGIN_CHANGE_LDAPPASS_CONFIG}
    chmod 644 ${PLUGIN_CHANGE_LDAPPASS_CONFIG}

    echo 'export status_sm_plugin_change_ldappass="DONE"' >> ${STATUS_FILE}
}

#
# MySQL backend.
#
sm_plugin_change_sqlpass()
{
    cd ${MISC_DIR}
    extract_pkg ${PLUGIN_CHANGE_SQLPASS_TARBALL} ${SM_PLUGIN_DIR}

    chown -R ${HTTPD_USER}:${HTTPD_GROUP} ${SM_PLUGIN_DIR}
    chmod -R 0755 ${SM_PLUGIN_DIR}

    cd ${SM_PLUGIN_DIR}/change_sqlpass/

    ECHO_INFO "Generate configration file: ${SM_PLUGIN_DIR}/change_sqlpass/config.php."
    cat >${PLUGIN_CHANGE_SQLPASS_CONFIG} <<EOF
<?php
   global \$csp_dsn, \$password_update_queries, \$lookup_password_query,
          \$force_change_password_check_query, \$password_encryption,
          \$csp_salt_query, \$csp_salt_static, \$csp_secure_port,
          \$csp_non_standard_http_port, \$csp_delimiter, \$csp_debug,
          \$min_password_length, \$max_password_length, \$include_digit_in_password,
          \$include_uppercase_letter_in_password, \$include_lowercase_letter_in_password,
          \$include_nonalphanumeric_in_password;

\$csp_dsn = "mysql://${MYSQL_ADMIN_USER}:${MYSQL_ADMIN_PW}@${MYSQL_SERVER}/${VMAIL_DB}";
\$lookup_password_query = 'SELECT count(*) FROM mailbox WHERE username = "%1" AND password = %4';
\$password_update_queries = array('UPDATE mailbox SET password = %4 WHERE username = "%1"');
\$force_change_password_check_query = '';
\$password_encryption = 'MYSQLENCRYPT';
\$csp_salt_static = 'password';
\$csp_salt_query = 'SELECT salt FROM users WHERE username = "%1"';
\$csp_secure_port = 0;
\$csp_non_standard_http_port = 0;
\$min_password_length = 6;
\$max_password_length = 0;
\$include_digit_in_password = 0;
\$include_uppercase_letter_in_password = 0;
\$include_lowercase_letter_in_password = 0;
\$include_nonalphanumeric_in_password = 0;
\$csp_delimiter = '@';
\$csp_debug = 0;
?>
EOF

    chown ${HTTPD_USER}:${HTTPD_GROUP} ${PLUGIN_CHANGE_SQLPASS_CONFIG}
    chmod 644 ${PLUGIN_CHANGE_SQLPASS_CONFIG}

    echo 'export status_sm_plugin_change_sqlpass="DONE"' >> ${STATUS_FILE}
}

# --------------------
# Enable all plugins.
# --------------------
enable_sm_plugins()
{
    # We do *NOT* use 'conf.pl' to enable plugins, because it's not easy to
    # control in non-interactive mode, so we use 'perl' to modify the config
    # file directly.

    if [ X"${BACKEND}" == X"OpenLDAP" ]; then
        ENABLED_SM_PLUGINS="${ENABLED_SM_PLUGINS} change_ldappass"
    elif [ X"${BACKEND}" == X"MySQL" ]; then
        ENABLED_SM_PLUGINS="${ENABLED_SM_PLUGINS} change_sqlpass"
    else
        :
    fi

    # Disable all exist plugins first.
    perl -pi -e 's|(^\$plugins.*)|#${1}|' ${SM_CONFIG}

    if [ ! -z "${ENABLED_SM_PLUGINS}" ]; then
        ECHO_INFO "Enable SquirrelMail plugins: ${ENABLED_SM_PLUGINS}."

        counter=0

        for i in ${ENABLED_SM_PLUGINS}; do
            echo "\$plugins[${counter}]='$(echo $i)';" >> ${SM_LOCAL_CONF}
            counter=$((counter+1))
        done
    else
        :
    fi

    echo 'export status_enable_sm_plugins="DONE"' >> ${STATUS_FILE}
}

# --------------------
# Install all plugins.
# --------------------
sm_plugin_all()
{
    # Install all plugins.
    check_status_before_run sm_plugin_compatibility
    check_status_before_run sm_plugin_check_quota
    check_status_before_run sm_plugin_select_language
    check_status_before_run sm_plugin_autosubscribe
    check_status_before_run sm_plugin_email_footer
    check_status_before_run sm_plugin_login_auto
    check_status_before_run sm_plugin_add_address

    # Enable avelsieve plugin.
    if [ X"${USE_MANAGESIEVE}" == X"YES" ]; then
        check_status_before_run sm_plugin_avelsieve
    else
        :
    fi

    # Backend depend.
    if [ X"${BACKEND}" == X"OpenLDAP" ]; then
        check_status_before_run sm_plugin_change_ldappass
    elif [ X"${BACKEND}" == X"MySQL" ]; then
        check_status_before_run sm_plugin_change_sqlpass
    else
        :
    fi

    # Enable all defined plugins.
    check_status_before_run enable_sm_plugins
}

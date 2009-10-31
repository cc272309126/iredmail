#!/usr/bin/env bash

# Author: Zhang Huangbin <michaelbibby (at) gmail.com>

# -------------------------------------------
# Install all optional components.
# -------------------------------------------
optional_components()
{
    # SquirrelMail.
    if [ X"${USE_SM}" == X"YES" ]; then
        # ------------------------------------------------
        # SquirrelMail and plugins.
        # ------------------------------------------------
        check_status_before_run sm_install && \
        check_status_before_run sm_config_basic

        if [ X"${BACKEND}" == X"OpenLDAP" ]; then
            check_status_before_run sm_config_ldap_address_book
        else
            :
        fi
        
        # SquirrelMail Translations.
        check_status_before_run sm_translations

        # Plugins.
        check_status_before_run sm_plugin_all
    else
        :
    fi

    # Roundcubemail.
    [ X"${USE_RCM}" == X"YES" ] && \
        check_status_before_run rcm_install && \
        check_status_before_run rcm_config_sieverules && \
        check_status_before_run rcm_config

    # phpLDAPadmin.
    [ X"${USE_PHPLDAPADMIN}" == X"YES" ] && \
        check_status_before_run pla_install

    # phpMyAdmin
    [ X"${USE_PHPMYADMIN}" == X"YES" ] && \
        check_status_before_run phpmyadmin_install

    # PostfixAdmin.
    [ X"${USE_POSTFIXADMIN}" == X"YES" ] && \
        check_status_before_run postfixadmin_install

    # Awstats.
    [ X"${USE_AWSTATS}" == X"YES" ] && \
        check_status_before_run awstats_config_basic && \
        check_status_before_run awstats_config_weblog && \
        check_status_before_run awstats_config_maillog && \
        check_status_before_run awstats_config_crontab

    # iRedAdmin.
    [ X"${USE_IREDADMIN}" == X"YES" ] && \
        check_status_before_run iredadmin_config
}

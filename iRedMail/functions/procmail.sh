#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb(at)iredmail.org>

procmail_config()
{
    ECHO_INFO "Configure Procmail (MDA)."

    ECHO_DEBUG "Copy ${SAMPLE_DIR}/procmailrc as ${PROCMAILRC}."
    backup_file ${PROCMAILRC}
    cp -f ${SAMPLE_DIR}/procmailrc ${PROCMAILRC}

    ECHO_DEBUG "Add procmail as postfix transport in ${POSTFIX_FILE_MASTER_CF}."
    cat >> ${POSTFIX_FILE_MASTER_CF} <<EOF
procmail unix    -       n       n       -       -      pipe
  flags=DRhu user=${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} argv=${PROCMAIL_BIN} -r -t SENDER=\${sender} RECIPIENT=\${recipient} DOMAIN=\${nexthop} -m USER=\${user} EXTENSION=\${extension} ${PROCMAILRC}
EOF

    if [ X"${TRANSPORT}" == X"procmail" ]; then
        ECHO_DEBUG "Setup transport in Postfix."
        postconf -e mailbox_command="${PROCMAIL_BIN} -f- -a \${EXTENSION}"
    fi

    ECHO_DEBUG "Setup procmail log file: ${PROCMAIL_LOGFILE}."
    touch ${PROCMAIL_LOGFILE}
    chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${PROCMAIL_LOGFILE}
    chmod 0700 ${PROCMAIL_LOGFILE}

    if [ X"${KERNEL_NAME}" == X"Linux" ]; then
        ECHO_DEBUG "Setup logrotate for procmail log file: ${PROCMAIL_LOGFILE}."
        cat >> ${PROCMAIL_LOGROTATE_FILE} <<EOF
${PROCMAIL_LOGFILE} {
    compress
    weekly
    rotate 10
    create 0600 vmail vmail
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2 

    postrotate
        ${SYSLOG_POSTROTATE_CMD}
    endscript
}
EOF
    fi

    echo 'export status_procmail_config="DONE"' >> ${STATUS_FILE}
}

#!/bin/bash

# Half automated mail server installation script.
# Copyright (C) <2015>  <Stefan Dietrich>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


POSTFIX_DIR="/etc/postfix"
VIRTUAL_DIR=""${POSTFIX_DIR}"/virtual"
DOVECOT_DIR="/etc/dovecot"


IsRoot()
{
# Make sure only root can run our script
    if [[ "$(id -u)" != "0" ]]
    then
	echo "This script must be run as root" 1>&2
	exit 1
    fi
}

SetDBUsername()
{
#Set the username for the MySQL mail database and for the system

    local DEFAULT_USER="vmail"

    read -p "Please enter a username (it will be used for the MySQL mail database and as systemuser for the mail system), default is ["${DEFAULT_USER}"]: " VMAIL_USER
    VMAIL_USER=${VMAIL_USER:-$DEFAULT_USER}
}

SetDBPassword()
{
#Set the user password for the MySQL mail database

    while [[ -z "${VMAILPASSWD}" ]];do
    read -p "Please enter a new password for your MySQL mail database: " VMAILPASSWD
done
    
}

SetMailDBName()
{
#Set a name for the MySQL mail database

    local DEFAULT_DB="vmail"

    read -p "Please enter a name for your MySQL mail database, default is ["${DEFAULT_DB}"]: " VMAILDB
    VMAILDB=${VMAILDB:-$DEFAULT_DB}
}

SetDomain()
{
#Set the domain


    while ! [[ "${DOMAIN}" =~ ^[a-zA-Z0-9.-]{2,}$ ]];do
    read -p "Please enter your domain (e.g. example.com): " DOMAIN
done

}

SetMailUser()
{
#Set the mail account for the mail system


    while ! [[ "${MAILUSER}" =~ ^[a-z0-9._-]{2,}$ ]];do
    read -p "Please enter a name for the mail account (e.g. for test@example.org you have to enter test): " MAILUSER
done


}

SetUserMailPWD()
{
#Set the password for the mail account

    
    read -p "Please enter a password for your "${MAILUSER}"@"${DOMAIN}" account: " MAILUSERPWD 


    if [[ -n "$MAILUSERPWD" ]]; then
    MAILUSERCRYPTPASS="$(doveadm pw -p "$MAILUSERPWD" -s SHA512-CRYPT)"
fi

}


InstallRequiredPackage()
{

#Install the required packages

    local INSTALL_PACKAGES=(mysql-server dovecot-common dovecot-imapd dovecot-mysql dovecot-lmtpd postfix postfix-mysql)
    apt-get update
    apt-get -y install ${INSTALL_PACKAGES[*]}
}

CreateUser()
{
#Add the user for the mail enviroment

    local VMAIL_DIR="/var/vmail"

    if [[ $? -eq 0 ]]
    then
	echo "Will create ${VMAIL_DIR} ${VMAIL_USER}" && useradd "${VMAIL_USER}" && mkdir -p "${VMAIL_DIR}" && chown -R "${VMAIL_USER}":"${VMAIL_USER}" "${VMAIL_DIR}" && chmod -R 770 "${VMAIL_DIR}" && echo "done"
    else
	echo "Something went wrong with the installtion"
    fi
}

CreateMailDir()
{
#create the postfix virtual dir

    if [[ ! -d ${VIRTUAL_DIR} ]]
    then 
	echo "Creating the Directory ${VIRTUAL_DIR}"
	mkdir -p "${VIRTUAL_DIR}" && chmod 660 "${VIRTUAL_DIR}" && echo "Successfully created"

    fi

}

CreatePostfixMySQLFiles()
{
#create the files for /etc/postfix/virtual

    local CONF_ALIASES=""${VIRTUAL_DIR}"/mysql-aliases.cf"
    local CONF_DOMAINS=""${VIRTUAL_DIR}"/mysql-domains.cf"
    local CONF_MAPS=""${VIRTUAL_DIR}"/mysql-maps.cf"
    local CONF_LOGIN=""${VIRTUAL_DIR}"/sender-login-maps.cf"
	

    cat <<EOF >"${CONF_ALIASES}"
user = ${VMAIL_USER}
password = ${VMAILPASSWD}
hosts = 127.0.0.1
dbname = ${VMAILDB}
query = SELECT destination FROM aliases WHERE source='%s' UNION SELECT CONCAT(username, '@', domain) AS destination FROM users WHERE CONCAT(username, '@', domain)='%s'
EOF

    cat <<EOF >"${CONF_DOMAINS}"
user = ${VMAIL_USER}
password = ${VMAILPASSWD}
hosts = 127.0.0.1
dbname = ${VMAILDB}
query = SELECT * FROM domains WHERE domain='%s'
EOF

    cat <<EOF >"${CONF_MAPS}"
user = ${VMAIL_USER}
password = ${VMAILPASSWD}
hosts = 127.0.0.1
dbname = ${VMAILDB}
query = SELECT * FROM users WHERE username='%u' AND domain='%d'
EOF


    cat <<EOF >"${CONF_LOGIN}"
user = ${VMAIL_USER}
password = ${VMAILPASSWD}
hosts = 127.0.0.1
dbname = ${VMAILDB}
query = SELECT concat(username, '@', domain) FROM users WHERE username='%u' AND domain='%d'
EOF

cd "$POSTFIX_DIR"
mv main.cf main.cf.bak && cat <<EOF > main.cf

smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no

append_dot_mydomain = no

readme_directory = no

mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mydestination = \$myhostname, localhost.${DOMAIN}, localhost
mailbox_size_limit = 51200000
message_size_limit = 51200000
recipient_delimiter =
inet_interfaces = all
mydomain = ${DOMAIN}
myorigin = \$mydomain
myhostname = mail.${DOMAIN}
inet_protocols = all

##### TLS parameters ######
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

###### SASL Auth ######
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes

###### Use Dovecot LMTP Service to deliver Mails to Dovecot ######
virtual_transport = lmtp:unix:private/dovecot-lmtp

##### Only allow mail transport if client is authenticated or in own network (PHP Scripts, ...) ######
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

###### MySQL Connection ######

virtual_alias_maps = mysql:/etc/postfix/virtual/mysql-aliases.cf
virtual_mailbox_maps = mysql:/etc/postfix/virtual/mysql-maps.cf
virtual_mailbox_domains = mysql:/etc/postfix/virtual/mysql-domains.cf
local_recipient_maps = \$virtual_mailbox_maps

smtpd_sender_login_maps = mysql:/etc/postfix/virtual/sender-login-maps.cf
smtpd_sender_restrictions = permit_mynetworks, reject_non_fqdn_sender, reject_sender_login_mismatch, permit_sasl_authenticated

EOF

}

CreateDovecotConf()
{
#Backup and create the dovecot config file

cd "$DOVECOT_DIR"
mv dovecot.conf dovecot.conf.bak && cat <<EOF > dovecot.conf

# Enable installed protocols
!include_try /usr/share/dovecot/protocols.d/*.protocol

listen = *, ::

base_dir = /var/run/dovecot/

# Greeting message for clients.
login_greeting = Dovecot ready.

!include conf.d/*.conf
!include_try local.conf

# Passdb SQL
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}
namespace inbox {
    mailbox Spam {
        auto = subscribe
        special_use = \Junk
    }

    mailbox Drafts { 
        auto = create 
        special_use = \Drafts  
    }
}
EOF

}


CreateMailDB()
{
#SQL commands

    Q1="create database "${VMAILDB}";"
    Q2="use "${VMAILDB}";"
    Q3="create table users (id INT UNSIGNED AUTO_INCREMENT NOT NULL, username VARCHAR(128) NOT NULL, domain VARCHAR(128) NOT NULL, password VARCHAR(128) NOT NULL, UNIQUE (id), PRIMARY KEY (username, domain) );"
    Q4="create table domains (domain VARCHAR(128) NOT NULL, UNIQUE (domain));"
    Q5="create table aliases (id INT UNSIGNED AUTO_INCREMENT NOT NULL, source VARCHAR(128) NOT NULL, destination VARCHAR(128) NOT NULL, UNIQUE (id), PRIMARY KEY (source, destination) );"
    Q6="GRANT ALL ON "${VMAILDB}".* TO '"${VMAIL_USER}"'@'localhost' IDENTIFIED BY '"${VMAILPASSWD}"' WITH GRANT OPTION;"
    Q7="FLUSH PRIVILEGES;"
    Q8="insert into domains (domain) values ('"$DOMAIN"');"
    Q9="insert into users (username, domain, password) values ('"${MAILUSER}"', '"${DOMAIN}"', '"${MAILUSERCRYPTPASS}"');"
    Q10="insert into aliases (source, destination) values ('@"${DOMAIN}"', '"${MAILUSER}"@"${DOMAIN}"');"
    SQL="${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}${Q10}"

    read -p "Please enter your Mysql root passwort: " MYSQL_ROOTPWD
    mysql -u root -p"${MYSQL_ROOTPWD}" -e "${SQL}"

}

EditConfigFiles()

{
#Backup the config files

cp /etc/dovecot/conf.d/15-lda.conf /etc/dovecot/conf.d/15-lda.conf.bac
cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.bac
cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.bac
cp /etc/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext.bac
cp /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl-conf.bac

#Edit line in 15-lda.conf (needs a fix)

    #sed -i 's/#postmaster_address.*/postmaster_adress = '"${MAILUSER}"'@'"${DOMAIN}"'/' /etc/dovecot/conf.d/15-lda.conf

#Edit lines in 10-auth.conf

    sed -i 's/!include auth-system.conf.ext/#!include auth-system.conf.ext/g' /etc/dovecot/conf.d/10-auth.conf
    sed -i 's/#disable_plaintext_auth.*/disable_plaintext_auth = yes/g' /etc/dovecot/conf.d/10-auth.conf
    sed -i 's/auth_mechanisms.*/auth_mechanisms = plain login/g' /etc/dovecot/conf.d/10-auth.conf

#Edit lines in 10-mail.conf

    sed -i 's/^mail_location = mbox.*/mail_location = maildir:~\/mail:LAYOUT=fs/' /etc/dovecot/conf.d/10-mail.conf
    sed -i "/^mail_location = maildir:~\/mail:LAYOUT=fs/ a mail_home = \/var\/vmail\/%d\/%n/" /etc/dovecot/conf.d/10-mail.conf
    sed -i 's/#mail_uid =/mail_uid = '"${VMAIL_USER}"'/g' /etc/dovecot/conf.d/10-mail.conf
    sed -i 's/#mail_gid =/mail_gid = '"${VMAIL_USER}"'/g' /etc/dovecot/conf.d/10-mail.conf
    sed -i 's/#mail_privileged_group =/mail_privileged_group = '"${VMAIL_USER}"'/g' /etc/dovecot/conf.d/10-mail.conf

#Edit lines in dovecot-sql.conf.ext

    sed -i 's/#driver =.*/driver = mysql/' /etc/dovecot/dovecot-sql.conf.ext
    sed -i 's/#connect =.*/connect = host=127.0.0.1 dbname='"${VMAILDB}"' user='"${VMAIL_USER}"' password='"${VMAILPASSWD}"'/' /etc/dovecot/dovecot-sql.conf.ext
    sed -i 's/#default_pass_scheme =.*/default_pass_scheme = SHA512-CRYPT/' /etc/dovecot/dovecot-sql.conf.ext

    sed -i '0,/#password_query = \\/s//password_query = \\/' /etc/dovecot/dovecot-sql.conf.ext
    sed -i '0,/#  SELECT username, domain, password \\/s//SELECT username, domain, password \\/' /etc/dovecot/dovecot-sql.conf.ext
    sed -i "0,/#  FROM users WHERE username = '%n' AND domain = '%d'/s//FROM users WHERE username = '%n' AND domain = '%d'/" /etc/dovecot/dovecot-sql.conf.ext
    sed -i 's/#iterate_query = SELECT username.*/iterate_query = SELECT username, domain FROM users/' /etc/dovecot/dovecot-sql.conf.ext
	
#Edit lines in d 10-ssl.conf

   sed -i 's/#ssl =.*/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf
   sed -i 's/#ssl_protocols =.*/ssl_protocols = !SSLv2 !SSLv3/g' /etc/dovecot/conf.d/10-ssl.conf
   sed -i 's/#ssl_cipher_list =.*/ssl_cipher_list = EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:+CAMELLIA256:+AES256:+CAMELLIA128:+AES128:SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!ECDSA:CAMELLIA256-SHA:AES256-SHA:CAMELLIA128-SHA:AES128-SHA/g' /etc/dovecot/conf.d/10-ssl.conf
   

}




Main()
{
    IsRoot
    SetDBUsername
    SetDBPassword
    SetMailDBName
    SetDomain
    SetMailUser
    InstallRequiredPackage
    SetUserMailPWD
    CreateUser
    CreateMailDir
    CreatePostfixMySQLFiles
    CreateDovecotConf
    CreateMailDB
    EditConfigFiles
}

Main

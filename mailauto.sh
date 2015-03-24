#!/bin/bash

VIRTUAL_DIR="/etc/postfix/virtual"

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

    local DEFAULT_USER="vmail"

#Set the user for the DB
    read -p "Please enter a username for your Mail-DB, default is [$DEFAULT_USER]: " VMAIL_USER
    VMAIL_USER=${VMAIL_USER:-$DEFAULT_USER}
}

SetDBPassword()
{
#Set the password and the name for mail database
    read -p "Please enter a new password for your Mail-DB: " VMAILPASSWD
}

SetMailDBName()
{

    local DEFAULT_DB="vmail"

    read -p "Please enter a name for your Mail-DB, default is [$DEFAULT_DB]: " VMAILDB
    VMAILDB=${VMAILDB:-$DEFAULT_DB}
}

SetDomain()
{
    read -p "Please enter your domain (e.g. example.com): " DOMAIN

}

SetMailUser()
{

    read -p "Please enter a name for the mail account (e.g. for test@example.org you have to enter test): " MAILUSER
}

SetUserMailPWD()
{

    read -p "Please enter a password for the mail account itself: " MAILUSERPWD 

    if [[ -n "$MAILUSERPWD" ]]; then
    MAILUSERCRYPTPASS="$(doveadm pw -p $MAILUSERPWD -s SHA512-CRYPT)"
fi

}


InstallRequiredPackage()
{

# Install the required packages
    local INSTALL_PACKAGES=(mysql-server dovecot-common dovecot-imapd dovecot-mysql dovecot-lmtpd postfix postfix-mysql php5 php5-mysql)

    apt-get -y install ${INSTALL_PACKAGES[*]}
}

CreateUser()
{

    local VMAIL_DIR="/var/vmail"

#Add the user for the mail enviroment

    if [[ $? -eq 0 ]]
    then
	echo "Will create ${VMAIL_DIR} ${VMAIL_USER}" && useradd "${VMAIL_USER}" && mkdir -p "${VMAIL_DIR}" && chown -R "${VMAIL_USER}":"${VMAIL_USER}" "${VMAIL_DIR}" && chmod -R 770 "${VMAIL_DIR}" && echo "done"
    else
	echo "Something went wrong with the installtion"
    fi
}

CreateMailDir()
{


    if [[ ! -d ${VIRTUAL_DIR} ]]
    then 
	echo "Creating the Directory ${VIRTUAL_DIR}"
	mkdir -p "${VIRTUAL_DIR}" && chmod 660 "${VIRTUAL_DIR}" && echo "Successfully created"

    fi

}

CreatePostfixFile()
{

    local CONF_ALIASES=""${VIRTUAL_DIR}"/mysql-aliases.cf"
    local CONF_DOMAINS=""${VIRTUAL_DIR}"/mysql-domains.cf"
    local CONF_MAPS=""${VIRTUAL_DIR}"/mysql-maps.cf"

#create the files for /etc/postfix/virtual

    cat <<EOF >"${CONF_ALIASES}"
user = "${VMAIL_USER}"
password = "${VMAILPASSWD}"
hosts = 127.0.0.1
dbname = "${VMAILDB}"
query = SELECT destination FROM aliases WHERE source='%s'
EOF

    cat <<EOF >"${CONF_DOMAINS}"
user = "${VMAIL_USER}"
password = "${VMAILPASSWD}"
hosts = 127.0.0.1
dbname = "${VMAILDB}"
query = SELECT * FROM domains WHERE domain='%s'
EOF

    cat <<EOF >"${CONF_MAPS}"
user = "${VMAIL_USER}"
password = "${VMAILPASSWD}"
hosts = 127.0.0.1
dbname = "${VMAILDB}"
query = SELECT * FROM users WHERE username='%u' AND domain='%d'
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
    Q6="GRANT ALL ON "$VMAILDB".* TO '"$VMAIL_USER"'@'localhost' IDENTIFIED BY '"$VMAILPASSWD"' WITH GRANT OPTION;"
    Q7="FLUSH PRIVILEGES;"
    Q8="insert into domains (domain) values ('"$DOMAIN"‘);"
    Q9="insert into users (username, domain, password) values ('"$MAILUSER"', '"$DOMAIN"', '"$MAILUSERCRYPTPASS"');"
    SQL="${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"

    read -p "Please enter your Mysql root passwort: " MYSQL_ROOTPWD
    mysql -u root -p"${MYSQL_ROOTPWD}" -e "$SQL"

}

Main()
{
    IsRoot
    SetDBUsername
    SetDBPassword
    SetMailDBName
    SetDomain
    SetMailUser
    SetUserMailPWD
InstallRequiredPackage
    CreateUser
    CreateMailDir
    CreatePostfixFile
    CreateMailDB
}

Main

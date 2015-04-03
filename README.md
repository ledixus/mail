# Mail

## Contact

ledixus@icloud.com

## License

GPLv3 or later, see Copying

## Automated Mailserver

A little bash script, which does the most work
to setup a mail server. It's based on the
tutorial from <https://www.thomas-leister.de>

You can find the complete tutorial here <https://thomas-leister.de/internet/mailserver-ubuntu-server-dovecot-postfix-mysql/>

At the moment it isn't complete and it needs a bit more testing.


## After the script was successful

If you used another value for ***vmail***, you have to adjust ***vmail*** to your value.

/etc/dovecot/conf.d/

Edit the file **10-mail.conf**

	mail_home = /var/vmail/%d/%n  
	mail_location = maildir:~/mail:LAYOUT=fs  
	mail_uid = vmail  
	mail_gid = vmail  
	mail_privileged_group = vmail   


/etc/dovecot/

Edit the file **dovecot-sql.conf.ext**

#####Replace the dbname, user and password with values which you entered in the srcipt.

	driver = mysql
	connect = host=127.0.0.1 dbname=REPLACEME user=REPLACEME password=REPLACEME
	default_pass_scheme = SHA512-CRYPT
	password_query = \
	SELECT username, domain, password \
	FROM users WHERE username = '%n' AND domain = '%d'

#####change
	#iterate_query = SELECT username, domain FROM users
#####to
	iterate_query = SELECT username, domain FROM users


/etc/dovecot/conf.d/ 

Edit the file **10-auth.conf**

	disable_plaintext_auth = yes
	auth_mechanisms = plain login
	
#####change
	iterate_query = SELECT username, domain FROM users
#####to
	#iterate_query = SELECT username, domain FROM users
	
/etc/dovecot/conf.d/

Edit the file **10-master.conf** 

	service auth {
    	unix_listener auth-userdb {
        mode = 0600
        user = vmail
        group = vmail
    }

    # Postfix smtp-auth
    unix_listener /var/spool/postfix/private/auth {
        mode = 0660
        user = postfix
        group = postfix
      }
	}
	
	service lmtp {
    unix_listener /var/spool/postfix/private/dovecot-lmtp {
      mode = 0660
      group = postfix
      user = postfix
    }
    user = vmail
	}

/etc/dovecot/conf.d/

Edit the file **15-lda.conf**

	set a adress if the mail transport isnt successful
	postmaster_address =


/etc/dovecot/conf.d/

Edit the file **10-ssl.conf**

	ssl = required
	ssl_cert = </etc/dovecot/dovecot.pem
	ssl_key = </etc/dovecot/private/dovecot.pem
	ssl_cipher_list = EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:+CAMELLIA256:+AES256:+CAMELLIA128:+AES128:SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!ECDSA:CAMELLIA256-SHA:AES256-SHA:CAMELLIA128-SHA:AES128-SHA
	
	ssl_protocols = !SSLv2 !SSLv3
	
	can cause problems:
	ssl_prefer_server_ciphers = yes
	

/etc/posfix/

Edit the file **master.cf**

Delete the complete "submission" Block including the -o parameters and replace with it the following block

	submission inet n       -       -       -       -       smtpd -v
  	-o syslog_name=postfix/submission
  	-o smtpd_tls_security_level=encrypt
  	-o smtpd_sasl_type=dovecot
  	-o smtpd_sasl_path=private/auth
  	-o smtpd_sasl_security_options=noanonymous
  	-o smtpd_sasl_auth_enable=yes
  	-o smtpd_client_restrictions=permit_sasl_authenticated,reject
  	
#####If everything is done, restart dovecot and postfix.

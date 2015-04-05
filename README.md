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

Edit the file **10-ssl.conf**

			
***Only set this if you're using Dovecot 2.2.6 or higher!***

	ssl_prefer_server_ciphers = yes
	

/etc/posfix/

Edit the file **master.cf**

Delete the complete "submission" Block including the -o parameters and replace it with the following block

	submission inet n       -       -       -       -       smtpd -v
  	-o syslog_name=postfix/submission
  	-o smtpd_tls_security_level=encrypt
  	-o smtpd_sasl_type=dovecot
  	-o smtpd_sasl_path=private/auth
  	-o smtpd_sasl_security_options=noanonymous
  	-o smtpd_sasl_auth_enable=yes
  	-o smtpd_client_restrictions=permit_sasl_authenticated,reject
  	
#####If everything is done, restart dovecot and postfix.

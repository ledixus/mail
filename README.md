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

Change the line in **15-lda.conf**

	#postmaster_adress = 

***to***

	postmaster_adress = yourmail@example.com


	
/etc/dovecot/conf.d/

Edit the file **10-master.conf** and change these sections like this:

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

Delete the complete "submission" block including the -o parameters and replace it with the following block

	submission inet n       -       -       -       -       smtpd -v
  	  -o syslog_name=postfix/submission
  	  -o smtpd_tls_security_level=encrypt
  	  -o smtpd_sasl_type=dovecot
  	  -o smtpd_sasl_path=private/auth
  	  -o smtpd_sasl_security_options=noanonymous
  	  -o smtpd_sasl_auth_enable=yes
  	  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  	
**Make sure that you have set correct DNS Records. Here is an example.**

Host             | Type  | Data                         | TTL
-----------------|-------|------------------------------|--------
example.org      | A     | 10.20.30.40                  | 
imap.example.org | CNAME | example.org                  |
smtp.example.org | CNAME | example.org                  |
example.org      | PTR   | 40.30.20.10.in-addr.arpa     |
example.org      | MX    | example.org.                 | 10
example.org		 | TXT   | v=spf1 a mx ptr ip4:10.20.30.40 ptr:example.org mx:example.org -all

***Replace example.org with your domain and 10.20.30.40 with your server IP.***

-----
***And don't forget to open the ports 143 and 587.***

-----
  	          
#####If everything is done, restart dovecot and postfix.

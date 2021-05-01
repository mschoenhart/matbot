function setupgmail(mailaddress,password)
%SETUP GMAIL to send emails via GMAIL SMTP-Server.

    setpref('Internet','E_mail',mailaddress);
    setpref('Internet','SMTP_Server','smtp.gmail.com');
    setpref('Internet','SMTP_Username',mailaddress);
    setpref('Internet','SMTP_Password',password);

    props=java.lang.System.getProperties;
    props.setProperty('mail.smtp.auth','true');
    props.setProperty('mail.smtp.socketFactory.class',...
                      'javax.net.ssl.SSLSocketFactory');
    props.setProperty('mail.smtp.socketFactory.port','465');

end

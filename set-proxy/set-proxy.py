#!/usr/bin/python
# -*- coding: utf-8 -*-

#Скрипт, предназначенный для обновления конфигурации nginx-proxy при добавлении/удалении/измении виртуальных хостов на бэкэнде.
import string, commands, sys, paramiko, nginx, os, re

SSH_HOST_ADDR = '128.0.0.1'
REMOTE_VHOSTS_DIR = '/etc/nginx/vhosts-proxies'
REMOTE_CERTS_DIR = '/etc/nginx/ssl/certs'
REMOTE_KEYS_DIR = '/etc/nginx/ssl/keys'
NGINX_RELOAD_COMMAND = 'systemctl reload nginx'
PROXY_CONFIG_TMPL = """
server {{
        listen 213.184.250.42:443 ssl;
        server_name {0};
        ssl on;
        ssl_certificate "/etc/nginx/ssl/certs/{1}";
        ssl_certificate_key "/etc/nginx/ssl/keys/{2}";
        ssl_ciphers {3};
        ssl_prefer_server_ciphers {4};
        ssl_protocols {5};

        location / {{
                proxy_set_header Host $host:$server_port;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_pass https://128.0.1.1;
                proxy_request_buffering off;
        }}
}}

"""

def addproxy( filepath ):
    if not os.path.isfile(filepath):
        exit(1)
    
    with open( filepath ) as file:
        vhost_config = file.read()
    conf_root = nginx.loads(vhost_config);

    for server in conf_root.query('server'):
        node = server.query('ssl', first = True)
        if node != False and 'on' == str(node):
            server_name = str(server.query('server_name', first = True))
            ssl_certificate = str(server.query('ssl_certificate', first = True)).replace('"', '')
            ssl_certificate_key = str(server.query('ssl_certificate_key', first = True)).replace('"', '')
            ssl_ciphers = str(server.query('ssl_ciphers', first = True))
            ssl_prefer_server_ciphers = str(server.query('ssl_prefer_server_ciphers', first = True))
            ssl_protocols = str(server.query('ssl_protocols', first = True))

            ssl_certificate_path_parts =  ssl_certificate.split('/');
            ssl_certificate_filename = ssl_certificate_path_parts[len(ssl_certificate_path_parts) - 1]
            remote_ssl_certificate_filepath = REMOTE_CERTS_DIR + '/' + ssl_certificate_filename

            ssl_certificate_key_path_parts =  ssl_certificate_key.split('/');
            ssl_certificate_key_filename = ssl_certificate_key_path_parts[len(ssl_certificate_key_path_parts) - 1]
            remote_ssl_certificate_key_filepath = REMOTE_KEYS_DIR + '/' + ssl_certificate_key_filename
        
            path_parts = filepath.split('/')
            filename = path_parts[len(path_parts) - 1]
            if re.match(r'.*\.conf$', filename) is None:
                return
            
            username = path_parts[len(path_parts) - 2]
            
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(SSH_HOST_ADDR)
            sftp = ssh.open_sftp()

            proxy_config = PROXY_CONFIG_TMPL.format( server_name, ssl_certificate_filename, ssl_certificate_key_filename, ssl_ciphers, ssl_prefer_server_ciphers, ssl_protocols)
            with sftp.open("{0}/{1}".format(REMOTE_VHOSTS_DIR, filename), 'w') as remote_conf_file:
                remote_conf_file.write(proxy_config)
            
            sftp.put(ssl_certificate, remote_ssl_certificate_filepath)
            sftp.put(ssl_certificate_key, remote_ssl_certificate_key_filepath)
            sftp.chmod(remote_ssl_certificate_key_filepath, 0o600)

            ssh.exec_command( NGINX_RELOAD_COMMAND )
            
            ssh.close()
              
    return

def delproxy( filepath ):
     path_parts = filepath.split('/')
     filename = path_parts[len(path_parts) - 1]

     #ISPManager удаляет файлы по своим странным ритулам поэтому нужно проверять, действительно ли файл конфига удален
     filename = filename.split('.todelete', 1)[0]
     #еще иногда зачем-то подставляет точку вначале имени файла
     if filename[0] == '.':
         filename = filename.replace('.', '', 1)
     
     if os.path.isfile('/'.join(path_parts[:(len(path_parts)-1)]) + '/' + filename):
         return
     
     if re.match(r'.*\.conf$', filename) is None:
         return
            
     domain = os.path.splitext(filename)[0]
     
     ssh = paramiko.SSHClient()
     ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
     ssh.connect(SSH_HOST_ADDR)
     sftp = ssh.open_sftp()

     sftp.remove(REMOTE_VHOSTS_DIR + '/' + filename)
     sftp.remove(REMOTE_CERTS_DIR + '/' + "{0}.crt".format(domain))
     sftp.remove(REMOTE_KEYS_DIR + '/' + "{0}.key".format(domain))

     ssh.exec_command( NGINX_RELOAD_COMMAND )
     
     ssh.close()

     return

if len(sys.argv) < 3:
    sys.exit("Command or inotify event and filename must be specified")
try:        
    command = sys.argv[1]
    filename = sys.argv[2]
    action  = locals().copy().get(command)
except NameError:
    sys.exit( "Invalid command: '{0}'".format(command) )
    
if not action:
    if command == 'IN_CLOSE_WRITE':
        addproxy(filename)
    elif command == 'IN_DELETE':
        delproxy(filename)
    else:
        print ( "Invalid command: '{0}'".format(command) )
        sys.exit(1)
else:
    action( filename );

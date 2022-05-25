#!/bin/bash
## Offline repo tool ... 
REPO_DIR="~/offline/"
NGINX_DIR='/etc/nginx/conf.d'
USERNAME=$(whoami)
HOST_IPS=$(hostname -I)
MY_HOSTNAME=$(hostname | awk -F . '{print $1}')

## notes on a yum downloader for offline - possible docker
mkdir offline
cd offline
mkdir yum
mkdir pip
mkdir files
yum update -y --downloadonly --downloaddir=/root/offline/yum
yum update -y
yum install wget python3-pip jq python-demjson yum-utils vim tmux -y

## bootstrap install packages
yumdownloader --destdir=/root/offline/yum --resolve install vim net-tools bash-completion policycoreutils-python expect cockpit cockpit-ws cockpit-storaged cockpit-packagekit cockpit-pcp cockpit-dashboard unzip wget gcc make python3-devel epel-release firewalld mlocate yum-utils screen rsync yamllint pcp python3-pip jq python-demjson tmux

## erlang and rabbitmq packages
cd ~/offline/yum
wget https://packages.erlang-solutions.com/erlang-solutions-2.0-1.noarch.rpm
wget https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.8.18/rabbitmq-server-3.8.18-1.el7.noarch.rpm
cd ~/offline/files
curl -L https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc --output rabbitmq-release-signing-key.asc

## haproxy pcs packages 
yumdownloader --destdir=/root/offline/yum --resolve haproxy policycoreutils-python pcs

## consul pg patroni 
cd ~/offline/files
wget https://releases.hashicorp.com/consul/1.6.2/consul_1.6.2_linux_amd64.zip
wget https://releases.hashicorp.com/consul/1.12.0/consul_1.12.0_linux_amd64.zip
cd ~/offline/yum
yum install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
yum update -y
yum repolist
yumdownloader --destdir=/root/offline/yum --resolve postgresql13-devel postgresql13-contrib postgresql13-server
yum install createrepo -y
createrepo --update --workers=6 ~/offline/yum/

pip3 install pip2pi

cat > /root/offline/pip/.requirements.txt << EOF 
cdiff==1.0
certifi==2019.9.11
chardet==3.0.4
Click==7.0
idna==2.8
patroni==1.6.0
pip==9.0.3
prettytable==0.7.2
psutil==5.6.5
psycopg2-binary==2.8.4
python-consul==1.1.0
python-dateutil==2.8.1
pytz==2019.3
PyYAML==5.1.2
requests==2.22.0
setuptools==41.6.0
six==1.13.0
tzlocal==2.0.0
urllib3==1.24.2
EOF

pip2tgz ~/offline/pip/ -r ~/offline/pip/.requirements.txt
dir2pi -n ~/offline/pip/
pip2pi  ~/offline/pip/  -n -r ~/offline/pip/.requirements.txt

## use httpd
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --reload

yum install httpd -y

mkdir /var/www/html/CentOS

cp -r ~/offline /var/www/html/CentOS/
systemctl enable httpd
systemctl start httpd
systemctl status httpd

cat > /etc/yum.repos.d << EOF
[localyumrepo]
name=Imagine_Offline_Repo
baseurl=http://127.0.0.1/CentOS/offline/yum/
enabled=1
gpgcheck=0
EOF

alias yumlocal='yum update -y --downloadonly --downloaddir=/var/www/html/CentOS/offline/yum && yum update -y'

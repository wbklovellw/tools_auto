#!/bin/bash
#addComputeNode.sh
#check config.ini
CONFIG_FILE=../conf/config.ini
if [ ! -s $CONFIG_FILE ]
then
  echo "Can not find config.ini!"
  exit 1
fi

function __readINI() 
{
  INIFILE=$1
  SECTION=$2
  ITEM=$3
  ITEM_VALUE=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$ITEM'/{print $2;exit}' $INIFILE`
  echo ${ITEM_VALUE}
}

#sources server
CONTROLLER_IP=( $( __readINI $CONFIG_FILE CONTROLLER_SERVER ip ) )
USER_DBPASS=( $( __readINI $CONFIG_FILE MARIADB user_dbpass ) )
RABBIT_USER=( $( __readINI $CONFIG_FILE RABBITMQ user ) )
RABBIT_PASS=( $( __readINI $CONFIG_FILE RABBITMQ pass ) )

yum install -y mariadb mariadb-server python2-PyMySQL
touch /etc/my.cnf.d/openstack.cnf
cat > /etc/my.cnf.d/openstack.cnf <<EOF
[mysqld]
bind-address = $CONTROLLER_IP
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF

systemctl start mariadb.service
systemctl enable mariadb.service

#mysql_secure_installation
echo -e "\ny\n$USER_DBPASS\n$USER_DBPASS\ny\nn\ny\ny" | mysql_secure_installation
#message queue install
yum install -y rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

#add the openstack user
rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS
#Permit configuration, write, and read access for the openstack user:
rabbitmqctl set_permissions $RABBIT_USER ".*" ".*" ".*"
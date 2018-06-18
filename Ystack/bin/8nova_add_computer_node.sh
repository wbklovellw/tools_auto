#!/bin/bash
#添加计算节点
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
CONTROLLER_NODE=( $( __readINI $CONFIG_FILE DOMAIN_NAME controller_domain ) )
DBUSER=( $( __readINI $CONFIG_FILE MARIADB user ) )
USER_DBPASS=( $( __readINI $CONFIG_FILE MARIADB user_dbpass ) )
NOVA_USER=( $( __readINI $CONFIG_FILE NOVA nova_user ) )
NOVA_PASS=( $( __readINI $CONFIG_FILE NOVA nova_pass ) )
NOVA_API_DBUSER=( $( __readINI $CONFIG_FILE NOVA nova_api_dbuser ) )
NOVA_API_DBPASS=( $( __readINI $CONFIG_FILE NOVA nova_api_dbpass ) )
NOVA_IP=( $( __readINI $CONFIG_FILE NOVA ip ) )
KEY_ADMIN_PASS=( $( __readINI $CONFIG_FILE KEYSTONE admin_user_token ) )
PLACEMENT_USER=( $( __readINI $CONFIG_FILE NOVA placement_user ) )
PLACEMENT_PASS=( $( __readINI $CONFIG_FILE NOVA placement_pass ) )
RABBIT_USER=( $( __readINI $CONFIG_FILE RABBITMQ user ) )
RABBIT_PASS=( $( __readINI $CONFIG_FILE RABBITMQ pass ) )

echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_ADMIN_PASS\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ../var/admin-openrc
source ../var/admin-openrc
openstack hypervisor list
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
sed -i "/^\[scheduler\]/discover_hosts_in_cells_interval = 300" /etc/nova/nova.conf

openstack compute service list
openstack catalog list
openstack image list
nova-status upgrade check
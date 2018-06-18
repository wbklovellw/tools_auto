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
CONTROLLER_NODE=( $( __readINI $CONFIG_FILE DOMAIN_NAME controller_domain ) )
DBUSER=( $( __readINI $CONFIG_FILE MARIADB user ) )
USER_DBPASS=( $( __readINI $CONFIG_FILE MARIADB user_dbpass ) )
CIN_USER=( $( __readINI $CONFIG_FILE CINDER cin_user ) )
CIN_PASS=( $( __readINI $CONFIG_FILE CINDER cin_pass ) )
CIN_DBUSER=( $( __readINI $CONFIG_FILE CINDER cin_dbuser ) )
CIN_DBPASS=( $( __readINI $CONFIG_FILE CINDER cin_dbpass ) )
KEY_ADMIN_PASS=( $( __readINI $CONFIG_FILE KEYSTONE admin_user_token ) )
PLACEMENT_USER=( $( __readINI $CONFIG_FILE NOVA placement_user ) )
PLACEMENT_PASS=( $( __readINI $CONFIG_FILE NOVA placement_pass ) )
RABBIT_USER=( $( __readINI $CONFIG_FILE RABBITMQ user ) )
RABBIT_PASS=( $( __readINI $CONFIG_FILE RABBITMQ pass ) )
CIN_IP=( $( __readINI $CONFIG_FILE CINDER ip ) )

source ../var/admin-openrc
openstack volume service list
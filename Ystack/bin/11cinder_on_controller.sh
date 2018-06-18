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

mysql -u$DBUSER -p$USER_DBPASS -e "source sql/cinder.sql"

echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_ADMIN_PASS\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ../var/admin-openrc
source ../var/admin-openrc

openstack user create --domain default --password $CIN_PASS $CIN_USER
openstack role add --project service --user $CIN_PASS admin
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
openstack endpoint create --region RegionOne volumev2 public http://$CONTROLLER_NODE:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://$CONTROLLER_NODE:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://$CONTROLLER_NODE:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://$CONTROLLER_NODE:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://$CONTROLLER_NODE:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://$CONTROLLER_NODE:8776/v3/%\(project_id\)s
yum install -y openstack-cinder

sed -i "/^\[database\]/a\connection = mysql+pymysql://$CIN_DBUSER:$CIN_DBPASS@$CONTROLLER_NODE/cinder" /etc/cinder/cinder.conf
sed -i "/^#osapi_max_limit = 1000/a\transport_url = rabbit:\/\/$RABBIT_USER:$RABBIT_PASS@$CONTROLLER_NODE\nauth_strategy = keystone\nmy_ip=$CIN_IP" \
/etc/cinder/cinder.conf
sed -i "/^#auth_uri = <None>/a\auth_uri = http://$CONTROLLER_NODE:5000\nauth_url = http://$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $CIN_USER\npassword = $CIN_PASS" \
/etc/cinder/cinder.conf
sed -i "/^\[oslo_concurrency\]/a\lock_path = /var/lib/cinder/tmp" /etc/cinder/cinder.conf
su -s /bin/sh -c "cinder-manage db sync" cinder

systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service


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
KEY_ADMIN_PASS=( $( __readINI $CONFIG_FILE KEYSTONE admin_user_token ) )
GLAN_USER=( $( __readINI $CONFIG_FILE GLANCE glan_user ) )
GLAN_PASS=( $( __readINI $CONFIG_FILE GLANCE glan_pass ) )
GLAN_DBUSER=( $( __readINI $CONFIG_FILE GLANCE glan_dbuser ) )
GLAN_DBPASS=( $( __readINI $CONFIG_FILE GLANCE glan_dbpass ) )

mysql -u$DBUSER -p$USER_DBPASS -e "source sql/glance.sql"
echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_ADMIN_PASS\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ../var/admin-openrc
source ../var/admin-openrc

openstack user create --domain default --password $GLAN_PASS $GLAN_USER
openstack role add --project service --user $GLAN_USER admin
openstack service create --name $GLAN_USER --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://$CONTROLLER_NODE:9292
openstack endpoint create --region RegionOne image internal http://$CONTROLLER_NODE:9292
openstack endpoint create --region RegionOne image admin http://$CONTROLLER_NODE:9292
yum install -y openstack-glance

sed -i "/^# From oslo.db/a\connection = mysql+pymysql://$GLAN_DBUSER:$GLAN_DBPASS@$CONTROLLER_NODE/glance" \
/etc/glance/glance-api.conf

sed -i "/^# From keystonemiddleware.auth_token/a\auth_uri = http://$CONTROLLER_NODE:5000\nauth_url = http://$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $GLAN_USER\npassword = $GLAN_PASS" \
/etc/glance/glance-api.conf

sed -i "s/^#flavor = keystone/flavor = keystone/" /etc/glance/glance-api.conf
sed -i "/^\[glance_store\]/a\stores = file,http\ndefault_store = file\nfilesystem_store_datadir = \/var\/lib\/glance\/images\/" \
/etc/glance/glance-api.conf

sed -i "/^# From oslo.db/a\connection = mysql+pymysql://$GLAN_DBUSER:$GLAN_DBPASS@$CONTROLLER_NODE/glance" \
/etc/glance/glance-registry.conf
sed -i "/^# From keystonemiddleware.auth_token/a\auth_uri = http:\/\/$CONTROLLER_NODE:5000\nauth_url = http:\/\/$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $GLAN_USER\npassword = $GLAN_PASS" \
/etc/glance/glance-registry.conf
sed -i "s/^#flavor = keystone/flavor = keystone/" /etc/glance/glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service

source ../var/admin-openrc
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list
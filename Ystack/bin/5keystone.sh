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
KEY_DBUSER=( $( __readINI $CONFIG_FILE KEYSTONE key_dbuser ) )
KEY_DBPASS=( $( __readINI $CONFIG_FILE KEYSTONE key_dbpass ) )
KEY_USER=( $( __readINI $CONFIG_FILE KEYSTONE key_user ) )
KEY_GROUP=( $( __readINI $CONFIG_FILE KEYSTONE key_group ) )
KEY_BOOT_PASS=( $( __readINI $CONFIG_FILE KEYSTONE boot_pass ) )
KEY_ADMIN_PASS=( $( __readINI $CONFIG_FILE KEYSTONE admin_user_token ) )
KEY_DEMO_PASS=( $( __readINI $CONFIG_FILE KEYSTONE demo_user_token ) )
KEY_DEMO_USER=( $( __readINI $CONFIG_FILE KEYSTONE demo_user ) )

mysql -u$DBUSER -p$USER_DBPASS -e "source sql/keystone.sql"

yum install -y openstack-keystone httpd mod_wsgi

sed -i "/^# From oslo.db/a\connection = mysql+pymysql://$KEY_DBUSER:$KEY_DBPASS@$CONTROLLER_NODE/keystone" \
/etc/keystone/keystone.conf
sed -i "/^#enforce_token_bind = permissive/a\provider = fernet" /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone

keystone-manage fernet_setup --keystone-user $KEY_USER --keystone-group $KEY_GROUP
keystone-manage credential_setup --keystone-user $KEY_USER --keystone-group $KEY_GROUP
keystone-manage bootstrap --bootstrap-password $KEY_BOOT_PASS --bootstrap-admin-url http://$CONTROLLER_NODE:35357/v3/ \
--bootstrap-internal-url http://$CONTROLLER_NODE:5000/v3/ --bootstrap-public-url http://$CONTROLLER_NODE:5000/v3/ \
--bootstrap-region-id RegionOne

sed -i "s/#ServerName www.example.com:80/ServerName $CONTROLLER_NODE/" /etc/httpd/conf/httpd.conf
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl start httpd.service

echo -e "export OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_DEMO_PASS\nexport OS_PROJECT_NAME=admin\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_DOMAIN_NAME=Default\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3" >> /etc/profile

source /etc/profile

openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" $KEY_DEMO_USER
openstack user create --domain default --password $KEY_DEMO_PASS $KEY_DEMO_USER
openstack role create user
openstack role add --project $KEY_DEMO_USER --user $KEY_DEMO_USER user

sed -i "s/ admin_token_auth//" /etc/keystone/keystone-paste.ini

unset OS_AUTH_URL OS_PASSWORD

openstack --os-auth-url http://$CONTROLLER_NODE:35357/v3 --os-project-domain-name default --os-user-domain-name default \
--os-project-name admin --os-username admin token issue --os-password $KEY_ADMIN_PASS
openstack --os-auth-url http://$CONTROLLER_NODE:5000/v3 --os-project-domain-name default --os-user-domain-name default \
--os-project-name $KEY_DEMO_USER --os-username $KEY_DEMO_USER token issue --os-password $KEY_DEMO_PASS

echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_ADMIN_PASS\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ../var/admin-openrc
source ../var/admin-openrc

openstack token issue

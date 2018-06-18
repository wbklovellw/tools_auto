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

yum install -y openstack-dashboard
sed -i "s/^OPENSTACK_HOST = \"127.0.0.1\"/OPENSTACK_HOST = \"$CONTROLLER_NODE\"/" /etc/openstack-dashboard/local_settings
sed -i "s/^ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]/ALLOWED_HOSTS = \['*'\]/" /etc/openstack-dashboard/local_settings


sed -i "/^CACHES = {/i\SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" /etc/openstack-dashboard/local_settings
sed -i "s/'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',/'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',/" /etc/openstack-dashboard/local_settings
sed -i "/^        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',/a\        'LOCATION': '$CONTROLLER_NODE:11211'," /etc/openstack-dashboard/local_settings
sed -i "s/OPENSTACK_KEYSTONE_URL = \"http:\/\/%s:5000\/v2.0\" % OPENSTACK_HOST/OPENSTACK_KEYSTONE_URL = \"http:\/\/%s:5000\/v3\" % OPENSTACK_HOST/" /etc/openstack-dashboard/local_settings
sed -i "/^#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = False/a\OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" /etc/openstack-dashboard/local_settings
sed -i "s/#OPENSTACK_API_VERSIONS = {/OPENSTACK_API_VERSIONS = {/" /etc/openstack-dashboard/local_settings
sed -i "s/#    \"identity\": 3,/    \"identity\": 3,/" /etc/openstack-dashboard/local_settings
sed -i "s/#    \"image\": 2,/    \"image\": 2,/" /etc/openstack-dashboard/local_settings
sed -i "s/#    \"volume\": 2,/    \"volume\": 2,/" /etc/openstack-dashboard/local_settings
sed -i "/^#    \"compute\": 2,/a\}" /etc/openstack-dashboard/local_settings
sed -i "s/#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'/" /etc/openstack-dashboard/local_settings
sed -i "s/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"_member_\"/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"/" /etc/openstack-dashboard/local_settings

systemctl restart httpd.service memcached.service
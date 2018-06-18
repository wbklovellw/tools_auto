#!/bin/bash
#创建控制中心
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

mysql -u$DBUSER -p$USER_DBPASS -e "source sql/nova.sql"

echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_ADMIN_PASS\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ../var/admin-openrc
source ../var/admin-openrc

openstack user create --domain default --password $NOVA_PASS $NOVA_USER
openstack role add --project service --user $NOVA_USER admin
openstack service create --name $NOVA_USER --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://$CONTROLLER_NODE:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://$CONTROLLER_NODE:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://$CONTROLLER_NODE:8774/v2.1
openstack user create --domain default --password $PLACEMENT_PASS $PLACEMENT_USER
openstack role add --project service --user $PLACEMENT_USER admin
openstack service create --name $PLACEMENT_USER --description "Placement API" placement
openstack endpoint create --region RegionOne $PLACEMENT_USER public http://$CONTROLLER_NODE:8778
openstack endpoint create --region RegionOne $PLACEMENT_USER internal http://$CONTROLLER_NODE:8778
openstack endpoint create --region RegionOne $PLACEMENT_USER admin http://$CONTROLLER_NODE:8778
yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api

sed -i "/^# \* quota_networks/a\enabled_apis = osapi_compute,metadata\ntransport_url = rabbit:\/\/$RABBIT_USER:$RABBIT_PASS@$CONTROLLER_NODE\nmy_ip = $NOVA_IP\nuse_neutron = True\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver" \
/etc/nova/nova.conf
sed -i "/^\[api_database\]/a\connection = mysql+pymysql://$NOVA_USER:$NOVA_API_DBPASS@$CONTROLLER_NODE/nova_api" /etc/nova/nova.conf
sed -i "/^\[database\]/a\connection = mysql+pymysql://$NOVA_USER:$NOVA_PASS@$CONTROLLER_NODE/nova" /etc/nova/nova.conf
sed -i "/^\[api\]/a\auth_strategy = keystone" /etc/nova/nova.conf
sed -i "/^#auth_uri=<None>/a\auth_uri = http://$CONTROLLER_NODE:5000\nauth_url = http://$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $NOVA_USER\npassword = $NOVA_PASS" \
/etc/nova/nova.conf
sed -i "/^# Enable VNC related features./a\enabled = true\nvncserver_listen = $NOVA_IP\nvncserver_proxyclient_address = $NOVA_IP" \
/etc/nova/nova.conf
sed -i "/^\[glance\]/a\api_servers = http://$CONTROLLER_NODE:9292" \
/etc/nova/nova.conf
sed -i "/^\[oslo_concurrency\]/a\lock_path = /var/lib/nova/tmp" \
/etc/nova/nova.conf
sed -i "/^\[placement\]/a\os_region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://$CONTROLLER_NODE:35357/v3\nusername = $PLACEMENT_USER\npassword = $PLACEMENT_PASS" /etc/nova/nova.conf
echo -e "<Directory /usr/bin>\n<IfVersion >= 2.4>\nRequire all granted\n</IfVersion>\n<IfVersion < 2.4>\nOrder allow,deny\nAllow from all\n</IfVersion>\n</Directory>" > \
/etc/httpd/conf.d/00-nova-placement-api.conf
systemctl restart httpd
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
nova-manage cell_v2 list_cells
systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service

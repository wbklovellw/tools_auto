#!/bin/bash
#二层网络安装2
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
NEU_DBUSER=( $( __readINI $CONFIG_FILE NEUTRON neu_dbuser ) )
NEU_DBPASS=( $( __readINI $CONFIG_FILE NEUTRON neu_dbpass ) )
NEU_USER=( $( __readINI $CONFIG_FILE NEUTRON neu_user ) )
NEU_PASS=( $( __readINI $CONFIG_FILE NEUTRON neu_pass ) )
NOVA_USER=( $( __readINI $CONFIG_FILE NOVA nova_user ) )
NOVA_PASS=( $( __readINI $CONFIG_FILE NOVA nova_pass ) )
PROVIDER_INTERFACE_NAME=( $( __readINI $CONFIG_FILE NEUTRON interface ) )
KEY_ADMIN_PASS=( $( __readINI $CONFIG_FILE KEYSTONE admin_user_token ) )
OVERLAY_INTERFACE_IP_ADDRESS=( $( __readINI $CONFIG_FILE NEUTRON ip_address ) )
RABBIT_USER=( $( __readINI $CONFIG_FILE RABBITMQ user ) )
RABBIT_PASS=( $( __readINI $CONFIG_FILE RABBITMQ pass ) )

mysql -u$DBUSER -p$USER_DBPASS -e "source sql/neutron.sql"

echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=$KEY_ADMIN_PASS\nexport OS_AUTH_URL=http://$CONTROLLER_NODE:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ../var/admin-openrc
source ../var/admin-openrc

openstack user create --domain default --password $NEU_PASS $NEU_USER
openstack role add --project service --user $NEU_USER admin
openstack service create --name $NEU_USER --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://$CONTROLLER_NODE:9696
openstack endpoint create --region RegionOne network internal http://$CONTROLLER_NODE:9696
openstack endpoint create --region RegionOne network admin http://$CONTROLLER_NODE:9696

yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables
sed -i "/^# From oslo.db/a\connection = mysql+pymysql://$NEU_DBUSER:$NEU_DBPASS@$CONTROLLER_NODE/neutron" \
/etc/neutron/neutron.conf
sed -i "/#state_path = \/var\/lib\/neutron/a\core_plugin = ml2\nservice_plugins = router\nallow_overlapping_ips = true\ntransport_url = rabbit:\/\/$RABBIT_USER:$RABBIT_PASS@$CONTROLLER_NODE\nauth_strategy = keystone\nnotify_nova_on_port_status_changes = true\nnotify_nova_on_port_data_changes = true" \
/etc/neutron/neutron.conf
sed -i "/^# From keystonemiddleware.auth_token/a\auth_uri = http:\/\/$CONTROLLER_NODE:5000\nauth_url = http:\/\/$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $NEU_USER\npassword = $NEU_PASS" \
/etc/neutron/neutron.conf
sed -i "/^# From nova.auth/a\auth_url = http:\/\/$CONTROLLER_NODE:35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = $NOVA_USER\npassword = $NOVA_PASS" \
/etc/neutron/neutron.conf
sed -i "/^\[oslo_concurrency\]/a\lock_path = \/var\/lib\/neutron\/tmp" \
/etc/neutron/neutron.conf
sed -i "/^#type_drivers = local,flat,vlan,gre,vxlan,geneve/a\type_drivers = flat,vlan,vxlan\ntenant_network_types = vxlan\nmechanism_drivers = linuxbridge,l2population\nextension_drivers = port_security" \
/etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[ml2_type_flat\]/a\flat_networks = provider" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[ml2_type_vxlan\]/a\vni_ranges = 1:1000" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[securitygroup\]/a\enable_ipset = true" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[linux_bridge\]/a\physical_interface_mappings = provider:$PROVIDER_INTERFACE_NAME" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/^\[vxlan\]/a\enable_vxlan = false\nlocal_ip = $OVERLAY_INTERFACE_IP_ADDRESS\nl2_population = true" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/\[securitygroup\]/a\enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

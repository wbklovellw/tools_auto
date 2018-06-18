#!/bin/bash
#计算节点添加网络配置
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
NOVA_USER=( $( __readINI $CONFIG_FILE NEUTRON nova_user ) )
NOVA_PASS=( $( __readINI $CONFIG_FILE NEUTRON nova_pass ) )
PROVIDER_INTERFACE_NAME=( $( __readINI $CONFIG_FILE NEUTRON interface ) )
KEY_ADMIN_PASS=( $( __readINI $CONFIG_FILE KEYSTONE admin_user_token ) )
RABBIT_USER=( $( __readINI $CONFIG_FILE RABBITMQ user ) )
RABBIT_PASS=( $( __readINI $CONFIG_FILE RABBITMQ pass ) )
METADATA_SECRET=( $( __readINI $CONFIG_FILE NEUTRON metadata_secret ) )

yum install -y openstack-neutron-linuxbridge ebtables ipset
sed -i "/#state_path = \/var\/lib\/neutron/a\transport_url = rabbit:\/\/$RABBIT_USER:$RABBIT_PASS@$CONTROLLER_NODE\nauth_strategy = keystone" \
/etc/neutron/neutron.conf
sed -i "/^# From keystonemiddleware.auth_token/a\auth_uri = http:\/\/$CONTROLLER_NODE:5000\nauth_url = http:\/\/$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $NEU_USER\npassword = $NEU_PASS" \
/etc/neutron/neutron.conf
sed -i "/^\[oslo_concurrency\]/a\lock_path = \/var\/lib\/neutron\/tmp" \
/etc/neutron/neutron.conf
sed -i "/^\[linux_bridge\]/a\physical_interface_mappings = provider:$PROVIDER_INTERFACE_NAME" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/^\[vxlan\]/a\enable_vxlan = false\nlocal_ip = $OVERLAY_INTERFACE_IP_ADDRESS\nl2_population = true" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/\[securitygroup\]/a\enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/# Configuration options for neutron/a\url = http://$CONTROLLER_NODE:9696\nauth_url = http://$CONTROLLER_NODE:35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = $NEU_USER\npassword = $NEU_PASS\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = $METADATA_SECRET" \
/etc/nova/nova.conf
systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service

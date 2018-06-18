#!/bin/bash
#三层网络安装
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
RABBIT_USER=( $( __readINI $CONFIG_FILE RABBITMQ user ) )
RABBIT_PASS=( $( __readINI $CONFIG_FILE RABBITMQ pass ) )
METADATA_SECRET=( $( __readINI $CONFIG_FILE NEUTRON metadata_secret ) )

sed -i "s/# verbose = true/verbose = true/" /etc/neutron/l3_agent.ini
sed -i "/^#ovs_use_veth = false/a\interface_driver = linuxbridge" /etc/neutron/l3_agent.ini
sed -i "/^#ovs_integration_bridge = br-int/a\interface_driver = linuxbridge\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\nenable_isolated_metadata = true" /etc/neutron/dhcp_agent.ini


sed -i "s/#nova_metadata_ip = 127.0.0.1/nova_metadata_ip = $CONTROLLER_NODE/" /etc/neutron/metadata_agent.ini
sed -i "s/#metadata_proxy_shared_secret =/metadata_proxy_shared_secret = $METADATA_SECRET/" /etc/neutron/metadata_agent.ini


sed -i "/# Configuration options for neutron/a\url = http://$CONTROLLER_NODE:9696\nauth_url = http://$CONTROLLER_NODE:35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = $NEU_USER\npassword = $NEU_PASS\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = $METADATA_SECRET" \
/etc/nova/nova.conf

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

systemctl restart openstack-nova-api.service

systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service

systemctl enable neutron-l3-agent.service
systemctl start neutron-l3-agent.service
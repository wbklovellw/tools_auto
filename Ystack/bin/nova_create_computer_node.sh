#!/bin/bash
#创建计算节点
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

yum install -y openstack-nova-compute

sed -i "/^# \* quota_networks/a\enabled_apis = osapi_compute,metadata\ntransport_url = rabbit:\/\/$RABBIT_USER:$RABBIT_PASS@$CONTROLLER_NODE\nmy_ip = $NOVA_IP\nuse_neutron = True\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver" \
/etc/nova/nova.conf
sed -i "/^\[api\]/a\auth_strategy = keystone" /etc/nova/nova.conf
sed -i "/^#auth_uri=<None>/a\auth_uri = http://$CONTROLLER_NODE:5000\nauth_url = http://$CONTROLLER_NODE:35357\nmemcached_servers = $CONTROLLER_NODE:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = $NOVA_USER\npassword = $NOVA_PASS" \
/etc/nova/nova.conf
sed -i "/^# Enable VNC related features./a\enabled = true\nvncserver_listen = 0.0.0.0\nvncserver_proxyclient_address = $NOVA_IP\nnovncproxy_base_url = http://$CONTROLLER_NODE:6080/vnc_auto.html" \
/etc/nova/nova.conf
sed -i "/^\[glance\]/a\api_servers = http://$CONTROLLER_NODE:9292" \
/etc/nova/nova.conf
sed -i "/^\[oslo_concurrency\]/a\lock_path = /var/lib/nova/tmp" \
/etc/nova/nova.conf
sed -i "/^\[placement\]/a\os_region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://$CONTROLLER_NODE:35357/v3\nusername = $PLACEMENT_USER\npassword = $PLACEMENT_PASS" \
/etc/nova/nova.conf
sed -i "/^# libvirt hypervisor driver to be used within an OpenStack deployment./a\virt_type = kvm" \
/etc/nova/nova.conf
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
#!/bin/bash
#更换yum源
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

declare -a COMPUTER_IP
declare -a BLOCK_IP

#sources server
CONTROLLER_IP=( $( __readINI $CONFIG_FILE CONTROLLER_SERVER ip ) )
COMPUTER_IP=( $( __readINI $CONFIG_FILE SERVER nova_ip ) )
BLOCK_IP=( $( __readINI $CONFIG_FILE SERVER cinder_ip ) )
CONTROLLER_NODE=( $( __readINI $CONFIG_FILE DOMAIN_NAME controller_domain ) )
COMPUTER_NAME=( $( __readINI $CONFIG_FILE DOMAIN_NAME computer_domain ) )
BLOCK_NAME=( $( __readINI $CONFIG_FILE DOMAIN_NAME block_domain ) )

echo "$CONTROLLER_IP $CONTROLLER_NODE" >> /etc/hosts

for (( i=0;i<${#COMPUTER_NAME[@]};i++ )) ;do
echo "${COMPUTER_IP[$i]} ${COMPUTER_NAME[$i]}" >> /etc/hosts
done

for (( i=0;i<${#BLOCK_NAME[@]};i++ )) ;do
echo "${BLOCK_IP[$i]} ${BLOCK_NAME[$i]}" >> /etc/hosts
done

yum install -y wget
rm -rf /etc/yum.repos.d/*.repo
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

cat > /etc/yum.repos.d/ceph.repo << EOF
[ceph]
name=Ceph packages for \$basearch
baseurl=http://download.ceph.com/rpm-jewel/el7/\$basearch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[ceph-noarch]
name=Ceph noarch packages
baseurl=http://download.ceph.com/rpm-jewel/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://download.ceph.com/rpm-jewel/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1
EOF

yum makecache
yum install -y yum-plugin-priorities
yum install -y centos-release-openstack-ocata
yum upgrade -y
yum install -y python-openstackclient
yum install -y openstack-selinux
systemctl stop firewalld
systemctl disable firewalld

setenforce 0


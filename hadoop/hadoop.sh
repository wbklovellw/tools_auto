#!/bin/bash
DATA_DIR="/home/data"
HADOOP_HOME="/home/data/hadoop"
LOCK_FILE="/tmp/hadoop.lock"
JAVA_HOME="/usr/local/jdk"
MYSQL_HOME="/usr/local/mysql"
PACK_DIR="/usr/local/src"
JDK_INSTALL_FILE="$PACK_DIR/jdk-8u144-linux-x64.tar.gz"
HIVE_INSTALL_FILE="$PACK_DIR/apache-hive-2.3.0-bin.tar.gz"
HADOOP_INSTALL_FILE="$PACK_DIR/hadoop-2.8.1.tar.gz"
HBASE_INSTALL_FILE="$PACK_DIR/hbase-1.3.1-bin.tar.gz"
SPARK_INSTALL_FILE="$PACK_DIR/spark-2.1.1-bin-hadoop2.7.tgz"
SQOOP_INSTALL_FILE="$PACK_DIR/sqoop-1.99.7-bin-hadoop200.tar.gz"
ZK_INSTALL_FILE="$PACK_DIR/zookeeper-3.4.9.tar.gz"
DB_INSTALL_FILE="$PACK_DIR/mariadb-10.3.9-linux-systemd-x86_64.tar.gz"
ANSIBLE_FILE="$PACK_DIR/stable-2.7.zip"
DB_VERSION="mariadb-10.3.9-linux-x86_64"
#MYSQL_IP="192.168.1.123"

ansible_install(){
	cd $PACK_DIR
	unzip $ANSIBLE_FILE
	python get-pip.py
	cd $PACK_DIR/ansible-stable-2.7
	pip install -r requirements.txt
	#pip install ansible
	python setup.py install
	mkdir /etc/ansible
	cp ./examples/ansible.cfg /etc/ansible
	yum install sshpass
}

env_ansible(){
if [ -f /etc/ansible/ansible.cfg ]; then
	echo "ansible is installed" && exit;
else
	echo "ansible is installing...."
	ansible_install;
	echo "ansible is success"
fi
}

jdk_install(){
	mkdir -p $JAVA_HOME
	tar -xzvf $JDK_INSTALL_FILE -C $JAVA_HOME
	cd $JAVA_HOME && mv $(ls -l . |awk '/^d/ {print $NF}')/* ./ && rm -rf $(ls -l . |awk '/^d/ {print $NF}' |awk '/^jdk/ {print $NF}')
	cat >> /etc/profile <<EOF
export JAVA_HOME=$JAVA_HOME
export CLASSPATH=.:\$JAVA_HOME/jre/lib/rt.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
	source /etc/profile
	java -version
}

env_jdk(){
if [ -d $JAVA_HOME ];then
	echo "JDK is installed" && exit;
else
	echo "JDK is installing...."
	jdk_install;
	echo "JDK is success"
fi
}

hadoop_install(){
	mkdir -p $HADOOP_HOME
	tar -xzvf $HADOOP_INSTALL_FILE -C $HADOOP_HOME
	cd $HADOOP_HOME && mv $(ls -l . |awk '/^d/ {print $NF}')/* ./ && rm -rf $(ls -l . |awk '/^d/ {print $NF}' |awk '/^hadoop/ {print $NF}')
	#source ./hadoop.sh
	#. ./hadoop.sh
	groupadd hadoop && useradd -m -g hadoop hadoop
	echo -e "hadoop\nhadoop" | passwd hadoop
	su - hadoop -s /bin/bash /root/hadoop.sh
	cat >> /home/hadoop/.bashrc <<EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=$HADOOP_HOME
export HADOOP_USER_NAME=hadoop
export PATH=\$JAVA_HOME/bin:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH
EOF
}

spark_install(){

}

hbase_install(){

}

hive_install(){

}

mysql_install(){
	mkdir $MYSQL_HOME
	cd $MYSQL_HOME
	tar -xzvf $DB_INSTALL_FILE -C $MYSQL_HOME
	groupadd mysql
	ln -s $DB_VERSION mysql
	cd mysql
	./scripts/mysql_install_db --user=mysql
	chown -R root .
	chown -R mysql data
}

zk_install(){

}

sqoop_install(){

}

main(){
	METHOD=$1
	case $METHOD in
		all)
			env_jdk;
			hadoop_install;
			spark_install;
			hbase_install;
			hive_install;
			zk_install;
			sqoop_install;
			;;
		hadoop)
			env_jdk;
			hadoop_install;
			;;
		spark)
			env_jdk;
			spark_install;
			;;
		hbase)
			env_jdk;
			hbase_install;
			;;
		hive)
			env_jdk;
			hive_install;
			;;
		zk)
			env_jdk;
			zk_install;
			;;
		sqoop)
			env_jdk;
			sqoop_install;
			;;
}

main;
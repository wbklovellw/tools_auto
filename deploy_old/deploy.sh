#!/bin/bash
#Shell Env
LOG_DATE='date "+%Y-%m-%d"'
LOG_TIME='date "+%H-%M-%s"'

CDATE=$(date "+%Y-%m-%d")
CTIME=$(date "+%H-%M-%s")

SHELL_NAME="deploy.sh"
SHELL_DIR="/home/www/"
SHELL_LOG="${SHELL_DIR}/${SHELL_NAME}.log"

#Code Env
CODE_DIR="/deploy/code/deploy"
CONFIG_DIR="/deploy/config"
TMP_DIR="/deploy/tmp"
TAR_DIR="/deploy/tar"
LOCK_FILE="/tmp/deploy.lock"

usage(){
	echo $"Usage: $0 [ deploy | rollback ]"
}

write_log(){
	LOGINFO=$1
	echo "${CDATE} ${CTIME}: ${SHELL_NAME}: ${LOGINFO}" >> ${SHELL_LOG}
}

shell_lock(){
	touch ${LOCK_FILE}
}

shell_unlock(){
	rm -f ${LOCK_FILE}
}

code_get(){
	write_log "code_get";
	cd $CODE_DIR && git pull
	
}

code_build(){
echo code_build
}

code_config(){
echo code_config
}

code_tar(){
echo code_tar
}

code_scp(){
echo code_scp
}

cluster_node_remove(){
echo cluster_node_remove
}

code_deploy(){
echo code_deploy
}

config_diff(){
echo config_diff
}

code_test(){
echo code_test
}

cluster_node_in(){
echo cluster_node_in
}

rollback(){
echo rollback
}

main(){
	if [ -f $LOCK_FILE ];then
		echo "Deploy is running" && exit;
	fi
	DEPLOY_METHOD=$1
	case $DEPLOY_METHOD in
		deploy)
			shell_lock;
			code_get;
			code_build;
			code_config;
			code_tar;
			code_scp;
			cluster_node_remove;
			code_deploy;
			config_diff;
			code_test;
			cluster_node_in;
			shell_unlock;
			;;
		rollback)
			shell_lock;
			rollback;
			shell_unlock;
			;;
		*)
			usage;
	esac
}

main $1
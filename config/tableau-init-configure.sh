#!/bin/bash

# Exit on first error:w
set -e

LOGFILE=/var/log/tableau_docker.log
RETAIN_NUM_LINES=10000

function logsetup {  
    TMP=$(tail -n $RETAIN_NUM_LINES $LOGFILE 2>/dev/null) && echo "${TMP}" > $LOGFILE
    exec > >(tee -a $LOGFILE)
    exec 2>&1
}

function log {  
    echo "[$(date --rfc-3339=seconds)]: $*"
}

logsetup

# We have to install at runtime of the container because systemd is not running during the build process
# causing installation to fail
if [[ ! -f /opt/tableau/docker_build/.init-done ]]; then
    log install tsm
    chmod -R 777 /run/user
    chmod -R 777 /dev/shm
    cp /opt/tableau/docker_build/registration_file.json.templ /opt/tableau/docker_build/registration_file.json
    set +e
    DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release | sed 's/\"//g')
    if [[ $DISTRO == "CentOS Linux" ]]; then
      yum install -y /tableau-server-${TABLEAU_VERSION}.x86_64.rpm tableau-postgresql-odbc-9.5.3-1.x86_64.rpm
    elif [[ $DISTRO == "Ubuntu" ]]; then
      gdebi -n /tableau-server.deb
    fi
    set -e
    log install done
fi

log start initalize tsm
su tsm -c "sudo bash -x /opt/tableau/tableau_server/packages/scripts.*/initialize-tsm -f --accepteula" 2>&1 1> /var/log/tableau_docker.log
log initalize done

source /etc/profile.d/tableau_server.sh

log login tsm
su tsm -c "sudo /opt/tableau/tableau_server/packages/customer-bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tsm login --username tsm --password tsm" 2>&1 1>> /var/log/tableau_docker.log
log login tsm done

log licenses activate
su tsm -c "sudo /opt/tableau/tableau_server/packages/customer-bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tsm licenses activate -t" 2>&1 1>> /var/log/tableau_docker.log
log licenses activate done 

log register 
su tsm -c "sudo /opt/tableau/tableau_server/packages/customer-bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tsm register --file /opt/tableau/docker_build/registration_file.json" 2>&1 1>> /var/log/tableau_docker.log
log register done

if [[ ! -f /var/opt/tableau/.import-done ]]; then
    log settings import
    su tsm -c "sudo /opt/tableau/tableau_server/packages/customer-bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tsm settings import -f /opt/tableau/docker_build/tableau_config.json" 2>&1 1>> /var/log/tableau_docker.log
    log settings import done

    log pending-changes apply
    su tsm -c "sudo /opt/tableau/tableau_server/packages/customer-bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tsm pending-changes apply --restart" 2>&1 1>> /var/log/tableau_docker.log
    log penging-changes apply done

    touch /var/opt/tableau/.import-done
fi

log initalize server
su tsm -c "sudo /opt/tableau/tableau_server/packages/customer-bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tsm initialize --start-server --request-timeout 1800 --username tsm --password tsm" 2>&1 1>> /var/log/tableau_docker.log
log initalize server done

log initialuser 
su tsm -c "sudo /opt/tableau/tableau_server/packages/bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/tabcmd initialuser --server localhost:80 --username admin --password admin" 2>&1 1>> /var/log/tableau_docker.log
log all done


touch /opt/tableau/docker_build/.init-done
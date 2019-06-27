#!/bin/bash

# ------------------------------------------------------------------
#          This script extracts media from /media/compressed
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
EXTRACT_DIR=/media/extracted/
COMPRESS_DIR=/media/compressed/
TEMP_DIR_FOR_DOWNLOADED_BACKUP=/media/backup/
source /root/install/config.sh


usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
EOF
    exit 1
}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

command_exists () {
    type "$1" &> /dev/null ;
}

EXTRACT(){

  EXE=$(/usr/bin/find ${COMPRESS_DIR}  -name '*.exe');

  if command_exists unrar ; then
  	/usr/bin/unrar x ${EXE} ${EXTRACT_DIR}
  else

  # ------------------------------------------------------------------
  #   At the time of writing, marketplace RHEL and marketplace SLES
  #	did not have unrar package. As a workaround, we download as below
  #   TODO: This is a temporary workaround and needs to be fixed in AMI
  # ------------------------------------------------------------------
  	log "WARNING: Downloading from repoforge. Prefer prebaked AMIs"


  	mkdir -p /root/install/misc
  	wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz -O /root/install/misc/unrar-5.0-RHEL5x64.tar.gz
  	(cd /root/install/misc && tar xvf /root/install/misc/unrar-5.0-RHEL5x64.tar.gz && chmod 755 /root/install/misc/unrar)
  	/root/install/misc/unrar x ${EXE} ${EXTRACT_DIR}

  	#wget http://pkgs.repoforge.org/unrar/unrar-5.0.3-1.el6.rf.x86_64.rpm -O /root/install/misc/unrar-5.0.3-1.el6.rf.x86_64.rpm
  	#rpm -i /root/install/misc/unrar-5.0.3-1.el6.rf.x86_64.rpm
  	#/usr/bin/unrar x ${EXE} ${EXTRACT_DIR}
  fi
}

COPY_INSTALLATION_MEDIA(){
  mkdir -p ${EXTRACT_DIR};
  # check DATA_UNITS folder presence
  if [ -d "${COMPRESS_DIR}/DATA_UNITS" ]; then
    echo "no need to extract -> move from ${COMPRESS_DIR} to ${EXTRACT_DIR} only";
    mv -f ${COMPRESS_DIR}* ${EXTRACT_DIR}
  else
    echo "seems extract is required";
    EXTRACT;
  fi
}


DOWNLOAD_BACKUP_FILES(){
  echo "Downloading Backup"
  echo "BACKUP_S3_PATH: $BACKUP_S3_PATH  into  BACKUP_DESTINATION: $BACKUP_DESTINATION files BACKUP_FILENAME_START_WITH: $BACKUP_FILENAME_START_WITH";
  #BACKUP_S3_PATH=s3://vtx-sap-media/SET_2019_06v01/backup/
  #BACKUP_DESTINATION="/backup/data/HDB/DB_HDB"
  #BACKUP_FILENAME_START_WITH="COMPLETE_DATA_BACKUP"

  # eliminating soft lockup by limiting max_concurrent_requests: https://docs.aws.amazon.com/cli/latest/topic/s3-config.html
  aws configure set default.s3.max_concurrent_requests 1
  aws configure set default.s3.max_bandwidth 50MB/s

  sysctl vm.dirty_ratio; sysctl -w vm.dirty_ratio=10
  sysctl vm.dirty_background_ratio; sysctl -w vm.dirty_background_ratio=5
  sysctl -p

  exCode=1; counter=0; waitTime=60;
  maxAttempts=5
  until (( $exCode == 0 )) || (( $counter == $maxAttempts ));
  do
    counter=$[$counter+1];
    echo "Attempt $counter / $maxAttempts";
    aws s3 sync ${BACKUP_S3_PATH} ${TEMP_DIR_FOR_DOWNLOADED_BACKUP} \
          --exclude "*" --include "${BACKUP_FILENAME_START_WITH}*";
    exCode=$?; echo "exCode: $exCode"
    if [ "$exCode" != "0" ]; then echo "wait ${waitTime} seconds"; sleep $waitTime; fi;
  done;
  aws configure set default.s3.max_concurrent_requests 10
  aws configure set default.s3.max_bandwidth 500MB/s

  mkdir -p ${BACKUP_DESTINATION}
  echo "move FROM ${TEMP_DIR_FOR_DOWNLOADED_BACKUP} TO ${BACKUP_DESTINATION}/"
  mv -fv ${TEMP_DIR_FOR_DOWNLOADED_BACKUP}* ${BACKUP_DESTINATION}/

  ls -la ${BACKUP_DESTINATION}/;

  return $exCode
}

#MAIN BODY#
echo "RESTORE_FROM_BACKUP: $RESTORE_FROM_BACKUP"

if [ "${RESTORE_FROM_BACKUP}" == 'Yes' ]; then
  COPY_INSTALLATION_MEDIA && DOWNLOAD_BACKUP_FILES;
else
  COPY_INSTALLATION_MEDIA;
fi;

#!/bin/bash
exCode=1; counter=0; waitTime=60;
maxAttempts=5
until (( $exCode == 0 )) || (( $counter == $maxAttempts ));
do
  counter=$[$counter+1];
  echo "Attempt $counter / $maxAttempts";
  aws s3 sync ${BACKUP_S3_PATH} ${BACKUP_DESTINATION} \
        --exclude "*" --include "${BACKUP_FILENAME_START_WITH}*";
  exCode=$?; echo "exCode: $exCode"
  if [ "$exCode" != "0" ]; then echo "wait ${waitTime} seconds"; sleep $waitTime; fi;
done;

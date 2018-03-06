#!/usr/local/bin/bash

GZIP=`which gzip`
WORK_DIR=/bscs/work/ARCHIVE/CDR/ALGER
LOG_FILE=/bscs/work/LOG/archive_logs.log

for DIR_NAME in `ls -1d 04*`
do
 FILE_NAME=CONST_20`basename "${DIR_NAME}"`
 echo "${FILE_NAME}" | tee -a $LOG_FILE
 tar -cvf "${FILE_NAME}".tar $DIR_NAME/*
 rm -rf "${DIR_NAME}"
 gzip "${FILE_NAME}".tar
 echo Arhcive "${FILE_NAME}".tar created | tee -a $LOG_FILE
done

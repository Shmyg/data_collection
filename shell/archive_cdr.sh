#!/usr/local/bin/bash

#***********************************************************************#
# NAME
#	archive_cdr.sh       
#
# SYNOPSIS
#       
#	archive_cdr.sh
#
# DESCRIPTION
#
#	Scripts takes all the CDR files in archive directory, tars and
#	gzips them.
#
#	Workflow:
#	- directory list is retreived from MSC_LIST file under
#	WORK_DIR directory
#	- for each FILE_DIR from list under ARCHIVE_DIR directory all the
#	files by mask FILE_PREFIX.YESTERDAY are tarred and gzipped
#       - if the files are archived successfully, they are added to
#       file_list.txt file in each directory
#	- if previous step is successful, all the files by the same
#	mask are deleted from ARCHIVE_DIR and WORK_DIR
#
# AUTHOR
#       
#	Shmyg 17.11.2004
#
# HISTORY OF CHANGES
#
#	$Log: archive_cdr.sh,v $
#	Revision 1.7  2004/12/22 09:55:30  serge
#	Fixed archive_cdr.sh to skip commented lines in NE list
#
#	Revision 1.6  2004/12/16 10:35:41  serge
#	Added insertion of all the archived filenames to the list
#	in each archived directory
#	
#	Revision 1.5  2004/12/08 13:16:04  serge
#	Fixed bug in calculation of files
#	
#	Revision 1.4  2004/12/08 08:06:15  serge
#	Fixed bug in mailx command
#	
#	Revision 1.3  2004/12/07 15:54:38  serge
#	Added results mailing into archive_cdr.sh
#	
#	Revision 1.2  2004/12/02 09:42:52  serge
#	Added CDR files deletion for previous day for WORK_DIR
#	
#	Revision 1.1  2004/12/01 09:22:04  serge
#	Changed directory structure
#	
#	Revision 1.5  2004/11/29 11:11:09  serge
#	Added files to parse FIH logs
#	
#	Revision 1.4  2004/11/18 14:40:33  serge
#	Tested archive_cdr.sh. Fixed poll_cdr.sh but didn't test
#	
#	Revision 1.3  2004/11/18 13:02:48  serge
#	Added check if MSC_LIST exists
#	
#	Revision 1.2  2004/11/18 12:53:48  serge
#	Fixed archive CDR - made it look inside ARCHIVE directory instead of
#	WORK. Added file to archive old CDRs - needed only for initial
#	cleaning
#	
#	Revision 1.1  2004/11/17 14:21:17  serge
#	Added script for CDR archival
#	
#
#***********************************************************************#

. /bscs/bscsenv

WORK_DIR="${WORK}"/MP/SWITCH/FTAM/IN
ARCHIVE_DIR="${WORK}"/ARCHIVE/CDR
MSC_LIST="${WORK_DIR}"/msc_list.txt
SCRIPTS_DIR=/bscs/scripts
GZIP=`which gzip`
YESTERDAY=`"${SCRIPTS_DIR}"/get_date.sh`

trap "exit 1" 0 1 2 15

if [[ "${YESTERDAY}"X = X ]]
then
 echo Cannot calculate date. Exiting...
 exit 1
fi

[ -s "${MSC_LIST}" ] || { echo Cannon find file "${MSC_LIST}". Exiting...; exit 1; }

exec 3< $MSC_LIST

while read MSC_NAME IP_ADDRESS FTP_USER FTP_PASS FILE_DIR FILE_PREFIX REMOTE_FILE <&3
do

 # Checking if variables are defined
 : ${MSC_NAME:?} ${IP_ADDRESS:?} ${FTP_USER:?}
 : ${FTP_PASS:?} ${FILE_DIR:?} ${FILE_PREFIX:?} ${REMOTE_FILE:?}

 # Line can be commented out
 if [[ "${MSC_NAME:0:1}" = "#" ]]
 then
  continue
 fi

 cd "${ARCHIVE_DIR}"/"${FILE_DIR}" || \
  { echo Cannot change directory to "${FILE_DIR}"; exit 1; }

 # We need to get a substring from the date because it is in the format YYYYMMDD and we
 # need YYMMDD
 FILE_QTY=`ls "${FILE_PREFIX}"."${YESTERDAY:2:6}"* | wc -l`
 if [[ "${FILE_QTY}" -gt "0" ]] 
 then

  tar -cfv "${FILE_DIR}"_"${YESTERDAY}".tar "${FILE_PREFIX}"."${YESTERDAY:2:6}"* || \
   { echo Cannot tar and remove files in directory "${FILE_DIR}". Exiting...; \
   exit 1; }

  # Adding archived filenames to the list
  for file_name in `tar -tf "${FILE_DIR}"_"${YESTERDAY}".tar`
  do
   echo "${FILE_DIR}"_"${YESTERDAY}".tar "${file_name}" >> file_list.txt
  done

 else
  echo There are no files "${FILE_PREFIX}"."${YESTERDAY:2:6}"
 fi

 if [ -e "${FILE_DIR}"_"${YESTERDAY}".tar -a -s "${FILE_DIR}"_"${YESTERDAY}".tar ]
 then

  $GZIP -f "${FILE_DIR}"_"${YESTERDAY}".tar || { echo Cannot gzip files in directory \
   "${FILE_DIR}. Exiting..."; exit 1; }

  file_num=`ls "${FILE_PREFIX}"."${YESTERDAY:2:6}"* | wc -l`

  mail_message="$mail_message
Number of files archived for $FILE_DIR is: $file_num"

  # Cleaning up directory
  rm "${FILE_PREFIX}"."${YESTERDAY:2:6}"* 
  
  # Cleaning working directory
  rm "${WORK_DIR}"/"${FILE_DIR}"/"${FILE_PREFIX}"."${YESTERDAY:2:6}"*

 fi

done

echo "${mail_message}" | mailx -s "CDR archival log" "${SUPPORT_MAIL}"

exec 3<&-

exit 0

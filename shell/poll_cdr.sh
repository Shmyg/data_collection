#!/usr/local/bin/bash

#***********************************************************************#
# NAME
#       poll_cdr.sh
#
# SYNOPSIS
#       poll_cdr.sh
#
# DESCRIPTION
#       Collects CDR files from the MSC. All the MSCs to get the date from
#       must be entered in 'MSC_LIST' file. File format:
#
#       MSC_NAME IP_ADDRESS FTP_USER FTP_PASS FILE_DIR \
#	FILE_PREFIX REMOTE_FILENAME TMP_FILENAME
#
#	If any of the parameters is missing, script terminates with error
#	All the MSCs are checked for availability by ping command. If the
#	MSC is available, CDR file is retreived by FTP and put into the
#	directory $WORK_DIR/$FILE_DIR that must exist. If directory
#	doesn't exist, script is terminated with error.
#	CDR file is retreived in two copies. Copies are tested for
#	identity. If they're not identical, script terminates with error.
#	After that new file is compared with the last file retreived. 
#	Information about the previuos file is retreived from ID file. If
#	the file doesn't exist, script terminates with error. So for the
#	first launch dummy ID and CDr files must be created. If the new
#	file and the previous one are identical, script terminates with
#	error. If they're not, new ID file with information about the new
#	CDR file is created and CDR file is backed up.
#
# AUTHOR
#       Originally written by Kenny Kong. Re-developed by Shmyg
#
#***********************************************************************#

#-----------------------------------------------------------------------#
#
# HISTORY OF CHANGES
#
# $Log: poll_cdr.sh,v $
# Revision 1.7  2005/02/24 09:14:46  serge
# Added e-mail sending to both support teams (poll_cdr.sh)
#
# Revision 1.6  2005/02/23 13:24:26  serge
# Changed e-mail address to send logs to (poll_cdr.sh)
#
# Revision 1.5  2004/12/22 09:55:30  serge
# Fixed archive_cdr.sh to skip commented lines in NE list
#
# Revision 1.4  2004/12/19 16:30:43  serge
# Added possibility to comment lines from MSC list
#
# Revision 1.3  2004/12/05 09:42:08  serge
# Added copying to DIH_INPUT_DIR and modified doc
#
# Revision 1.2  2004/12/01 14:41:52  serge
# Working production version
#
# Revision 1.7  2004/11/29 11:11:09  serge
# Added files to parse FIH logs
#
# Revision 1.6  2004/11/18 14:40:33  serge
# Tested archive_cdr.sh. Fixed poll_cdr.sh but didn't test
#
# Revision 1.5  2004/11/18 12:55:45  serge
# Incorporated changes in poll_cdr.sh made during the testing
#
# Revision 1.4  2004/11/16 17:02:57  serge
# First testing on MSC
#
# Revision 1.3  2004/11/16 09:20:09  serge
# Added MSC list. Added REMOTE_FILE variable retreival from the list
#
# Revision 1.2  2004/11/15 16:18:21  serge
# Almost working version
#
# Revision 1.1.1.1  2004/11/14 16:51:14  serge
# Files for MSC data collection
#
#***********************************************************************#


#-----------------------------------------------------------------------#
# Initialization section
#-----------------------------------------------------------------------#

. /bscs/bscsenv

CONTR_FILE="${WORK}"/CTRL/poll_cdr.PID
MSC_LIST="${WORK}"/MP/SWITCH/FTAM/IN/msc_list.txt
BACKUP_DIR="${WORK}"/ARCHIVE/CDR/
LOG_FILE="${WORK}"/TMP/POLL_CDR_`date +%Y%m%d%H%M`.LOG
WORK_DIR="${WORK}"/MP/SWITCH/FTAM/IN
VDATE=`date +%y%m%d%H%M`
DIH_INPUT_DIR="${WORK}"/MP/SWITCH/FTAM

# Variables
mail_subject='Data collection log'

# Trapping exit and removing temporary files

trap 'rm $CONTR_FILE; cat $LOG_FILE | mailx -s "${mail_subject}" $IT_SUPPORT_MAIL $SUPPORT_MAIL' EXIT

report_error()
{
 mail_subject='Data collection terminated with ERRORS!'
}

#-----------------------------------------------------------------------#
# backup()
# Procedure to backup the downloaded cdr files before they are processed 
# by the BSCS
#-----------------------------------------------------------------------#

backup()
{
if [ ! -d "$BACKUP_DIR" ]
then
 echo ERROR: Backup directory doesn\'t exist. Trying to create | tee -a "${LOG_FILE}"
 mkdir -p "${BACKUP_DIR}" || \
  { echo ERROR: Cannot create backup directory for "${MSC_NAME}"; report_error; continue; }
fi

echo New file is $NEW_FILE
cp "${NEW_FILE}" "${BACKUP_DIR}"/"${FILE_DIR}" || \
 { echo ERROR: File backup for "${MSC_NAME}" failed; report_error; continue; }
}

#-----------------------------------------------------------------------#
# ftp_delete()
# Procedure for releasing the already downloaded and checked cdr file 
# on the MSC, for a new cdr file to be collected.
#-----------------------------------------------------------------------#

ftp_delete()
{
ftp -n "${IP_ADDRESS}"<< EOF
user "${FTP_USER}" "${FTP_PASS}"
delete  "${REMOTE_FILE}"
quit
EOF

if [[ ! $? -eq 0 ]]
then
 echo ERROR: Release of CDR file on "${MSC_NAME}" has failed
 report_error
 continue
else
 echo File on "${MSC_NAME}" successfully released | tee -a $LOG_FILE
fi

}

#-----------------------------------------------------------------------#
# cdr_done()
# Checking if the cdr file downloaded already exists and check if cdr
# was moved correctly.
# If it does exist, or if there was any problems with moving the new cdr
# then issue a FAIL status and stop.
#-----------------------------------------------------------------------#

cdr_done()
{
id_file=`ls -1 *.ID | tr -d A-Z | tr -d .`
OLD_FILE="${FILE_PREFIX}"."${ID_FILE}"
NEW_FILE="${FILE_PREFIX}"."${VDATE}"
mv "${TMP_FILENAME}"_a.tmp "${NEW_FILE}" || { echo Error while renaming file; exit 1; }
echo "INDEX file. DO NOT DELETE!" > "${VDATE}".ID
echo Last cdr file downloaded: - "${NEW_FILE}" >> "${VDATE}".ID
echo Last file downloaded is "${OLD_FILE}" | tee -a $LOG_FILE
echo New file is "${NEW_FILE}" | tee -a $LOG_FILE
# Comparing last saved file with the downloaded one
case `cmp "${OLD_FILE}" "${NEW_FILE}"` in
 "" ) echo Duplicate check for "${MSC_NAME}" failed! File already exists | tee -a $LOG_FILE
      rm -f "${NEW_FILE}"
      rm -f "${VDATE}".ID
      rm -f "${TMP_FILENAME}"_b.tmp
      report_error;
      continue;;
 * ) echo Duplicate check successful | tee -a $LOG_FILE
     FILE_SIZE=`ls -l "${NEW_FILE}" | awk '{print $5}'`
     echo Downloaded file size is: "${FILE_SIZE}" | tee -a $LOG_FILE
     cp "${NEW_FILE}" "${DIH_INPUT_DIR}"
     rm -f "${TMP_FILENAME}"_b.tmp
     rm -f "${ID_FILE}".ID;;
esac
}

#-----------------------------------------------------------------------#
# ftp_get()
# Procedure for connecting to the MSC and collect two instances of the
# same file. After that both instances are checked for identity. Temporary
# filenames must not be changed or else ftp won't work
#
#-----------------------------------------------------------------------#

ftp_get()
{
echo "${TMP_FILENAME}"_a.tmp
ftp -n "${IP_ADDRESS}"<< EOF
user "${FTP_USER}" "${FTP_PASS}"
binary
get "${REMOTE_FILE}" "${TMP_FILENAME}"_a.tmp
get "${REMOTE_FILE}" "${TMP_FILENAME}"_b.tmp
quit
EOF

if [[ ! $? -eq 0 ]]
then
 echo ERROR: FTP transfer for "${MSC_NAME}" failed
 report_error
 continue
else
 echo File from "${MSC_NAME}" is successfully downloaded | tee -a "${LOG_FILE}"
fi

# Check if both files exist
if [[ -e "${TMP_FILENAME}"_a.tmp && -e "${TMP_FILENAME}"_b.tmp && -s "${TMP_FILENAME}"_a.tmp ]]
then
 # Check if files are identical and size is greater than 0
 if cmp "${TMP_FILENAME}"_a.tmp "${TMP_FILENAME}"_b.tmp
 then
  echo CDR file integrity check for "${MSC_NAME}" succeeded | tee -a $LOG_FILE
 else
  echo ERROR: CDR file integrity check for "${MSC_NAME}" failed | tee -a $LOG_FILE
  report_error
  continue
 fi
else
 echo ERROR: Download from "${MSC_NAME}" failed | tee -a $LOG_FILE
 report_error
 continue
fi
}


#-----------------------------------------------------------------------#
# check_idfile()
# Check if the ID file exists in the directory
# This file is used as control file to mark the last downloaded cdr file.
#  if 0 exist then error.
#  if 2 exist then error.
#  if 1 exist then success.
# If only one ID file exists, the script will proceed.
#
# ID FILE FORMAT... (yymmddhhmmss)
# file name: 0408101048.ID
#
# file content..
# INDEX file. Do Not Delete!
# Last cdr file downloaded: - IA.ICMCRAL.0408101048 @ 2004/08/10-10:48
#-----------------------------------------------------------------------#

check_idfile()
{
CHECK_ID=`ls -l *.ID | wc -l`
pwd
case "$CHECK_ID" in
 "0") echo "ERROR: ID file is not found" | tee -a $LOG_FILE
      report_error
      continue;;
 "1") ID_FILE=`ls -1 *.ID | tr -d A-Z | tr -d .`
      if [[ -e "$FILE_PREFIX.$ID_FILE" &&  -s "$FILE_PREFIX.$ID_FILE" ]]
      then
       echo CDR ID file for "${MSC_NAME}" verification successful | tee -a "${LOG_FILE}"
      else
       echo ERROR: CDR file specified in ID file doesn\'t exist | tee -a $LOG_FILE
       report_error
       continue
      fi;;
  * ) echo ERROR: more than one ID file exists | tee -a $LOG_FILE
      report_error
      continue;;
esac
}

#-----------------------------------------------------------------------#
# Main
#-----------------------------------------------------------------------#

# Check if process is running
if [ -e $CONTR_FILE ]
then
  echo ERROR: Process is already running. Exiting... | tee -a $LOG_FILE
  report_error
  exit 1
else
 echo $$ > $CONTR_FILE
fi

echo Starting work at `date +"%H:%M:%S"` | tee -a $LOG_FILE
echo ----------------------------------------------------- | tee -a $LOG_FILE

# Reading MSC list
exec 3< $MSC_LIST

echo Output sent to: "${LOG_FILE}"

# Processing list
while read MSC_NAME IP_ADDRESS FTP_USER FTP_PASS \
 FILE_DIR FILE_PREFIX REMOTE_FILE TMP_FILENAME <&3
do

 # Checking if variables are defined
 : ${MSC_NAME:?} ${IP_ADDRESS:?} ${FTP_USER:?} ${FTP_PASS:?}
 : ${FILE_DIR:?} ${FILE_PREFIX:?} ${REMOTE_FILE:?} ${TMP_FILENAME:?}

 # Line can be commented out
 if [[ "${MSC_NAME:0:1}" = "#" ]]
 then
  continue
 fi

 # Checking if MSC is alive
 if ping "${IP_ADDRESS}" -n 2 -m 10 &> /dev/null
 then
  echo MSC "${MSC_NAME}" is up | tee -a $LOG_FILE
 else
  echo ERROR: MSC "${MSC_NAME}" is not available | tee -a $LOG_FILE
  report_error
  continue
 fi

 if [ ! -d "${WORK_DIR}"/"${FILE_DIR}" ] 
 then
  echo ERROR: Directory to put files in "${WORK_DIR}"/"${FILE_DIR}" doesn\'t exist!
  report_error
  continue
 else
  cd "${WORK_DIR}"/"${FILE_DIR}" || { echo ERROR: Cannot change directory to \
   "${WORK_DIR}"/"${FILE_DIR}"; report_error; continue; }
 fi

 check_idfile
 ftp_get
 cdr_done
 ftp_delete
 backup
 echo ----------------------------------------------------- | tee -a $LOG_FILE
done

exec 3<&-

echo Finishing work at `date +"%H:%M:%S"` | tee -a $LOG_FILE

exit 0

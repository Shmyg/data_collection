#!/usr/local/bin/bash

#***********************************************************************#
# NAME
#       
#  extract_archived_filenames.sh
#
# SYNOPSIS
#       
#  extract_archived_filenames.sh
#
# DESCRIPTION
#
#  Extracts all the filenames from all gzip archives in current
#  directory and puts them into file_list.txt file
#
# AUTHOR
#       
#  Shmyg
#
# HISTORY OF CHANGES
#
#	$Log: extract_archived_filenames.sh,v $
#	Revision 1.2  2004/12/16 14:59:57  serge
#	Fixed list_file variable in exctract_archived_filenames.sh
#
#	Revision 1.1  2004/12/16 14:58:26  serge
#	Added file to get archived filenames
#	
#
#***********************************************************************#

trap "exit 1" 0 1 2 15

list_file='file_list.txt'

for archive_name in *.gz
do
 echo Processing archive "${archive_name}"
 for file_name in `cat "${archive_name}" | gzcat | tar -tf -`
  do
   echo "${archive_name}" "${file_name}" >> "${list_file}"
  done
done

exit 0

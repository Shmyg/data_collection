/*
|| Script to get statistics for loaded into BSCS files
|| (CDR data)
||
|| $Log: files_collected.sql,v $
|| Revision 1.1  2004/12/15 15:13:29  serge
|| Added script to collect statistics by CDR filename
||
*/

SET PAGESIZE 0
SET TRIMSPOOL ON
SET LINESIZE 32767
SET TAB OFF
SET FEEDBACK OFF
SET ECHO OFF
SET VERIFY OFF
SET TERMOUT OFF

COLUMN begin_date new_val start_date
SELECT  TO_CHAR( SYSDATE, 'YYYYMMDDHH24MI' ) begin_date
FROM    DUAL; 


SPOOL files_collected_&&start_date..txt

SELECT	SUBSTR( filename, INSTR( filename, '.', 1, 1 ) + 1,
		( INSTR( filename, '.', 1, 2 ) - 
			(INSTR( filename, '.', 1, 1 ) + 1) ) ),
	SUBSTR( filename, INSTR( filename, '.', 1, 2 ) + 1, 6 ),
	fs.shdes,
	COUNT(*)
FROM	thufitab	th,
	file_status	fs
WHERE	fs.status = th.status
AND	filename LIKE 'IA%'
GROUP	BY SUBSTR( filename, INSTR( filename, '.', 1, 1 ) + 1, 
		( INSTR( filename, '.', 1, 2 ) - 
			(INSTR( filename, '.', 1, 1 ) + 1) ) ),
	SUBSTR( filename, INSTR( filename, '.', 1, 2 ) + 1, 6 ),
	fs.shdes
/

SPOOL OFF

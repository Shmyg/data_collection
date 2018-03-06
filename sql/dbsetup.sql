CREATE	TABLE &owner..file_status
	(
	status		NUMBER,
	shdes		VARCHAR2(30),
	status_desc	VARCHAR2(500),
	CONSTRAINT	pk_file_status
	PRIMARY	KEY
		(
		status
		)
	)
ORGANIZATION INDEX
/

CREATE	GLOBAL TEMPORARY TABLE &owner..temp_results
	(
	line	CLOB
	)
ON COMMIT DELETE ROWS
/

grant select on thufitab to &owner.;
grant select on thsfttab to &owner.;


exec DBMS_JOB.SUBMIT( :v_job_num, 'begin data_collection.received_files_stat(trunc(sysdate)-1,
trunc(sysdate), ''Y''); end;', TRUNC(SYSDATE) + 1 + 2/24, 'TRUNC(SYSDATE) + 1 + 2/24');

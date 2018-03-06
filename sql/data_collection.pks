CREATE OR REPLACE
PACKAGE	&owner..data_collection
AS
	-- Provides statistics about data collected for the
	-- dates provided. By default - for yesterday
	PROCEDURE	received_files_stat
		(
		i_start_date	DATE := TRUNC( SYSDATE ) - 1,
		i_end_date	DATE := TRUNC( SYSDATE ),
		i_mail_result	VARCHAR2 := 'N'
		);

	-- These are 2 functions to convert UNIX time to human and
	-- vice versa
	FUNCTION	human_time
		(
		i_unix_time	IN NUMBER
		)
	RETURN	DATE;

	FUNCTION	unix_time
		(
		i_human_time	IN DATE := SYSDATE
		)
	RETURN	NUMBER;

	-- Provides statistics (amount, open amount, payment amount
	-- etc) about CBB created for the date provided. By default - 
	-- yesterday
	PROCEDURE	cbb_stat
		(
		i_start_date	DATE := TRUNC( SYSDATE ) - 1,
		i_end_date	DATE := TRUNC( SYSDATE ),
		i_mail_result	VARCHAR2 := 'N'
		);

END	data_collection;
/

SHOW ERRORS


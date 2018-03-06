CREATE	OR REPLACE
PACKAGE	BODY data_collection
AS

PROCEDURE	received_files_stat
	(
	i_start_date	IN DATE := TRUNC( SYSDATE ) - 1,
	i_end_date	IN DATE := TRUNC( SYSDATE ),
	i_mail_result	IN VARCHAR2 := 'N'
	)
AS

	v_line		CLOB;
	v_message	CLOB;

	CURSOR	line_cur
	IS
	SELECT	line
	FROM	temp_results;
	
BEGIN

	INSERT	INTO temp_results
		(
		SELECT	TO_CHAR( TRUNC( tu.received ), 'DD.MM.YYYY' ) || ' ' ||
			RPAD( th.description, 50, '.' ) || ' Status: ' ||
			RPAD( fs.shdes, 35, '.' ) ||
			LPAD( COUNT( tu.file_id ), 4 )
		FROM	thufitab	tu,
			thsfttab	th,
			file_status	fs
		WHERE	tu.file_type = th.ft_id
		AND	tu.status = fs.status
		AND	tu.received >= i_start_date
		AND	tu.received < i_end_date
		GROUP	BY TO_CHAR( TRUNC( tu.received ), 'DD.MM.YYYY' ),
			fs.shdes,
			th.description
	);

	IF	i_mail_result = 'Y'
	THEN

	        OPEN    line_cur;
        	LOOP
	
        	        FETCH   line_cur
        	        INTO    v_line;

 	               EXIT    WHEN line_cur%NOTFOUND;

 	               v_message := v_message || CHR(10) || CHR(32) || v_line;

		END     LOOP;

		CLOSE   line_cur;

		mailit.mailusers
			(
			'data_collection_group',
			NULL,
			'Data collection log for period ' || i_start_date ||
				'-' || i_end_date,
			v_message
			);

	END	IF;

END	received_files_stat;

FUNCTION	human_time
	(
	i_unix_time	IN NUMBER
	)
RETURN	DATE
IS

	v_date	DATE;

BEGIN

	SELECT	TO_DATE( '01.01.1970', 'DD.MM.YYYY' ) + i_unix_time / 86400
	INTO	v_date
	FROM	DUAL;

	RETURN	v_date;

END	human_time;

FUNCTION	unix_time
	(
	i_human_time	IN DATE := SYSDATE
	)
RETURN	NUMBER
IS

	v_unix_time	PLS_INTEGER;

BEGIN

	SELECT	( i_human_time - TO_DATE( '01.01.1970', 'DD.MM.YYYY' )) * 86400
	INTO	v_unix_time
	FROM	DUAL;

	RETURN	v_unix_time;	

END	unix_time;


PROCEDURE       cbb_stat
	(
	i_start_date    DATE := TRUNC( SYSDATE ) - 1,
	i_end_date      DATE := TRUNC( SYSDATE ),
	i_mail_result   VARCHAR2 := 'N'
	)
AS

	v_line		CLOB;
	v_message	CLOB;

	CURSOR	line_cur
	IS
	SELECT	line
	FROM	temp_results;

	-- Mail alias to send e-mails to
	c_mail_alias	CONSTANT &owner..user_mailids.user_alias%TYPE :=
				'cbb_support'; 

	-- Mail subject
	v_subject	VARCHAR2(40) := 'CBB log for period ';

	-- Header to put on the report
	c_header	CONSTANT VARCHAR2(200) := 
		'_______TX_ID Rateplan________________________ ____CO_ID ' ||
		'___CBB amount _Correct amount __Open amount _Payment amount ___Difference';

BEGIN


INSERT	INTO temp_results
	(
	line
	)
VALUES	(
	c_header
	);


INSERT	INTO temp_results
	(
	line
	)
VALUES	(
	''
	);

-- Getting info and putting it into temporary table
INSERT	INTO temp_results
	(
	SELECT  LPAD( oa.ohxact, 12 ) || ' ' ||
		RPAD( rp.des, 32 ) ||
		LPAD( oa.co_id, 10 ) ||
		LPAD( TRUNC( oa.ohinvamt_gl ), 14 ) ||
		LPAD( TRUNC( tm.subscript * 1.17 + tm.accessfee * 1.17 ), 16 ) || 
		LPAD( TRUNC( oa.ohopnamt_gl ), 14 ) ||
		LPAD( oa.cadamt_gl, 16 ) ||
		LPAD( ( TRUNC( tm.subscript * 1.17 + tm.accessfee * 1.17 ) - TRUNC( oa.ohinvamt_gl ) ), 14 )
	FROM    (
		SELECT  oh.ohxact,
			oh.customer_id,
			oh.co_id,
			oh.ohinvamt_gl,
			oh.ohopnamt_gl,
			NVL( cd.cadamt_gl, 0 ) AS cadamt_gl,
			oh.ohentdate
		-- Selecting all the CBB invoices for the period provided 
		-- and associated payments (if any)
		FROM    orderhdr_all    oh
		LEFT	OUTER JOIN cashdetail cd
		ON      oh.ohxact = cd.cadoxact
		WHERE   TRUNC( oh.ohentdate ) >= i_start_date
		AND	TRUNC( oh.ohentdate ) < i_end_date
		AND     ohstatus = 'IN'
		AND     ohinvtype = 1
		)               oa,
		rateplan        rp,
		rateplan_hist   rh,
		mpulktmb        tm
	WHERE   oa.co_id = rh.co_id
	AND     rh.tmcode = tm.tmcode
	AND     rp.tmcode = rh.tmcode
	-- Looking for 'Telephony' service
	AND     tm.sncode = 1
	-- Looking for the initial rateplan
	AND     rh.seqno =
		(
		SELECT  MIN( seqno )
		FROM    rateplan_hist
		WHERE   co_id = oa.co_id
		)
	-- Looking for the last version of the rateplan
	AND     tm.vsdate =
		(
		SELECT  MAX( vsdate )
		FROM    mpulktmb
		WHERE   tmcode = tm.tmcode
		AND     vsdate < oa.ohentdate
		)
	);


	IF	i_mail_result = 'Y'
	THEN

	        OPEN    line_cur;
        	LOOP
	
        	        FETCH   line_cur
        	        INTO    v_line;

 	               EXIT    WHEN line_cur%NOTFOUND;

 	               v_message := v_message || CHR(10) || CHR(32) || v_line;

		END     LOOP;

		CLOSE   line_cur;

		mailit.mailusers
			(
			c_mail_alias,
			NULL,
			v_subject || i_start_date ||
				'-' || i_end_date,
			v_message
			);

	END	IF;
END	cbb_stat;

END	data_collection;
/

SHOW ERRORS


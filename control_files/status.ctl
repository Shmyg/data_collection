LOAD	DATA
INTO	TABLE file_status
TRUNCATE
FIELDS	TERMINATED BY '-'
TRAILING NULLCOLS
	(
	status	INTEGER EXTERNAL,
	status_desc,
	shdes
	)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------Deleting previous generated Tables----------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--SELECT 'begin' || chr(13) || chr(10) || 'TRY_ANSWER(' || listagg(voc_in_stat_id, ', '''', 1);' || chr(13) || chr(10) || 'TRY_ANSWER(') within group (order by voc_in_stat_id) over (partition by mail) || ', '''', 1);' || chr(13) || chr(10) || 'end;' as test from v_all_vocabulary_to_learn vl

DROP TABLE T_DEBUG;
DROP TABLE T_VOCABULARY_IN_STATISTIC;
DROP TABLE T_USER_VOCABULARY_PRACTICE;
DROP TABLE T_TRANSLATION;
DROP TABLE T_VOCABULARY;
DROP TABLE T_STATISTIC;
DROP TABLE T_LANGUAGE;
DROP TABLE T_UNIT;
DROP TABLE T_USERS;
DROP TABLE T_ALL_RESSOURCES;
DROP TABLE T_STATISTIC_TIME;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------Creating the Tables--------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE T_USERS(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	EMAIL VARCHAR2(40) NOT NULL,
	FIRST_NAME VARCHAR(16) NOT NULL,
	LAST_NAME VARCHAR(16) NOT NULL,
	CONSTRAINT USERS_PK PRIMARY KEY (ID)
);

CREATE TABLE T_UNIT(
	ID NUMBER  GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	NAME VARCHAR(16) NOT NULL,
	CONSTRAINT UNIT_PK PRIMARY KEY(ID)
);

CREATE TABLE T_LANGUAGE (
	ID NUMBER  GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	NAME VARCHAR(5) NOT NULL,
	CONSTRAINT LANGUAGE_PK PRIMARY KEY (ID)
);

CREATE TABLE T_STATISTIC(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	USERS_ID NUMBER NOT NULL,
	TIMESTAMP_GENERATED TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    TIMESTAMP_DONE TIMESTAMP(6),
	CONSTRAINT STATISTIC_PK PRIMARY KEY(ID),
	CONSTRAINT USER_FK FOREIGN KEY (USERS_ID) REFERENCES T_USERS(ID)
);

CREATE TABLE T_VOCABULARY(
 	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	UNIT_ID NUMBER NOT NULL,
	LANGUAGE_ID NUMBER NOT NULL,
	VOCABULARY VARCHAR(32) NOT NULL,
	CONSTRAINT VOCABULARY_PK PRIMARY KEY(ID),
	CONSTRAINT UNIT_FK FOREIGN KEY (UNIT_ID) REFERENCES T_UNIT(ID),
	CONSTRAINT LANGUAGE_VOC_FK FOREIGN KEY (LANGUAGE_ID) REFERENCES T_LANGUAGE(ID)
);

CREATE TABLE T_TRANSLATION(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	VOCABULARY_ID NUMBER NOT NULL,
	LANGUAGE_ID NUMBER NOT NULL,
	TRANSLATION VARCHAR(32) NOT NULL,
	CONSTRAINT TRANSLATION_PK PRIMARY KEY (ID),
	CONSTRAINT VOCABULARY_FK FOREIGN KEY (VOCABULARY_ID) REFERENCES T_VOCABULARY(ID),
	CONSTRAINT LANGUAGE_FK FOREIGN KEY (LANGUAGE_ID) REFERENCES T_LANGUAGE(ID)	
);

CREATE TABLE T_USER_VOCABULARY_PRACTICE(
	TIMESTAMP_LAST_PRACTICE TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
	VOCABULARY_ID NUMBER NOT NULL,
	USERS_ID NUMBER NOT NULL,
	CATEGORY NUMBER NOT NULL,
	COUNTER NUMBER NOT NULL,
	CONSTRAINT USER_PRACTICE_PK PRIMARY KEY (VOCABULARY_ID, USERS_ID),
	CONSTRAINT PRACTICE_USER_ID_FK FOREIGN KEY (USERS_ID) REFERENCES T_USERS(ID),
	CONSTRAINT PRACTICE_VOCABULARY_ID_FK FOREIGN KEY (VOCABULARY_ID) REFERENCES T_VOCABULARY(ID)
);

CREATE TABLE T_VOCABULARY_IN_STATISTIC(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	CORRECT NUMBER DEFAULT NULL,
	STATISTIC_ID NUMBER NOT NULL,
	VOCABULARY_ID NUMBER NOT NULL,
	CONSTRAINT VOCABULARY_IN_STATISTIC_PK PRIMARY KEY (ID),
	CONSTRAINT STATISTIC_VOC_FK FOREIGN KEY (STATISTIC_ID) REFERENCES T_STATISTIC(ID),	
	CONSTRAINT VOCABULARY_STAT_FK FOREIGN KEY (VOCABULARY_ID) REFERENCES T_VOCABULARY(ID)
);

CREATE TABLE T_DEBUG(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	MESSAGE VARCHAR(128), 
	MESSAGE_NUM NUMBER,
	CONSTRAINT DEBUG_PK PRIMARY KEY (ID)
);

CREATE TABLE T_ALL_RESSOURCES(
	RES_KEY VARCHAR(32) NOT NULL, 
	RES VARCHAR2(256) NOT NULL,
	CONSTRAINT RES_PK PRIMARY KEY (RES_KEY)
);

CREATE TABLE T_STATISTIC_TIME(
	CATEGORY NUMBER,
	HOURS NUMBER,
	CONSTRAINT STATISTIC_TIME_PK PRIMARY KEY (CATEGORY)
);
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Create Views-------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--------------any error------------------------------------------
CREATE OR REPLACE FORCE VIEW V_ERRORS AS
	SELECT * FROM SYS.USER_ERRORS WHERE (TYPE = 'PROCEDURE' OR TYPE = 'FUNCTION' OR TYPE='VIEW') AND NAME LIKE '%';


--Any vocabulary entry with any value asociated with any value of any translation entry 
CREATE OR REPLACE FORCE VIEW V_ALL_VOCABULARY_ENTRIES AS
SELECT TP.TIMESTAMP_LAST_PRACTICE,  COALESCE(CATEGORY, 0) AS CATEGORY, TU.ID AS USERS_ID, U.ID AS UNIT_ID, U.NAME AS UNIT, V.ID AS VOC_ID, V.VOCABULARY, V.LANGUAGE_ID AS VOC_LANG_ID, VL.NAME AS VOC_LANG, T.ID AS TRA_ID, T.TRANSLATION, T.LANGUAGE_ID AS TRA_LANG_ID, LL.NAME AS TRA_LANG
        FROM  T_VOCABULARY V
          INNER JOIN T_TRANSLATION T ON V.ID = T.VOCABULARY_ID 
          INNER JOIN T_UNIT U ON V.UNIT_ID = U.ID
          INNER JOIN T_LANGUAGE VL ON VL.ID = V.LANGUAGE_ID 
          INNER JOIN T_LANGUAGE LL ON LL.ID = T.LANGUAGE_ID
          LEFT JOIN T_USER_VOCABULARY_PRACTICE TP ON TP.VOCABULARY_ID = V.ID,
          T_USERS TU;
	
		
	
--Any vocabulary string with any translation string, distinct entries	
CREATE OR REPLACE FORCE VIEW V_ALL_VOCABULARY_TRANSLATIONS AS
	SELECT DISTINCT VOCABULARY, LISTAGG(TRANSLATION, ', ') WITHIN GROUP (ORDER BY VOCABULARY) OVER (PARTITION BY VOCABULARY) AS TRANSLATION
	FROM (SELECT VOCABULARY, TRANSLATION FROM T_VOCABULARY INNER JOIN T_TRANSLATION ON T_TRANSLATION.VOCABULARY_ID = T_VOCABULARY.ID) VOC;
		
	
--Any vocabulary to learn
CREATE OR REPLACE FORCE VIEW V_ALL_VOCABULARY_TO_LEARN AS
	SELECT TV.ID AS VOC_IN_STAT_ID, S.USERS_ID AS USERS_ID, U.EMAIL AS MAIL, TV.VOCABULARY_ID
	FROM T_VOCABULARY_IN_STATISTIC TV 
		INNER JOIN T_STATISTIC S ON TV.STATISTIC_ID = S.ID 
		INNER JOIN T_USERS U ON U.ID = S.USERS_ID
	WHERE TV.CORRECT IS NULL;
	
	
--------------------------------any vocabulary with category and timestamp----------------------------------------------
CREATE OR REPLACE FORCE VIEW V_ALL_VOCABULARY_PRACTICES AS
	SELECT VOCABULARY_ID, USERS_ID, A.CATEGORY,  (HOURS - HOURS_SINCE_LAST_PRACTICE) AS HOURS_NEEDED
		FROM
		(SELECT A.*, COALESCE(UP.CATEGORY, 0) AS CATEGORY, COALESCE(EXTRACT(DAY FROM CURRENT_TIMESTAMP - TIMESTAMP_LAST_PRACTICE)*24+EXTRACT(HOUR FROM CURRENT_TIMESTAMP - TIMESTAMP_LAST_PRACTICE), 999999) AS HOURS_SINCE_LAST_PRACTICE
		FROM (SELECT V.ID AS VOCABULARY_ID, U.ID AS USERS_ID FROM T_VOCABULARY V, T_USERS U) A 
			LEFT JOIN T_USER_VOCABULARY_PRACTICE UP ON UP.VOCABULARY_ID = A.VOCABULARY_ID AND UP.USERS_ID = A.USERS_ID) A
			INNER JOIN T_STATISTIC_TIME STT ON STT.CATEGORY = A.CATEGORY
ORDER BY A.USERS_ID, A.VOCABULARY_ID;


-------------------------------------creates the view with any learning tag needed----------------------------------------
CREATE OR REPLACE FORCE VIEW V_ALL_LEARNING_TAGS AS
	SELECT DISTINCT 
			USERS_ID, 
			'BEGIN' || CHR(13) || CHR(10) || 'TRY_ANSWER(' || 
			LISTAGG(VOC_IN_STAT_ID, ', '''', '|| USERS_ID ||');' ||
			CHR(13) || CHR(10) || 'TRY_ANSWER(') 
				WITHIN GROUP (ORDER BY VOC_IN_STAT_ID) OVER (PARTITION BY USERS_ID) || ', '''', '|| USERS_ID ||');' || CHR(13) || CHR(10) || 'END;' 
				AS VOCABULARIES   
	FROM V_ALL_VOCABULARY_TO_LEARN;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare Check Functions----------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------checks if the given answer is correct---------------------------------------------------
CREATE OR REPLACE FUNCTION CHECK_ANSWER(P_VOCABULARY_ID IN NUMBER, P_ANSWER IN VARCHAR2)
	RETURN BOOLEAN
	IS	
		V_NUMBER_OF_ROWS_WITH_THIS_ANSWER NUMBER;
	BEGIN
			SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_THIS_ANSWER FROM T_TRANSLATION WHERE TRANSLATION = P_ANSWER AND VOCABULARY_ID = P_VOCABULARY_ID;
			RETURN V_NUMBER_OF_ROWS_WITH_THIS_ANSWER > 0;
	END;
/

--------------------------------------------checks if the question was not answered before---------------------------------------------------
CREATE OR REPLACE FUNCTION NOT_YET_TRIED(P_VOCABULARY_IN_STATISTIC_ID IN NUMBER)
	RETURN BOOLEAN
	IS	
		V_NUMBER_OF_ANSWERED_ROWS NUMBER;
	BEGIN
			SELECT COUNT(*) INTO V_NUMBER_OF_ANSWERED_ROWS FROM T_VOCABULARY_IN_STATISTIC WHERE CORRECT IS NULL AND ID = P_VOCABULARY_IN_STATISTIC_ID;
			RETURN V_NUMBER_OF_ANSWERED_ROWS > 0;
	END;
/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare  Getter Functions--------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------returns the ressource by key-----------------------------
CREATE OR REPLACE FUNCTION GET_RESSOURCE(P_RES_KEY IN VARCHAR2)
	RETURN VARCHAR2
	IS V_RES VARCHAR2(256);
	BEGIN
		SELECT RES INTO V_RES FROM T_ALL_RESSOURCES WHERE RES_KEY = P_RES_KEY;
		RETURN V_RES;
	END;
/

--------------------returns the ressource by key-----------------------------
CREATE OR REPLACE FUNCTION GET_VOCABULARY_BY_ID(P_ID IN NUMBER)
	RETURN VARCHAR2
	IS V_VOCABULARY VARCHAR2(256);
	BEGIN
		SELECT VOCABULARY INTO V_VOCABULARY FROM T_VOCABULARY WHERE ID = P_ID;
		RETURN V_VOCABULARY;
	END;
/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare Procedures - "public" procedures and functions-----------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------creates a new vocabulary with translation. if unit, the vocabulary or the translation don't exist, they will be created------------------
------------------------------example: INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'legen', 'EN', 'to put', '1');--------------------------------------------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_VOCABULARY_WITH_TRANSLATION (P_LANGUAGE_DEFAULT IN VARCHAR2, P_WORD_LANGUAGE_DEFAULT IN VARCHAR2, P_LANGUAGE_TRANSLATE IN VARCHAR2, P_WORD_LANGUAGE_TRANSLATE IN VARCHAR2, P_UNIT_NAME IN VARCHAR2)
	IS
	BEGIN
		--insert default language
		MERGE INTO T_LANGUAGE DEST 
		USING (SELECT P_LANGUAGE_DEFAULT AS NAME FROM DUAL) SRC
		ON (SRC.NAME = DEST.NAME)
		WHEN NOT MATCHED THEN
			INSERT  (NAME) 
			VALUES (P_LANGUAGE_DEFAULT);	
		COMMIT;
			
		--insert translation language
		MERGE INTO T_LANGUAGE DEST 
		USING (SELECT P_LANGUAGE_TRANSLATE AS NAME FROM DUAL) SRC
		ON (SRC.NAME = DEST.NAME)
		WHEN NOT MATCHED THEN
			INSERT  (NAME) 
			VALUES (P_LANGUAGE_TRANSLATE);	
		COMMIT;
		
		--insert new unit if not exists
		MERGE INTO T_UNIT DEST 
		USING (SELECT P_UNIT_NAME AS NAME FROM DUAL) SRC
		ON (SRC.NAME = DEST.NAME)
		WHEN NOT MATCHED THEN
			INSERT (NAME) 
			VALUES (P_UNIT_NAME);	
		COMMIT;
			
		--insert new vocabulary
		MERGE INTO T_VOCABULARY DEST 
		USING (SELECT P_WORD_LANGUAGE_DEFAULT AS VOCABULARY, (SELECT ID FROM T_UNIT WHERE NAME = P_UNIT_NAME) AS UNIT_ID FROM DUAL) SRC
		ON (SRC.VOCABULARY = DEST.VOCABULARY AND SRC.UNIT_ID = DEST.UNIT_ID)
		WHEN NOT MATCHED THEN
			INSERT (VOCABULARY, UNIT_ID, LANGUAGE_ID) 
			VALUES (P_WORD_LANGUAGE_DEFAULT, (SELECT ID FROM T_UNIT WHERE NAME = P_UNIT_NAME), (SELECT ID FROM T_LANGUAGE WHERE NAME = P_LANGUAGE_DEFAULT));	
		COMMIT;	
		
		--insert new translation
		MERGE INTO T_TRANSLATION DEST
		USING (SELECT P_WORD_LANGUAGE_TRANSLATE AS TRANSLATION,  (SELECT V.ID FROM T_VOCABULARY V INNER JOIN T_UNIT U ON U.ID = U.ID WHERE V.VOCABULARY = P_WORD_LANGUAGE_DEFAULT AND U.NAME = P_UNIT_NAME) AS VOCABULARY_ID, (SELECT ID FROM T_UNIT U WHERE U.NAME = P_UNIT_NAME) AS UNIT_ID FROM DUAL) SRC
		ON (SRC.VOCABULARY_ID = DEST.VOCABULARY_ID AND SRC.TRANSLATION = DEST.TRANSLATION AND EXISTS(SELECT COUNT(*) FROM T_VOCABULARY WHERE UNIT_ID = SRC.UNIT_ID))
		WHEN NOT MATCHED THEN
			INSERT (TRANSLATION, LANGUAGE_ID, VOCABULARY_ID) 
			VALUES (P_WORD_LANGUAGE_TRANSLATE, (SELECT ID FROM T_LANGUAGE WHERE NAME  = P_LANGUAGE_TRANSLATE), (SELECT ID FROM T_VOCABULARY WHERE VOCABULARY = P_WORD_LANGUAGE_DEFAULT));	
		COMMIT;		
	END; 
/	

--------------------------------------------------inserts a new user if there is no user with this email---------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_USER (P_FIRST_NAME IN VARCHAR2, P_LAST_NAME IN VARCHAR2, P_EMAIL IN VARCHAR2)
	IS
	BEGIN
		MERGE INTO T_USERS DEST 
		USING (SELECT P_EMAIL AS EMAIL FROM DUAL) SRC
		ON (SRC.EMAIL = DEST.EMAIL)
		WHEN NOT MATCHED THEN
			INSERT (FIRST_NAME, LAST_NAME, EMAIL) 
			VALUES (P_FIRST_NAME, P_LAST_NAME, P_EMAIL);	
		COMMIT;	
	END; 
/		


--------------------------------------------------creates a new statistic for a user---------------------------------------------------------------------------------------------
------------------------P_CATEGORY = -1 for any category--------------------------------------------------------------------------------------------------------------------
------------------------P_UNIT = ' ' for any unit-----------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE CREATE_NEW_STATISTIC (P_CATEGORY IN NUMBER, P_UNIT IN VARCHAR2, P_USER_ID IN NUMBER)
	IS 
	BEGIN	
		--create the statistic itself
		INSERT INTO T_STATISTIC (USERS_ID) VALUES (P_USER_ID);
		COMMIT;
		
		--insert vocabularies to the statistic
		INSERT INTO T_VOCABULARY_IN_STATISTIC (VOCABULARY_ID, STATISTIC_ID)
			SELECT DISTINCT VOC_ID AS VOCABULARY_ID, (SELECT MAX(ID) FROM T_STATISTIC) AS STATISTIC_ID FROM V_ALL_VOCABULARY_ENTRIES 
			WHERE (CATEGORY = P_CATEGORY OR P_CATEGORY = -1) AND (UNIT = P_UNIT OR P_UNIT = ' ') AND USERS_ID = P_USER_ID;
		COMMIT;
	END; 
/		

------------------------------------trys to answer a vocabulary----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE TRY_ANSWER(P_ID_OF_VOCABULARY_IN_STATISTIC IN NUMBER, P_ANSWER IN VARCHAR2, P_USER_ID IN VARCHAR2)
	IS 
		V_CORRECT NUMBER;
		V_VOCABULARY_ID NUMBER;
		V_STATISTIC_ID NUMBER;
	BEGIN
		SELECT VOCABULARY_ID INTO  V_VOCABULARY_ID FROM T_VOCABULARY_IN_STATISTIC WHERE ID = P_ID_OF_VOCABULARY_IN_STATISTIC;
		SELECT STATISTIC_ID INTO  V_STATISTIC_ID FROM T_VOCABULARY_IN_STATISTIC WHERE ID = P_ID_OF_VOCABULARY_IN_STATISTIC;
	
		IF NOT_YET_TRIED(P_ID_OF_VOCABULARY_IN_STATISTIC) THEN
			IF CHECK_ANSWER(V_VOCABULARY_ID, P_ANSWER) THEN
				V_CORRECT := -1;
			ELSE
				V_CORRECT := 0;
			END IF;
		
				UPDATE T_VOCABULARY_IN_STATISTIC SET CORRECT = V_CORRECT WHERE ID = P_ID_OF_VOCABULARY_IN_STATISTIC;
				
				UPDATE T_STATISTIC SET TIMESTAMP_DONE = CURRENT_TIMESTAMP 
				WHERE 
					ID = V_STATISTIC_ID 
					AND NOT EXISTS(
											SELECT COUNT(*)
											FROM T_VOCABULARY_IN_STATISTIC 
											WHERE STATISTIC_ID = 1 
											GROUP BY CORRECT 
											HAVING CORRECT IS NULL);
				COMMIT;		
						
				REGISTER_PRACTICE(V_CORRECT, V_VOCABULARY_ID, P_USER_ID);
		END IF;
	END;
/


------------------------------------updates timestamp last practice----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE REGISTER_PRACTICE(P_CORRECT IN NUMBER, P_VOCABULARY_ID IN NUMBER, P_USER_ID IN NUMBER)
	IS 
	BEGIN
		MERGE INTO T_USER_VOCABULARY_PRACTICE DEST 
			USING (SELECT P_USER_ID AS USERS_ID, P_VOCABULARY_ID AS VOCABULARY_ID FROM DUAL) SRC
			ON (SRC.USERS_ID = DEST.USERS_ID AND SRC.VOCABULARY_ID = DEST.VOCABULARY_ID)
			WHEN MATCHED THEN
				UPDATE SET 
					TIMESTAMP_LAST_PRACTICE = CURRENT_TIMESTAMP,
					CATEGORY = CASE 
												WHEN(P_CORRECT = -1 AND CATEGORY < 5 AND COUNTER = 5) 
														THEN (CATEGORY+1)
												ELSE CATEGORY
												END,
					COUNTER = CASE 
												WHEN((P_CORRECT = 0 AND COUNTER = 0) OR (P_CORRECT = -1 AND COUNTER = 5)) 
														THEN 0
												ELSE (COUNTER+1)
												END
				WHERE USERS_ID = P_USER_ID AND VOCABULARY_ID = P_VOCABULARY_ID
			WHEN NOT MATCHED THEN
				INSERT (USERS_ID, VOCABULARY_ID, CATEGORY, COUNTER) 
				VALUES (P_USER_ID, P_VOCABULARY_ID, 0, CASE
																									WHEN (P_CORRECT = -1) THEN 1
																									ELSE 0
																									END);
		COMMIT;		
	END;
/

----------------------------------------------------------sends an email-------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEND_MAIL (P_TO_EMAIL IN VARCHAR2, P_SUBJECT IN VARCHAR2, P_MESSAGE IN  VARCHAR2)
  IS
     V_FROM      VARCHAR2(80) := 'vocabeltrainer@company.com';
     V_RECIPIENT VARCHAR2(80) := P_TO_EMAIL;
     V_SUBJECT   VARCHAR2(80) := P_SUBJECT;
      V_MAIL_HOST VARCHAR2(30) := 'mail.company.de';
      V_MAIL_CONN UTL_SMTP.CONNECTION;
      CRLF        VARCHAR2(2)  := chr(13)||chr(10);
  BEGIN
     V_MAIL_CONN := UTL_SMTP.OPEN_CONNECTION(V_MAIL_HOST, 25);
     UTL_SMTP.HELO(V_MAIL_CONN, V_MAIL_HOST);
     UTL_SMTP.MAIL(V_MAIL_CONN, V_FROM);
     UTL_SMTP.RCPT(V_MAIL_CONN, V_RECIPIENT);
     UTL_SMTP.DATA(V_MAIL_CONN,
       'Date: '   || TO_CHAR(SYSDATE, 'Dy, DD Mon YYYY hh24:mi:ss') || CRLF ||
       'From: '   || V_FROM || CRLF ||
       'Subject: '|| V_SUBJECT || CRLF ||
       'To: '     || V_RECIPIENT || CRLF ||
	   P_MESSAGE
     );
     UTL_SMTP.QUIT(V_MAIL_CONN);
  END;
/


CREATE OR REPLACE PROCEDURE SEND_MAILS
IS
	V_USER_EMAIL VARCHAR2(256);
	V_FIRSTNAME VARCHAR2(256);
	V_LASTNAME VARCHAR2(256);
	V_VOCABULARY_ID NUMBER;
	V_UNIT_NAME VARCHAR2(256);
    CRLF VARCHAR2(2)  := CHR(13) || CHR(10);
	V_MESSAGE VARCHAR2(4096) := '';	
BEGIN
	
			FOR	I IN (SELECT DISTINCT  USERS_ID FROM V_ALL_LEARNING_TAGS)
			LOOP
				
				V_MESSAGE := 'begin' || CRLF;
				SELECT FIRST_NAME INTO V_FIRSTNAME FROM T_USERS WHERE ID = I.USERS_ID;
				SELECT LAST_NAME INTO V_LASTNAME FROM T_USERS  WHERE ID = I.USERS_ID;
				SELECT EMAIL INTO V_USER_EMAIL FROM T_USERS WHERE ID = I.USERS_ID;
				
				FOR J IN (SELECT VOC_IN_STAT_ID FROM V_ALL_VOCABULARY_TO_LEARN WHERE USERS_ID = I.USERS_ID)
				LOOP
					SELECT VOCABULARY_ID INTO V_VOCABULARY_ID FROM T_VOCABULARY_IN_STATISTIC WHERE ID = J.VOC_IN_STAT_ID;
					SELECT  U.NAME INTO V_UNIT_NAME FROM T_UNIT U INNER JOIN T_VOCABULARY V ON  U.ID = V.UNIT_ID WHERE V.ID = V_VOCABULARY_ID;
					V_MESSAGE := V_MESSAGE || '/*' || V_UNIT_NAME || ': ' ||GET_VOCABULARY_BY_ID(V_VOCABULARY_ID) || '=> ' || '*/TRY_ANSWER(' || TO_CHAR(J.VOC_IN_STAT_ID) ||', '''', '|| I.USERS_ID ||');' || CRLF;
				END LOOP;
				V_MESSAGE := V_MESSAGE || 'end;';
				
				SEND_MAIL(V_USER_EMAIL, GET_RESSOURCE('voc_subject'),  GET_RESSOURCE('voc_hello') || V_FIRSTNAME || ' ' || V_LASTNAME || GET_RESSOURCE('voc_whoiam') || CRLF || GET_RESSOURCE('voc_whatiwant') || CRLF || GET_RESSOURCE('voc_lastword') || CRLF || CRLF || V_MESSAGE);
			END LOOP;
END;
/

-----------------------------------------------------WILL CREATE A STATISTIC FOR ANY VOCABULARY THAT IS NEEDED TO LEARN------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CREATE_UNLEARNED_VOCABULARY_STATISTICS
IS 
		V_STATISTIC_ID NUMBER;
		V_COUNT_ALREADY_TAKEN_VOCABULARY NUMBER;
BEGIN
	FOR I IN 
	(
		SELECT DISTINCT B.USERS_ID  AS ID
			FROM (SELECT A.ID AS STATISTIC_ID, A.USERS_ID, B.VOCABULARY_ID FROM T_STATISTIC A INNER JOIN T_VOCABULARY_IN_STATISTIC B ON A.ID = B.STATISTIC_ID WHERE CORRECT IS NULL) A
				RIGHT JOIN V_ALL_VOCABULARY_PRACTICES B ON A.USERS_ID = B.USERS_ID AND A.VOCABULARY_ID = B.VOCABULARY_ID
			WHERE STATISTIC_ID IS NULL AND HOURS_NEEDED < 1
	)
	LOOP
		INSERT INTO T_STATISTIC (USERS_ID) VALUES (I.ID);
		SELECT MAX(ID) INTO V_STATISTIC_ID FROM T_STATISTIC;			
		COMMIT;
		FOR J IN 
		(
		SELECT DISTINCT B.VOCABULARY_ID AS ID
		FROM (SELECT A.ID AS STATISTIC_ID, A.USERS_ID, B.VOCABULARY_ID FROM T_STATISTIC A INNER JOIN T_VOCABULARY_IN_STATISTIC B ON A.ID = B.STATISTIC_ID WHERE CORRECT IS NULL) A
			RIGHT JOIN V_ALL_VOCABULARY_PRACTICES B ON A.USERS_ID = B.USERS_ID AND A.VOCABULARY_ID = B.VOCABULARY_ID
		WHERE STATISTIC_ID IS NULL AND HOURS_NEEDED < 1		
		)
		LOOP
			INSERT INTO T_VOCABULARY_IN_STATISTIC (STATISTIC_ID, VOCABULARY_ID) VALUES (V_STATISTIC_ID, J.ID);
			COMMIT;		
		END LOOP;
	END LOOP;
END;
/

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------create jobs--------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BEGIN 
    DBMS_SCHEDULER.DROP_JOB ('J_SEND_MAILS_TO_USERS');
   	dbms_scheduler.create_job ( 
    		job_name => 'J_SEND_MAILS_TO_USERS', 
    		job_type => 'PLSQL_BLOCK', 
    		job_action => 'CREATE_UNLEARNED_VOCABULARY_STATISTICS;SEND_MAILS;', 				
    		enabled => true, 
    		repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYDAY=MON,TUE,WED,THU,FRI'
   ); 
END;
/


BEGIN 
    DBMS_SCHEDULER.DROP_JOB ('J_CREATE_UNLEARNED_VOCABULARY_STATISTICS');
   	dbms_scheduler.create_job ( 
    		job_name => 'J_CREATE_UNLEARNED_VOCABULARY_STATISTICS', 
    		job_type => 'PLSQL_BLOCK', 
    		job_action => 'CREATE_UNLEARNED_VOCABULARY_STATISTICS;', 
    		enabled => true, 
    		repeat_interval => 'FREQ=HOURLY;INTERVAL=1'
   ); 
END;
/

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------default data insert--------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO T_ALL_RESSOURCES (RES_KEY, RES) VALUES ('voc_hello', 'Hallo ');
INSERT INTO T_ALL_RESSOURCES (RES_KEY, RES) VALUES ('voc_whoiam', '. Ich bin dein persoenlicher Vocabeltrainer :). ');
INSERT INTO T_ALL_RESSOURCES (RES_KEY, RES) VALUES ('voc_whatiwant', 'Du hast schon lange keine Vocabeln mehr gelernt. Deswegen solltest du das jetzt unbedingt tun.');
INSERT INTO T_ALL_RESSOURCES (RES_KEY, RES) VALUES ('voc_lastword', 'Wollte ich nur einmal gesagt haben. Danke. Und viel Spass beim Lernen ;).');
INSERT INTO T_ALL_RESSOURCES (RES_KEY, RES) VALUES ('voc_subject', 'Lerne mal Vocabeln---');
INSERT INTO T_STATISTIC_TIME (CATEGORY, HOURS) VALUES (0, 1);
INSERT INTO T_STATISTIC_TIME (CATEGORY, HOURS) VALUES (1, 2);
INSERT INTO T_STATISTIC_TIME (CATEGORY, HOURS) VALUES (2, 8);
INSERT INTO T_STATISTIC_TIME (CATEGORY, HOURS) VALUES (3, 20);
INSERT INTO T_STATISTIC_TIME (CATEGORY, HOURS) VALUES (4, 40);
INSERT INTO T_STATISTIC_TIME (CATEGORY, HOURS) VALUES (5, 60);
COMMIT;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Testscript ausführen---------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--select * from all_vocabulary_entries where voc_id in (select voc_id from all_vocabulary_entries where translation in (select translation from all_vocabulary_entries where voc_id = 1))

--to learn:
--cube
--rollup

BEGIN
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'setzen, stellen, legen', 'EN', 'to put', 'Unit 1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to put', 'DE', 'setzen', 'Unit 1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to put', 'DE', 'stellen', 'Unit 1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to put', 'DE', 'legen', 'Unit 1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'setzen', 'EN', 'to set', 'Unit 1');
		
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to career', 'Unit 1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to run', 'Unit 1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to race', 'Unit 1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'to run, to race, to career', 'EN', 'rennen', 'Unit 1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'sitzen', 'EN', 'to sit', 'Unit 1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'stehen', 'EN', 'to stand', 'Unit 1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'gehen', 'EN', 'to walk', 'Unit 1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'average', 'DE', 'durchschnitt', 'Unit 1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to count', 'DE', 'zaehlen', 'Unit 1');
	

	--SELECT 'begin' || chr(13) || chr(10) || 'TRY_ANSWER(' || listagg(voc_in_stat_id, ', '''', 1);' || chr(13) || chr(10) || 'TRY_ANSWER(') within group (order by voc_in_stat_id) over (partition by mail) || ', '''', 1);' || chr(13) || chr(10) || 'end;' as test from v_all_vocabulary_to_learn 

	--will be inserted
	INSERT_NEW_USER('Simon','Klein','simon.klein@company.de');
	INSERT_NEW_USER('Simon','Klein','simon.klein@company2.de');
	
	
	CREATE_NEW_STATISTIC(-1, ' ', 1);
	CREATE_NEW_STATISTIC(-1, ' ', 2);
	
END;
/


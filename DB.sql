------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------Deleting previous generated Tables----------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--view Errors: select * from SYS.USER_ERRORS where type = 'PROCEDURE' or type = 'FUNCTION'
--View specific errors: select * from SYS.USER_ERRORS where (type = 'PROCEDURE' or type = 'FUNCTION') and name LIKE 'INSERT_NEW_TRANSLATION_IF_NOT_EXISTS' 

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
	SELECT TV.ID AS VOC_IN_STAT_ID, S.USERS_ID AS USERS_ID, U.EMAIL AS MAIL 
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

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare Check Functions----------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


--------------------Checks if a language already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION LANGUAGE_EXISTS(P_LANGUAGE IN VARCHAR2)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_LANGUAGE NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_LANGUAGE FROM T_LANGUAGE WHERE NAME = P_LANGUAGE;
		RETURN V_NUMBER_OF_ROWS_WITH_LANGUAGE > 0;
	END;
/

--------------------Checks if a vocabulary already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION VOCABULARY_EXISTS(P_VOCABULARY IN VARCHAR2, P_TRANSLATION IN VARCHAR2, P_UNIT_ID IN NUMBER)
	RETURN BOOLEAN
	IS 
		V_NUMBER_OF_ROWS_WITH_VOCABULARY NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_VOCABULARY FROM T_VOCABULARY WHERE VOCABULARY = P_VOCABULARY AND UNIT_ID = P_UNIT_ID;
		RETURN V_NUMBER_OF_ROWS_WITH_VOCABULARY > 0;
	END;
/

--------------------Checks if a unit already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION UNIT_EXISTS(P_UNIT IN VARCHAR2)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_UNIT NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_UNIT FROM T_UNIT WHERE NAME = P_UNIT;
		RETURN V_NUMBER_OF_ROWS_WITH_UNIT > 0;
	END;
/

--------------------CHECKS IF THE SAME TRANSLATION FOR A VOCABULARY ALREADY EXISTS. RETURNS TRUE IF EXISTS------------------------
CREATE OR REPLACE FUNCTION TRANSLATION_EXISTS(P_TRANSLATION IN VARCHAR2, P_VOCABULARY IN VARCHAR2, P_UNIT_ID IN NUMBER)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_TRANSLATION NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_TRANSLATION FROM V_ALL_VOCABULARY_ENTRIES WHERE UNIT_ID = P_UNIT_ID AND TRANSLATION = P_TRANSLATION;
		RETURN V_NUMBER_OF_ROWS_WITH_TRANSLATION > 0;
	END;
/

--------------------Checks if a user with the same email already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION USER_EXISTS(P_EMAIL IN VARCHAR2)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_USER NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_USER FROM T_USERS WHERE EMAIL = P_EMAIL;
		RETURN V_NUMBER_OF_ROWS_WITH_USER > 0;
	END;
/

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

--------------------------------------------checks if the question was not answered before---------------------------------------------------
CREATE OR REPLACE FUNCTION STATISTIC_IS_FULL(P_STATISTIC_ID IN NUMBER)
	RETURN BOOLEAN
	IS	
		V_NUMBER_OF_NOT_FULL_STATISTICS NUMBER;
	BEGIN
			SELECT COUNT(*) INTO V_NUMBER_OF_NOT_FULL_STATISTICS FROM T_VOCABULARY_IN_STATISTIC  WHERE CORRECT IS NULL AND STATISTIC_ID = P_STATISTIC_ID;
			RETURN V_NUMBER_OF_NOT_FULL_STATISTICS = 0;
	END;
/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare  Getter Functions--------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------returns the id of a vocabulary with the given name------------------------
CREATE OR REPLACE FUNCTION GET_ID_OF_VOCABULARY(P_VOCABULARY IN VARCHAR2)
	RETURN NUMBER
	IS V_ID_OF_VOCABULARY NUMBER;
	BEGIN
		SELECT ID INTO V_ID_OF_VOCABULARY FROM T_VOCABULARY WHERE VOCABULARY = P_VOCABULARY;
		RETURN V_ID_OF_VOCABULARY;
	END;
/

--------------------returns the id of a unit with the given name-----------------------------
CREATE OR REPLACE FUNCTION GET_ID_OF_UNIT(P_UNIT IN VARCHAR2)
	RETURN NUMBER
	IS V_ID_OF_UNIT NUMBER;
	BEGIN
		SELECT ID INTO V_ID_OF_UNIT FROM T_UNIT WHERE NAME = P_UNIT;
		RETURN V_ID_OF_UNIT;
	END;
/

--------------------returns the id of a language with the given name-----------------------------
CREATE OR REPLACE FUNCTION GET_ID_OF_LANGUAGE(P_LANGUAGE IN VARCHAR2)
	RETURN NUMBER
	IS V_ID_OF_LANGUAGE NUMBER;
	BEGIN
		SELECT ID INTO V_ID_OF_LANGUAGE FROM T_LANGUAGE WHERE NAME = P_LANGUAGE;
		RETURN V_ID_OF_LANGUAGE;
	END;
/

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

------------------------returns the category id-------------------------------
CREATE OR REPLACE FUNCTION GET_CATEGORY_ID(P_VOCABULARY_ID IN NUMBER, P_USERS_ID IN NUMBER)
	RETURN NUMBER
	IS V_CATEGORY_ID VARCHAR2(256);
	BEGIN
		SELECT CATEGORY INTO V_CATEGORY_ID FROM T_USER_VOCABULARY_PRACTICE WHERE VOCABULARY_ID = P_VOCABULARY_ID AND USERS_ID = P_USERS_ID;
		RETURN V_CATEGORY_ID;
	END;
/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare Procedures - "private" procedures---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------inserts a new unit into the unit table if not exists------------------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_UNIT_IF_NOT_EXISTS (P_UNIT IN VARCHAR2)
	IS
	BEGIN
		IF NOT UNIT_EXISTS(P_UNIT) THEN
			INSERT INTO T_UNIT (NAME) VALUES (P_UNIT);
			COMMIT;
		END IF;
	END; 
/	

-------------inserts a new language if the given language not exists--------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_LANGUAGE_IF_NOT_EXISTS (P_LANGUAGE IN VARCHAR2)
	IS
	BEGIN
		IF NOT LANGUAGE_EXISTS(P_LANGUAGE) THEN
			INSERT INTO T_LANGUAGE (NAME) VALUES (P_LANGUAGE);
			COMMIT;
		END IF;
	END; 
/	


-------------inserts a new vocabulary into the vocabulary table if not exists------------------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_VOCABULARY_IF_NOT_EXISTS (P_VOCABULARY IN VARCHAR2, P_TRANSLATION IN VARCHAR2, P_LANGUAGE IN VARCHAR2, P_UNIT_ID IN NUMBER)
	IS 
		V_ID_OF_LANGUAGE NUMBER;
		V_VOCABULARY_ID NUMBER;
	BEGIN
		V_ID_OF_LANGUAGE := GET_ID_OF_LANGUAGE(P_LANGUAGE);
		IF NOT VOCABULARY_EXISTS(P_VOCABULARY, P_TRANSLATION, P_UNIT_ID) THEN
			INSERT INTO T_VOCABULARY (VOCABULARY, UNIT_ID, LANGUAGE_ID) VALUES (P_VOCABULARY, P_UNIT_ID, V_ID_OF_LANGUAGE);
			SELECT MAX(ID) INTO V_VOCABULARY_ID FROM T_VOCABULARY;
			COMMIT;
		END IF;
	END; 
/	

-------------inserts a new translation if the given translation not exists--------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_TRANSLATION_IF_NOT_EXISTS (P_TRANSLATION IN VARCHAR2, P_VOCABULARY IN VARCHAR2, P_LANGUAGE_TO_TRANSLATE_TO IN VARCHAR2, P_UNIT IN VARCHAR2)
	IS 
		V_ID_OF_VOCABULARY NUMBER;
		V_ID_OF_LANGUAGE NUMBER;
	BEGIN
		IF NOT TRANSLATION_EXISTS(P_TRANSLATION, P_VOCABULARY, GET_ID_OF_UNIT(P_UNIT)) THEN
			V_ID_OF_VOCABULARY := GET_ID_OF_VOCABULARY(P_VOCABULARY);
			V_ID_OF_LANGUAGE := GET_ID_OF_LANGUAGE(P_LANGUAGE_TO_TRANSLATE_TO);
			INSERT INTO T_TRANSLATION (TRANSLATION, LANGUAGE_ID, VOCABULARY_ID) VALUES (P_TRANSLATION, V_ID_OF_LANGUAGE, V_ID_OF_VOCABULARY);
			COMMIT;
		END IF;
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
		    INSERT_NEW_LANGUAGE_IF_NOT_EXISTS(P_LANGUAGE_DEFAULT);
			INSERT_NEW_LANGUAGE_IF_NOT_EXISTS(P_LANGUAGE_TRANSLATE);
			INSERT_NEW_UNIT_IF_NOT_EXISTS(P_UNIT_NAME);
			INSERT_NEW_VOCABULARY_IF_NOT_EXISTS(P_WORD_LANGUAGE_DEFAULT,  P_WORD_LANGUAGE_TRANSLATE, P_LANGUAGE_DEFAULT, GET_ID_OF_UNIT(P_UNIT_NAME));
			INSERT_NEW_TRANSLATION_IF_NOT_EXISTS(P_WORD_LANGUAGE_TRANSLATE, P_WORD_LANGUAGE_DEFAULT, P_LANGUAGE_TRANSLATE, P_UNIT_NAME);
	END; 
/	

--------------------------------------------------inserts a new user if there is no user with this email---------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_USER (P_FIRST_NAME IN VARCHAR2, P_LAST_NAME IN VARCHAR2, P_EMAIL IN VARCHAR2)
	IS
	BEGIN
		IF NOT USER_EXISTS(P_EMAIL) THEN
			INSERT INTO T_USERS (FIRST_NAME, LAST_NAME, EMAIL) VALUES (P_FIRST_NAME, P_LAST_NAME, P_EMAIL);
			COMMIT;
		END IF;
	END; 
/		


--------------------------------------------------creates a new statistic for a user---------------------------------------------------------------------------------------------
------------------------P_CATEGORY = -1 for any category--------------------------------------------------------------------------------------------------------------------
------------------------P_UNIT = ' ' for any unit-----------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE CREATE_NEW_STATISTIC (P_CATEGORY IN NUMBER, P_UNIT IN VARCHAR2, P_USER_ID IN NUMBER)
	IS 
		V_STATISTIC_ID NUMBER;
	BEGIN	
		--create the statistic itself
		INSERT INTO T_STATISTIC (USERS_ID) VALUES (P_USER_ID);
		COMMIT;
		
		--load variables
		SELECT ID INTO V_STATISTIC_ID FROM T_STATISTIC WHERE ROWID=(SELECT MAX(ROWID) FROM T_STATISTIC);

		--insert values into link table
		FOR	I IN (SELECT DISTINCT VOC_ID AS ID FROM V_ALL_VOCABULARY_ENTRIES WHERE (CATEGORY = P_CATEGORY OR P_CATEGORY = -1) AND (UNIT = P_UNIT OR P_UNIT = ' ') AND USERS_ID = P_USER_ID)
		LOOP
			INSERT INTO T_VOCABULARY_IN_STATISTIC (STATISTIC_ID, VOCABULARY_ID) VALUES (V_STATISTIC_ID, I.ID);		
			COMMIT;
		END LOOP;
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
		SELECT DISTINCT STATISTIC_ID INTO  V_STATISTIC_ID FROM T_VOCABULARY_IN_STATISTIC WHERE ID = P_ID_OF_VOCABULARY_IN_STATISTIC;
	
		IF NOT_YET_TRIED(P_ID_OF_VOCABULARY_IN_STATISTIC) THEN
			IF CHECK_ANSWER(V_VOCABULARY_ID, P_ANSWER) THEN
				V_CORRECT := -1;
			ELSE
				V_CORRECT := 0;
			END IF;
		
				UPDATE T_VOCABULARY_IN_STATISTIC SET CORRECT = V_CORRECT WHERE ID = P_ID_OF_VOCABULARY_IN_STATISTIC;
						
				REGISTER_PRACTICE(V_CORRECT = -1, V_VOCABULARY_ID, P_USER_ID);
				IF STATISTIC_IS_FULL(V_STATISTIC_ID) THEN
					UPDATE T_STATISTIC SET TIMESTAMP_DONE = CURRENT_TIMESTAMP WHERE ID = V_STATISTIC_ID;
				END IF;
				COMMIT;
		END IF;
	END;
/


------------------------------------updates timestamp last practice----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE REGISTER_PRACTICE(P_CORRECT IN BOOLEAN, P_VOCABULARY_ID IN NUMBER, P_USER_ID IN NUMBER)
	IS 
		V_CATEGORY NUMBER;
		V_COUNTER NUMBER;
	BEGIN
		MERGE INTO T_USER_VOCABULARY_PRACTICE DEST 
			USING (SELECT P_USER_ID AS USERS_ID, P_VOCABULARY_ID AS VOCABULARY_ID FROM DUAL) SRC
			ON (SRC.USERS_ID = DEST.USERS_ID AND SRC.VOCABULARY_ID = DEST.VOCABULARY_ID)
			WHEN MATCHED THEN
				UPDATE SET TIMESTAMP_LAST_PRACTICE = CURRENT_TIMESTAMP
				WHERE USERS_ID = P_USER_ID AND VOCABULARY_ID = P_VOCABULARY_ID
			WHEN NOT MATCHED THEN
				INSERT (USERS_ID, VOCABULARY_ID, CATEGORY, COUNTER) 
				VALUES (P_USER_ID, P_VOCABULARY_ID, 0, 0);	
		COMMIT;		
		
		SELECT CATEGORY INTO V_CATEGORY FROM T_USER_VOCABULARY_PRACTICE WHERE VOCABULARY_ID = P_VOCABULARY_ID AND USERS_ID = P_USER_ID;
		SELECT COUNTER INTO V_COUNTER FROM T_USER_VOCABULARY_PRACTICE WHERE VOCABULARY_ID = P_VOCABULARY_ID AND USERS_ID = P_USER_ID;
		
		IF P_CORRECT THEN
			V_COUNTER := V_COUNTER+1;
			IF V_COUNTER > 5 THEN
				V_COUNTER := 0;
				V_CATEGORY := V_CATEGORY + 1;
				IF V_CATEGORY > 5 THEN
					V_CATEGORY := 5;
				END IF;
			END IF;
		ELSE
			V_COUNTER := V_COUNTER - 1;
			IF V_COUNTER < 0 THEN
				V_COUNTER := 0;
			END IF;
		END IF;
		
		UPDATE T_USER_VOCABULARY_PRACTICE SET CATEGORY = V_CATEGORY, COUNTER = V_COUNTER WHERE VOCABULARY_ID = P_VOCABULARY_ID AND USERS_ID = P_USER_ID;
		COMMIT;
	END;
/

----------------------------------------------------------sends an email-------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SEND_MAIL (P_TO_EMAIL IN VARCHAR2, P_SUBJECT IN VARCHAR2, P_MESSAGE IN  VARCHAR2)
  IS
     V_FROM      VARCHAR2(80) := 'vocabeltrainer@company.com';
     V_RECIPIENT VARCHAR2(80) := P_TO_EMAIL;
     V_SUBJECT   VARCHAR2(80) := P_SUBJECT;
      V_MAIL_HOST VARCHAR2(30) := 'mail.company.com';
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
	V_A VARCHAR2(256) := GET_RESSOURCE('voc_hello');
	V_B VARCHAR2(256) := GET_RESSOURCE('voc_whoiam');
	V_C VARCHAR2(256) := GET_RESSOURCE('voc_whatiwant');
	V_D VARCHAR2(256) := GET_RESSOURCE('voc_lastword');
    CRLF VARCHAR2(2)  := CHR(13) || CHR(10);
	V_MESSAGE VARCHAR2(4096) := '';	
BEGIN
	
			FOR	I IN (SELECT DISTINCT  USERS_ID FROM V_ALL_VOCABULARY_TO_LEARN)
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
				SEND_MAIL(V_USER_EMAIL, 'Lerne mal Vocabeln...',  V_A || V_FIRSTNAME || ' ' || V_LASTNAME || V_B || CRLF || V_C || CRLF || V_D || CRLF || CRLF || V_MESSAGE);
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
    		repeat_interval => 'FREQ=DAILY;BYHOUR=6'
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
	

	

	--will be inserted
	INSERT_NEW_USER('Simon','Klein','simon@company.de');
	
END;
/


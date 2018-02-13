------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------Deleting previous generated Tables----------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--view Errors: select * from SYS.USER_ERRORS where type = 'PROCEDURE' or type = 'FUNCTION'
--View specific errors: select * from SYS.USER_ERRORS where (type = 'PROCEDURE' or type = 'FUNCTION') and name LIKE 'INSERT_NEW_TRANSLATION_IF_NOT_EXISTS' 

DROP TABLE VOCABULARY_IN_STATISTIC;
DROP TABLE TRANSLATION;
DROP TABLE VOCABULARY;
DROP TABLE STATISTIC;
DROP TABLE LANGUAGE;
DROP TABLE UNIT;
DROP TABLE USERS;
DROP TABLE DEBUG;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------Creating the Tables--------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE USERS(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	EMAIL VARCHAR2(40) NOT NULL,
	FIRST_NAME VARCHAR(16) NOT NULL,
	LAST_NAME VARCHAR(16) NOT NULL,
	CONSTRAINT USERS_PK PRIMARY KEY (ID)
);

CREATE TABLE UNIT(
	ID NUMBER  GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	NAME VARCHAR(16) NOT NULL,
	CONSTRAINT UNIT_PK PRIMARY KEY(ID)
);

CREATE TABLE LANGUAGE (
	ID NUMBER  GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	NAME VARCHAR(5) NOT NULL,
	CONSTRAINT LANGUAGE_PK PRIMARY KEY (ID)
);

CREATE TABLE STATISTIC(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	USERS_ID NUMBER NOT NULL,
    TIMESTAMP_DONE TIMESTAMP(6),
	CONSTRAINT STATISTIC_PK PRIMARY KEY(ID),
	CONSTRAINT USER_FK FOREIGN KEY (USERS_ID) REFERENCES USERS(ID)
);

CREATE TABLE VOCABULARY(
 	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	UNIT_ID NUMBER NOT NULL,
	LANGUAGE_ID NUMBER NOT NULL,
	VOCABULARY VARCHAR(32) NOT NULL,
	CATEGORY NUMBER NOT NULL,
	COUNTER NUMBER NOT NULL,
	TIMESTAMP_LAST_PRACTICE TIMESTAMP(6),
	CONSTRAINT VOCABULARY_PK PRIMARY KEY(ID),
	CONSTRAINT UNIT_FK FOREIGN KEY (UNIT_ID) REFERENCES UNIT(ID),
	CONSTRAINT LANGUAGE_VOC_FK FOREIGN KEY (LANGUAGE_ID) REFERENCES LANGUAGE(ID)
);

CREATE TABLE TRANSLATION(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	VOCABULARY_ID NUMBER NOT NULL,
	LANGUAGE_ID NUMBER NOT NULL,
	TRANSLATION VARCHAR(32) NOT NULL,
	CONSTRAINT TRANSLATION_PK PRIMARY KEY (ID),
	CONSTRAINT VOCABULARY_FK FOREIGN KEY (VOCABULARY_ID) REFERENCES VOCABULARY(ID),
	CONSTRAINT LANGUAGE_FK FOREIGN KEY (LANGUAGE_ID) REFERENCES LANGUAGE(ID)	
);

CREATE TABLE VOCABULARY_IN_STATISTIC(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	CORRECT NUMBER DEFAULT NULL,
	STATISTIC_ID NUMBER NOT NULL,
	VOCABULARY_ID NUMBER NOT NULL,
	CONSTRAINT VOCABULARY_IN_STATISTIC_PK PRIMARY KEY (ID),
	CONSTRAINT STATISTIC_VOC_FK FOREIGN KEY (STATISTIC_ID) REFERENCES STATISTIC(ID),	
	CONSTRAINT VOCABULARY_STAT_FK FOREIGN KEY (VOCABULARY_ID) REFERENCES VOCABULARY(ID)
);

CREATE TABLE DEBUG(
	ID NUMBER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
	MESSAGE VARCHAR(128), 
	MESSAGE_NUM NUMBER,
	CONSTRAINT DEBUG_PK PRIMARY KEY (ID)
);
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Create Views-------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FORCE VIEW ALL_VOCABULARY_ENTRIES AS
	SELECT U.ID AS UNIT_ID, U.NAME AS UNIT, V.CATEGORY, V.ID AS VOC_ID, V.VOCABULARY, V.LANGUAGE_ID AS VOC_LANG_ID, VL.NAME AS VOC_LANG, T.ID AS TRA_ID, T.TRANSLATION, T.LANGUAGE_ID AS TRA_LANG_ID, LL.NAME AS TRA_LANG
	FROM  VOCABULARY V
		INNER JOIN TRANSLATION T ON V.ID = T.VOCABULARY_ID 
		INNER JOIN UNIT U ON V.UNIT_ID = U.ID
		INNER JOIN LANGUAGE VL ON VL.ID = V.LANGUAGE_ID 
		INNER JOIN LANGUAGE LL ON LL.ID = T.LANGUAGE_ID;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Declare Check Functions----------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


--------------------Checks if a language already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION LANGUAGE_EXISTS(P_LANGUAGE IN VARCHAR2)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_LANGUAGE NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_LANGUAGE FROM LANGUAGE WHERE NAME = P_LANGUAGE;
		RETURN V_NUMBER_OF_ROWS_WITH_LANGUAGE > 0;
	END;
/

--------------------Checks if a vocabulary already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION VOCABULARY_EXISTS(P_VOCABULARY IN VARCHAR2, P_UNIT_ID IN NUMBER)
	RETURN BOOLEAN
	IS 
		V_NUMBER_OF_ROWS_WITH_VOCABULARY NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_VOCABULARY FROM VOCABULARY WHERE VOCABULARY = P_VOCABULARY AND UNIT_ID = P_UNIT_ID;
		RETURN V_NUMBER_OF_ROWS_WITH_VOCABULARY > 0;
	END;
/

--------------------Checks if a unit already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION UNIT_EXISTS(P_UNIT IN VARCHAR2)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_UNIT NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_UNIT FROM UNIT WHERE NAME = P_UNIT;
		RETURN V_NUMBER_OF_ROWS_WITH_UNIT > 0;
	END;
/

--------------------Checks if the same translation for a vocabulary already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION TRANSLATION_EXISTS(P_TRANSLATION IN VARCHAR2, P_VOCABULARY IN VARCHAR2, P_UNIT_ID IN NUMBER)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_TRANSLATION NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_TRANSLATION FROM ALL_VOCABULARY_ENTRIES WHERE UNIT_ID = P_UNIT_ID AND ((VOCABULARY = P_VOCABULARY AND TRANSLATION = P_TRANSLATION) OR (VOCABULARY = P_TRANSLATION AND TRANSLATION = P_VOCABULARY));
		RETURN V_NUMBER_OF_ROWS_WITH_TRANSLATION > 0;
	END;
/

--------------------Checks if a user with the same email already exists. returns true if exists------------------------
CREATE OR REPLACE FUNCTION USER_EXISTS(P_EMAIL IN VARCHAR2)
	RETURN BOOLEAN
	IS V_NUMBER_OF_ROWS_WITH_USER NUMBER;
	BEGIN
		SELECT COUNT(*) INTO V_NUMBER_OF_ROWS_WITH_USER FROM USERS WHERE EMAIL = P_EMAIL;
		RETURN V_NUMBER_OF_ROWS_WITH_USER > 0;
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
		SELECT ID INTO V_ID_OF_VOCABULARY FROM VOCABULARY WHERE VOCABULARY = P_VOCABULARY;
		RETURN V_ID_OF_VOCABULARY;
	END;
/

--------------------returns the id of a unit with the given name-----------------------------
CREATE OR REPLACE FUNCTION GET_ID_OF_UNIT(P_UNIT IN VARCHAR2)
	RETURN NUMBER
	IS V_ID_OF_UNIT NUMBER;
	BEGIN
		SELECT ID INTO V_ID_OF_UNIT FROM UNIT WHERE NAME = P_UNIT;
		RETURN V_ID_OF_UNIT;
	END;
/

--------------------returns the id of a language with the given name-----------------------------
CREATE OR REPLACE FUNCTION GET_ID_OF_LANGUAGE(P_LANGUAGE IN VARCHAR2)
	RETURN NUMBER
	IS V_ID_OF_LANGUAGE NUMBER;
	BEGIN
		SELECT ID INTO V_ID_OF_LANGUAGE FROM LANGUAGE WHERE NAME = P_LANGUAGE;
		RETURN V_ID_OF_LANGUAGE;
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
			INSERT INTO UNIT (NAME) VALUES (P_UNIT);
			COMMIT;
		END IF;
	END; 
/	

-------------inserts a new language if the given language not exists--------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_LANGUAGE_IF_NOT_EXISTS (P_LANGUAGE IN VARCHAR2)
	IS
	BEGIN
		IF NOT LANGUAGE_EXISTS(P_LANGUAGE) THEN
			INSERT INTO LANGUAGE (NAME) VALUES (P_LANGUAGE);
			COMMIT;
		END IF;
	END; 
/	


-------------inserts a new vocabulary into the vocabulary table if not exists------------------------
CREATE OR REPLACE PROCEDURE INSERT_NEW_VOCABULARY_IF_NOT_EXISTS (P_VOCABULARY IN VARCHAR2, P_TRANSLATION IN VARCHAR2, P_LANGUAGE IN VARCHAR2, P_UNIT_ID IN NUMBER)
	IS V_ID_OF_LANGUAGE NUMBER;
	BEGIN
		V_ID_OF_LANGUAGE := GET_ID_OF_LANGUAGE(P_LANGUAGE);
		IF NOT VOCABULARY_EXISTS(P_VOCABULARY, P_UNIT_ID) AND NOT TRANSLATION_EXISTS(P_TRANSLATION, P_VOCABULARY, P_UNIT_ID) THEN
			INSERT INTO VOCABULARY (VOCABULARY, CATEGORY, COUNTER, UNIT_ID, LANGUAGE_ID) VALUES (P_VOCABULARY, 0, 0, P_UNIT_ID, V_ID_OF_LANGUAGE);
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
			INSERT INTO TRANSLATION (TRANSLATION, LANGUAGE_ID, VOCABULARY_ID) VALUES (P_TRANSLATION, V_ID_OF_LANGUAGE, V_ID_OF_VOCABULARY);
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
			INSERT INTO USERS (FIRST_NAME, LAST_NAME, EMAIL) VALUES (P_FIRST_NAME, P_LAST_NAME, P_EMAIL);
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
		INSERT INTO STATISTIC (USERS_ID) VALUES (P_USER_ID);
		COMMIT;
		
		--load variables
		SELECT ID INTO V_STATISTIC_ID FROM STATISTIC WHERE ROWID=(SELECT MAX(ROWID) FROM STATISTIC);

		--insert values into link table
		FOR	I IN (SELECT DISTINCT MIN(VOC_ID) OVER (PARTITION BY TRANSLATION) AS ID FROM ALL_VOCABULARY_ENTRIES WHERE (CATEGORY = P_CATEGORY OR P_CATEGORY = -1) AND (UNIT = P_UNIT OR P_UNIT = ' '))
		LOOP
			INSERT INTO VOCABULARY_IN_STATISTIC (STATISTIC_ID, VOCABULARY_ID) VALUES (V_STATISTIC_ID, I.ID);		
			COMMIT;
		END LOOP;

	END; 
/		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------Testscript ausführen---------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--select listagg(vocabulary, ', ') within group (order by vocabulary desc), translation from all_vocabulary_entries group by translation
--select distinct min(voc_id) over (partition by translation) from all_vocabulary_entries


--test
--select distinct listagg(vocabulary, ', ') within group (order by vocabulary desc) from all_vocabulary_entries group by translation
--select distinct listagg(translation, ', ') within group (order by translation desc) from all_vocabulary_entries group by vocabulary


--select a.tra, b.voc from
--(select distinct listagg(translation, ', ') within group (order by translation desc) as tra, vocabulary from all_vocabulary_entries group by vocabulary) a,
--(select distinct listagg(vocabulary, ', ') within group (order by vocabulary desc) as voc, translation from all_vocabulary_entries group by translation) b
--where a.vocabulary = b.voc and a.tra = b.translation



--test ende

--cube
--rollup
--over partition by

BEGIN
	--will be inserted
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'legen', 'EN', 'to put', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'stellen', 'EN', 'to put', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'setzen', 'EN', 'to put', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to run', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to race', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to career', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'sitzen', 'EN', 'to sit', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'stehen', 'EN', 'to stand', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'gehen', 'EN', 'to walk', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'average', 'DE', 'durchschnitt', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to count', 'DE', 'zaehlen', '1');
	
	
	--won't be inserted
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'legen', 'EN', 'to put', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'stellen', 'EN', 'to put', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'setzen', 'EN', 'to put', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to put', 'DE', 'legen', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to put', 'DE', 'stellen', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('EN', 'to put', 'DE', 'setzen', '1');
	
	
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to run', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to race', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'rennen', 'EN', 'to career', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'to run', 'EN', 'rennen', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'to race', 'EN', 'rennen', '1');
	INSERT_NEW_VOCABULARY_WITH_TRANSLATION('DE', 'to career', 'EN', 'rennen', '1');
	
	--ÜBERARBEITE DEN GESAMTEN MECHANISMUS DES EINFÜGENS VON VOKABELN:
		--
	
	
	
	--will be inserted
	INSERT_NEW_USER('Simon','Klein','simon.klein@triology.de');
	INSERT_NEW_USER('Lisa','Milde','lisa.milde@triology.de');

	--won't be inserted
	INSERT_NEW_USER('Hallo','Welt','simon.klein@triology.de');
	
	
	--Creates a new Statistic
	 CREATE_NEW_STATISTIC (0,'1', 1);
	 CREATE_NEW_STATISTIC (-1,' ', 1);
	 CREATE_NEW_STATISTIC (-1,'1', 1);
	 CREATE_NEW_STATISTIC (0,' ', 1);
	
END;


	
	
						
	


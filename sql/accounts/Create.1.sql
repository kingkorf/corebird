

PRAGMA user_version = 1;

-- SQL schema for an account database
CREATE TABLE IF NOT EXISTS `common`(
  token VARCHAR(100),
  token_secret VARCHAR(100)
);


CREATE TABLE IF NOT EXISTS `info`(
  id NUMERIC(19,0) PRIMARY KEY,
  screen_name VARCHAR(30),
  name VARCHAR(30)
);


CREATE TABLE IF NOT EXISTS `dm_threads`(
  user_id NUMERIC(19,0) PRIMARY KEY,
  name VARCHAR(40),
  screen_name VARCHAR(30),
  last_message VARCHAR(250),
  last_message_id NUMERIC(19,0),
  avatar_url VARCHAR (250)
);

CREATE TABLE IF NOT EXISTS `dms` (
  from_id NUMERIC(19,0),
  to_id NUMERIC(19,0),
  from_screen_name VARCHAR(30),
  to_screen_name VARCHAR(40),
  from_name VARCHAR(30),
  to_name VARCHAR(30),
  timestamp INTEGER(11),
  avatar_url VARCHAR(250),
  id NUMERIC (19,0) PRIMARY KEY,
  text TEXT
);



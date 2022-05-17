USE zeppelin;
--CREATE TABLE users (username TEXT, password TEXT, password_salt TEXT);
--CREATE TABLE user_roles (username TEXT, role_name TEXT);
--CREATE TABLE user_permissions (username TEXT, permission TEXT);
--GRANT ALL PRIVILEGES ON zeppelin.users TO 'zeppelin'@'localhost';
--GRANT ALL PRIVILEGES ON zeppelin.user_roles TO 'zeppelin'@'localhost';
--GRANT ALL PRIVILEGES ON zeppelin.user_permissions TO 'zeppelin'@'localhost';

# Create test users

INSERT INTO users (username, password) VALUES ('gaiauser1', '$shiro1..........f5giMWb5axaB+8cNE5B1oe4w58=');
INSERT INTO users (username, password) VALUES ('gaiauser2', '$shiro1$SH-.....sRoJS912hLLnMsjGKHA=');
INSERT INTO users (username, password) VALUES ('gaiauser3', '$shiro1$SHA........gQLtfF+JJ4Nvoztdv850=');
INSERT INTO users (username, password) VALUES ('gaiauser4', '$shiro1$SHA..........lda86sTHvKypv0=');
INSERT INTO users (username, password) VALUES ('gaiauser5', '$shiro1$SHA-.........vZfL3igfFTjzk9AjlC1UJdY=');
INSERT INTO users (username, password) VALUES ('gaiauser6', '$shiro1$SHA-........Rzlyr5eeuBEkPyyLSWo=');
INSERT INTO users (username, password) VALUES ('gaiauser7', '$shiro1$SHA-..........9WXdKLPXQeWC17iyOmkK8PkLDYHMvHQ=');
INSERT INTO users (username, password) VALUES ('gaiauser8', '$shiro1$SH............673LYs6EqSEH1LSec95c=');
INSERT INTO users (username, password) VALUES ('gaiauser9', '$shiro1$SHA-z............jozPuicSp5DNw45OnvdUxSU10kb2k=');
INSERT INTO users (username, password) VALUES ('gaiauser10', '$shiro1$SH............ZObnftBrFs+WLqI/oS2uvb2/vPJDU=');

# Create roles

INSERT INTO user_roles (username, role_name) VALUES ('gaiauser1', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser2', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser3', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser4', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser5', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser6', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser7', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser8', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser9', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('gaiauser10', 'user');



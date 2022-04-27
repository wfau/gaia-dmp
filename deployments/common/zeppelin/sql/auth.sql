USE zeppelin;
CREATE TABLE users (username TEXT, password TEXT, password_salt TEXT);
CREATE TABLE user_roles (username TEXT, role_name TEXT);
CREATE TABLE user_permissions (username TEXT, permission TEXT);
GRANT ALL PRIVILEGES ON zeppelin.users TO 'zeppelin'@'localhost';
GRANT ALL PRIVILEGES ON zeppelin.user_roles TO 'zeppelin'@'localhost';
GRANT ALL PRIVILEGES ON zeppelin.user_permissions TO 'zeppelin'@'localhost';


INSERT INTO users (username, password) VALUES ('gaiauser', '$shiro1$SHA-256$500...........R0GxWVAH028tjMyIkbKmMDW2E0=');
INSERT INTO users (username, password) VALUES ('dcr', '$shiro1$SHA-256$500000...........bp5aQVQtw6kmVMUlENoGkrBPjCDqWOs=');
INSERT INTO users (username, password) VALUES ('nch', '$shiro1$SHA-256$500000$MPs..............5lBwoKj7LtnBMUZJp4XmCyBv9yvMZrM=');
INSERT INTO users (username, password) VALUES ('zrq', '$shiro1$SHA-256$50000...............Pm6tS4XfOETCwEwI8Ri5FE8GfM2uBRQ=');
INSERT INTO users (username, password) VALUES ('stv', '$shiro1$SHA-25.....................sAkP3jjvbeq1KHgieb00pIizAM=');
INSERT INTO users (username, password) VALUES ('admin', '$shiro1$SHA-256$50000.................p+LFeSFqvBNMKVpYMVMCc+cE8/rrTQI=');
INSERT INTO users (username, password) VALUES ('yrvafhom', '$shiro1$SHA-256$500000$b/..............C9diAs6AUdv/29qjtsSLqmWUQ=');

# Create roles

INSERT INTO user_roles (username, role_name) VALUES ('admin', 'admin');
INSERT INTO user_roles (username, role_name) VALUES ('dcr', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('nch', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('zrq', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('stv', 'user');
INSERT INTO user_roles (username, role_name) VALUES ('yrvafhom', 'user');



USE zeppelin;
CREATE TABLE users (username TEXT, password TEXT, password_salt TEXT);
CREATE TABLE user_roles (username TEXT, role_name TEXT);
CREATE TABLE user_permissions (username TEXT, permission TEXT);
GRANT ALL PRIVILEGES ON zeppelin.users TO 'zeppelin'@'localhost';
GRANT ALL PRIVILEGES ON zeppelin.user_roles TO 'zeppelin'@'localhost';
GRANT ALL PRIVILEGES ON zeppelin.user_permissions TO 'zeppelin'@'localhost';


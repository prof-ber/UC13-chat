CREATE DATABASE chat;

CREATE TABLE users (
    id VARCHAR(128) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    senha VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pictures (id INT PRIMARY KEY auto_increment, pictures_data LONGBLOB);

CREATE TABLE users_pictures (    
    user_id VARCHAR(128),
    picture_id INT,
    PRIMARY KEY (user_id, picture_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (picture_id) REFERENCES pictures(id) ON DELETE CASCADE
);
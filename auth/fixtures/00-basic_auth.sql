/* 
Basic auth that tests overarching roles and basic RSL 
*/

CREATE ROLE user1 NOINHERIT LOGIN;
CREATE ROLE user2 NOINHERIT LOGIN;
CREATE ROLE user3 NOINHERIT LOGIN;
CREATE ROLE deleter NOINHERIT LOGIN;

CREATE TABLE messages(
    id serial PRIMARY KEY,
    from_user text NOT NULL,
    to_user text NOT NULL,
    message text NOT NULL
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY ensure_user ON messages
USING(current_user in (from_user, to_user) OR current_user = 'deleter')
WITH CHECK (current_user = from_user);

CREATE POLICY no_delete ON messages
FOR DELETE USING(current_user = 'deleter');

GRANT ALL PRIVILEGES ON messages TO user1;  
GRANT USAGE ON SEQUENCE messages_id_seq TO user1;
GRANT ALL PRIVILEGES ON messages TO user2;  
GRANT USAGE ON SEQUENCE messages_id_seq TO user2;
GRANT ALL PRIVILEGES ON messages TO user3;  
GRANT USAGE ON SEQUENCE messages_id_seq TO user3;
GRANT ALL PRIVILEGES ON messages TO deleter;  
GRANT USAGE ON SEQUENCE messages_id_seq TO deleter;

INSERT INTO messages (from_user, to_user, message) VALUES 
    ('user1', 'user2', 'row level securities are sweet'),
    ('user2', 'user1', 'I know, we should use them for authentication!'),
    ('user3', 'user1', 'User 2 is a bit of a drama queen dont you think?');

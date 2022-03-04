/* sql to clean up the db after each run */
DROP POLICY IF EXISTS ensure_user ON messages;
DROP TABLE IF EXISTS messages CASCADE;

DROP ROLE IF EXISTS user3;
DROP ROLE IF EXISTS user2;
DROP ROLE IF EXISTS user1;
DROP ROLE IF EXISTS deleter;

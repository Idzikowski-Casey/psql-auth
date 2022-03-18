CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA auth;

/* table to keep track of web users */
CREATE TABLE auth.users (
    id       serial PRIMARY KEY,
    username text,
    pass     text   
);

/* way to keep track of logins and sessions */
CREATE TABLE auth.sessions(
    id      serial PRIMARY KEY,
    user_id int not null REFERENCES auth.users(id),
    token   uuid NOT NULL DEFAULT public.gen_random_uuid() UNIQUE
);

/* gets the current uuid token */
CREATE OR REPLACE FUNCTION 
auth.getauth(OUT token uuid) AS
$$
BEGIN
    SELECT nullif(current_setting('auth.auth_token'), '') INTO token;
    EXCEPTION WHEN undefined_object THEN
END;
$$ LANGUAGE plpgsql STABLE;

/* sets the uuid token as a setting, used in rls */
CREATE OR REPLACE FUNCTION auth.setauth(token text) RETURNS UUID AS $$
BEGIN
    PERFORM set_config('auth.auth_token', token, false);
    RETURN auth.getauth();
END
$$ LANGUAGE plpgsql;

/* maps a uuid token back to a user */
CREATE OR REPLACE FUNCTION auth.token2user(_token text, OUT _user_id int) AS $$
BEGIN
    SELECT user_id FROM auth.sessions WHERE token = _token::uuid INTO _user_id;
    IF _user_id IS NULL THEN
        RAISE 'AUTH TOKEN INVALID';
    END IF; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* gets the current user that is logged in */
CREATE OR REPLACE FUNCTION auth.curuser() RETURNS int AS $$
DECLARE
    _token uuid;
BEGIN
    SELECT auth.getauth() INTO _token;
    RETURN CASE WHEN _token IS NULL THEN NULL ELSE auth.token2user(_token::text) END;
END
$$ LANGUAGE plpgsql STABLE;

/* trigger to hash password on insert or update */
CREATE OR REPLACE FUNCTION
auth.encrypt_pass() RETURNS trigger AS $$
BEGIN
  IF tg_op = 'INSERT' OR new.pass <> old.pass THEN
    new.pass := public.crypt(new.pass, public.gen_salt('md5'));
  END IF;
  RETURN new;
END
$$ LANGUAGE plpgsql;

/* trigger to hash password on insert or update */
DROP trigger IF EXISTS encrypt_pass ON auth.users;
CREATE trigger encrypt_pass
  BEFORE INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE auth.encrypt_pass();

/* initial login function */
CREATE OR REPLACE FUNCTION
auth.login(_username text, _pass text, OUT _token uuid) AS $$
DECLARE
    _user auth.users;
BEGIN
    SELECT * FROM auth.users WHERE username = _username INTO _user;
    IF _user is NULL OR _user.pass != public.crypt(_pass, _user.pass) THEN
        RAISE 'INVALID username or password';
    ELSE INSERT INTO auth.sessions (user_id) VALUES (_user.id)
        RETURNING token INTO _token;
      PERFORM auth.setauth(_token::text);
    END IF;
END
$$ language plpgsql SECURITY DEFINER;

/* login function to continue a current login session, from uuid */
CREATE OR REPLACE FUNCTION
auth.login(INOUT _token uuid) AS $$
BEGIN 
    PERFORM auth.setauth(NULL);
    PERFORM auth.token2user(_token::text); -- validate token
    PERFORM auth.setauth(_token::text);
END
$$ language plpgsql SECURITY DEFINER;

/* logout function removes uuid from sessions table and sets auth to null */
CREATE OR REPLACE FUNCTION auth.logout(_token text DEFAULT auth.getauth()) RETURNS VOID AS $$
BEGIN
    BEGIN
        DELETE FROM auth.sessions WHERE token = _token::uuid;
    EXCEPTION WHEN OTHERS THEN
    END;
    PERFORM auth.setauth(NULL);
END
$$ language plpgsql SECURITY DEFINER;

INSERT INTO auth.users(username, pass) VALUES
    ('appuser1', 'password1'),
    ('appuser2', 'password2');


CREATE ROLE api WITH LOGIN NOINHERIT;
GRANT USAGE ON SCHEMA auth TO api;

GRANT SELECT ON auth.users TO api;

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

/* policy allows only the current logged in user to access their own data */
CREATE POLICY own_user ON auth.users
FOR SELECT 
USING (id = auth.curuser());

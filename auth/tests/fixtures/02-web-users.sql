/* 
    data privilege descriptions:
        - reader: can only SELECT on data
        - writer: can SELECT, INSERT, and UPDATE
        - deleter: can SELECT, INSERT, UPDATE, and DELETE
        - owner: all privileges and can allow other users to access their data
 */
CREATE TYPE auth.data_privileges AS ENUM ('reader', 'writer', 'deleter','owner');


/* Data schema */
CREATE SCHEMA IF NOT EXISTS data;

/* We need a trigger on projects that makes curuser owner of project on insert */
CREATE TABLE IF NOT EXISTS data.projects (
    id SERIAL PRIMARY KEY,
    name text,
    description text
);

CREATE TABLE IF NOT EXISTS data.rocks (
    id SERIAL PRIMARY KEY,
    lithology text,
    time_period text,
    time numeric,
    project_id integer REFERENCES data.projects(id)
);

/* auth -> projects w/privileges mapping table */
CREATE TABLE IF NOT EXISTS auth.projects(
    id SERIAL PRIMARY KEY,
    user_id integer REFERENCES auth.users(id),
    project_id integer REFERENCES data.projects(id),
    privilege auth.data_privileges
);

/* Extend privileges of api db role */
GRANT USAGE ON SCHEMA data TO api;

GRANT USAGE, SELECT, UPDATE ON auth.projects_id_seq TO api;
GRANT SELECT, INSERT, UPDATE, DELETE ON auth.projects TO api;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA data TO api;
GRANT SELECT, INSERT, UPDATE, DELETE ON data.projects TO api;
GRANT SELECT, INSERT, UPDATE, DELETE ON data.rocks TO api;

/* Helper functions for RLS */
 -- get user id and then map to auth.projects table
CREATE OR REPLACE FUNCTION auth.curuser_projects() 
RETURNS TABLE (project_id integer, privilege auth.data_privileges) AS $$
DECLARE
    _user_id integer;
BEGIN
    SELECT curuser FROM auth.curuser() INTO _user_id;
    RETURN QUERY SELECT p.project_id, p.privilege FROM auth.projects p WHERE p.user_id = _user_id;
END
$$ language plpgsql SECURITY DEFINER;

/* RLS On Tables */
ALTER TABLE auth.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE data.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE data.rocks ENABLE ROW LEVEL SECURITY;

-- Only project owners can view and manipulate project privileges
CREATE POLICY owner_projects ON auth.projects
USING (project_id IN (
    SELECT project_id from auth.curuser_projects() 
    WHERE privilege = 'owner'))
WITH CHECK (project_id IN (
    SELECT project_id from auth.curuser_projects() 
    WHERE privilege = 'owner'));

-- Projects only viewable based on auth projects table
CREATE POLICY projects_secure ON data.projects
USING (id IN (
    SELECT project_id from auth.curuser_projects()
    WHERE privilege IN ('reader','writer','deleter','owner')))
WITH CHECK (id IN (
    SELECT project_id from auth.curuser_projects()
    WHERE privilege IN ('writer','deleter', 'owner')
));

-- Rocks can only be viewed based on their projects
CREATE POLICY rocks_secure ON data.rocks
USING (project_id IN (
    SELECT project_id from auth.curuser_projects()
    WHERE privilege IN ('reader','writer','deleter','owner')))
WITH CHECK (project_id IN (
    SELECT project_id from auth.curuser_projects()
    WHERE privilege IN ('writer','deleter', 'owner')
));

INSERT INTO auth.users(username, pass) VALUES
    ('cidzikowski', 'casey-password'),
    ('dquinn', 'daven-password'),
    ('speters', 'shanan-password');

INSERT INTO data.projects(name, description) VALUES 
    ('Project-idz', 'This project belongs to Casey'),
    ('Project-quinn', 'This project belongs to Daven'),
    ('Project-peters', 'This project belongs to Shanan');

INSERT INTO data.rocks(lithology, time_period, time, project_id) VALUES
    ('Sandstone', 'cretaceous', 100, 3),
    ('Limestone', 'cambrian', 500, 3),
    ('Mudstone', 'permian', 260, 3),
    ('Tonalite trondhjemite granodiorite', 'paleo-archean', 3700, 1),
    ('Zircon', 'archean', 2600, 1),
    ('Basalt', 'paleocene', 60, 1);

INSERT INTO auth.projects(user_id, project_id, privilege) VALUES
    (3, 1, 'owner'),
    (4, 2, 'owner'),
    (5, 3, 'owner'),
    (4, 3, 'reader'),
    (4, 1, 'writer');

-- trigger to insert project as owner into auth table
CREATE OR REPLACE FUNCTION auth.project_owner()
RETURNS trigger AS $$
DECLARE
    _user_id integer;
BEGIN
    SELECT curuser FROM auth.curuser() INTO _user_id;

    IF tg_op = "INSERT" THEN
        INSERT INTO auth.projects(user_id, project_id, privilege) VALUES
            (_user_id, NEW.id, 'owner');
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP trigger IF EXISTS project_owner ON data.projects;
CREATE trigger project_owner
  AFTER INSERT ON data.projects
  FOR EACH ROW
  EXECUTE PROCEDURE auth.project_owner();
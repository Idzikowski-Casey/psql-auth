-- data privilege roles
CREATE TABLE IF NOT EXISTS auth.data_roles(
    id SERIAL PRIMARY KEY,
    role text,
    description text
);
-- default data roles
INSERT INTO auth.data_roles(role, description) VALUES
    ('reader', 'user can only perform SELECT on data'),
    ('writer', 'user can SELECT, INSERT, and UPDATE'),
    ('deleter', 'user can SELECT, INSERT, and UPDATE'),
    ('manager', 'user encompasses privileges of deleter and can manage user permissions on data');

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
    role_id integer REFERENCES auth.data_roles(id)
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
CREATE OR REPLACE FUNCTION auth.current_user_projects() 
RETURNS TABLE (project_id integer, role text) AS $$
DECLARE
    _user_id integer;
BEGIN
    SELECT auth.current_user() INTO _user_id;
    RETURN QUERY SELECT p.project_id, r.role FROM auth.projects p 
                 JOIN auth.data_roles r
                 ON r.id = p.role_id
                 WHERE p.user_id = _user_id;
END
$$ language plpgsql SECURITY DEFINER;

/* RLS On Tables */
ALTER TABLE auth.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE data.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE data.rocks ENABLE ROW LEVEL SECURITY;

-- Only project owners can view and manipulate project privileges
CREATE POLICY owner_projects ON auth.projects
USING (project_id IN (
    SELECT project_id from auth.current_user_projects() 
    WHERE role = 'manager'));

-- Projects only viewable based on auth projects table
CREATE POLICY projects_select ON data.projects FOR SELECT
USING (id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('reader','writer','deleter','manager')));

/* 
    Update Policies are special because you can set both a USING and WITH CHECK
    criteria. USING will apply to existing rows and WITH CHECK will apply to new rows.
 */
CREATE POLICY projects_update ON data.projects FOR UPDATE
USING (id IN  (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('writer','deleter','manager')));

CREATE POLICY projects_insert ON data.projects FOR INSERT
WITH CHECK (id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('writer','deleter','manager')));

CREATE POLICY projects_delete ON data.projects FOR DELETE
USING (id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('deleter','manager')));

-- Rocks can only be viewed based on their projects
CREATE POLICY rocks_select ON data.rocks FOR SELECT
USING (project_id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('reader','writer','deleter','manager')));

CREATE POLICY rocks_insert ON data.rocks FOR INSERT
WITH CHECK(project_id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('writer','deleter', 'manager')));

CREATE POLICY rocks_update ON data.rocks FOR UPDATE
USING (project_id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('writer','deleter', 'manager')));

CREATE POLICY rocks_delete ON data.rocks FOR DELETE
USING (id IN (
    SELECT project_id from auth.current_user_projects()
    WHERE role IN ('deleter','manager')));

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

INSERT INTO auth.projects(user_id, project_id, role_id) VALUES
    (3, 1, 4),
    (4, 2, 4),
    (5, 3, 4),
    (4, 3, 1),
    (4, 1, 2);

-- trigger to insert project as owner into auth table
CREATE OR REPLACE FUNCTION auth.project_owner()
RETURNS trigger AS $$
DECLARE
    _user_id integer;
    manager_id integer;
BEGIN
    SELECT auth.current_user() INTO _user_id;
    SELECT id FROM auth.data_roles WHERE role = 'manager' INTO manager_id;
    IF tg_op = "INSERT" THEN
        INSERT INTO auth.projects(user_id, project_id, role_id) VALUES
            (_user_id, NEW.id, manager_id);
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP trigger IF EXISTS project_owner ON data.projects;
CREATE trigger project_owner
  AFTER INSERT ON data.projects
  FOR EACH ROW
  EXECUTE PROCEDURE auth.project_owner();
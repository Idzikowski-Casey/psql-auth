/* 
    mapping web users to database roles for login! Password will be same as user's password
    1. Db-roles table in auth
    2. Function to create role for user
        - make sure that role name isn't already taken
    3. Function to get user_id from current_user and then
       get project_ids similar to current_user_projects 
    
    NOTE: _current_user needs to be passed in the policy bc security definer functions mess with
          current_user.
*/

CREATE TABLE auth.web_db_roles(
    id SERIAL PRIMARY KEY,
    user_id integer REFERENCES auth.users(id),
    role text
);

/* function to create a database role from a user role, should only work if logged in */
CREATE OR REPLACE FUNCTION auth.create_current_user_role(role_name text, pass text)
RETURNS VOID AS $$
DECLARE
    _user_id integer;
BEGIN
    -- get current user id
    -- create the database role
    -- insert role and user_id into table
    SELECT auth.current_user() INTO _user_id;
    IF _user_id IS NULL THEN
        RAISE EXCEPTION 'No one is logged in!';
    END IF;

    IF role_name IN (select rolname from pg_roles) THEN
        RAISE EXCEPTION 'Invalid Role Name, %', role_name
            using hint = 'role_name already in use';
    END IF;
    -- create role and grant same privileges as api
    EXECUTE FORMAT('CREATE ROLE "%I" LOGIN PASSWORD %L INHERIT', role_name, pass);
    EXECUTE FORMAT('GRANT api TO "%I"', role_name);

    INSERT INTO auth.web_db_roles(user_id, role) VALUES (_user_id, role_name);
END
$$ language plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION auth.get_current_db_user_id(_current_user text)
RETURNS integer AS $$
DECLARE
    _user_id integer;
BEGIN
    SELECT wdr.user_id FROM auth.web_db_roles wdr WHERE _current_user = wdr.role INTO _user_id;
    RETURN _user_id;
END
$$ language plpgsql SECURITY DEFINER;

/* function for rls, map the current_user to a _user_id */
CREATE OR REPLACE FUNCTION auth.db_user_projects(_current_user text) 
RETURNS TABLE (project_id integer, role text) AS $$
DECLARE
    _user_id integer;
BEGIN
    SELECT auth.get_current_db_user_id(_current_user) INTO _user_id;
    RETURN QUERY SELECT p.project_id, r.role FROM auth.projects p 
                 JOIN auth.data_roles r
                 ON r.id = p.role_id
                 WHERE p.user_id = _user_id;
END
$$ language plpgsql SECURITY DEFINER;

-- Only project owners can view and manipulate project privileges
CREATE POLICY owner_projects_db_user ON auth.projects
USING (project_id IN (
    SELECT project_id from auth.db_user_projects(current_user) 
    WHERE role = 'manager'));

-- Projects only viewable based on auth projects table
CREATE POLICY projects_select_db_user ON data.projects FOR SELECT
USING (id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('reader','writer','deleter','manager')));

/* 
    Copied and pasted policies from previous file and replaced the function. 
    RLS works such that if there are multiple policies only one needs to be passed, implicit OR.
 */
CREATE POLICY projects_update_db_user ON data.projects FOR UPDATE
USING (id IN  (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('writer','deleter','manager')));

CREATE POLICY projects_insert_db_user ON data.projects FOR INSERT
WITH CHECK (id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('writer','deleter','manager')));

CREATE POLICY projects_delete_db_user ON data.projects FOR DELETE
USING (id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('deleter','manager')));

-- Rocks can only be viewed based on their projects
CREATE POLICY rocks_select_db_user ON data.rocks FOR SELECT
USING (project_id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('reader','writer','deleter','manager')));

CREATE POLICY rocks_insert_db_user ON data.rocks FOR INSERT
WITH CHECK(project_id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('writer','deleter', 'manager')));

CREATE POLICY rocks_update_db_user ON data.rocks FOR UPDATE
USING (project_id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('writer','deleter', 'manager')));

CREATE POLICY rocks_delete_db_user ON data.rocks FOR DELETE
USING (id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role IN ('deleter','manager')));


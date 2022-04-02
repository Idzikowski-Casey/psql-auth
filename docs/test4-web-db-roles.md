# Web Users to DB Roles

### Granting db logins with specific permissions to web users

### Important Concepts

- Custom data auth schema can be extended to DB roles

### Overview:

There is often the case where it will be beneficial for a web user to also have a db user login. That way a web user can also edit the db directly through a db-ui such as [Postico](https://eggerapps.at/postico/) or [PgAdmin](https://www.pgadmin.org/). This is specific to "lab-data" software that macrostrat and sparrow specialize in. Generally speaking, it is not a good idea to give users access to the database.

We will create new database roles that inherit from the base API role, which is restricted to only the data. Then we will create new table policies that check for a "current_user" other than API and match the created role back to a user and then to the data table and voila! Security.

The first thing we do is create an `auth.web_db_roles` table that maps a role to a user_id in the `auth` schema. This table will be used to map a current_user to a web_user for row level security policies.

Next, we create a helper function that will create a new database role that can login with a password. The role_name and password are passed to the function. This function checks to make sure a web_user is logged on and if not will error out. Then it checks to make sure that the role_name is free and not already in use. After these checks it creates the role with login and inherits the api role, the base db role that we use for our db connection. Lastly it inserts the new role name and user_id into the `auth.web_db_roles` table.

After that we need to make some functions that will allow our table policies to easily check the privileges of the current_user. Remember that for table policies if there are multiple for the same action, only one needs to pass in order for the query to execute. The main thing we need to do is map the `current_user` to a `user_id` in the `auth.users` table. This is achieved by the new table we recently made! We can then recreate a function from our last test, that returns projects and privileges, but modify the function so that it maps the `current_user` to a `user_id`.

```sql
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
```

**NOTE**: Because our functions are `SECURITY DEFINER` we need to pass `current_user` from the table policies.

```sql
-- Only project owners can view and manipulate project privileges
CREATE POLICY owner_projects_db_user ON auth.projects
USING (project_id IN (
    SELECT project_id from auth.db_user_projects(current_user)
    WHERE role = 'manager'));
```

### TL;DR

We have extended our custom authentication schema to database roles. Now a specific user can create a postgres login for the database and the row level securities will remain in effect!

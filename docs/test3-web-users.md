# Web Users and RLS

### Applying row level security to traditional web user design and complex data level permissions

### Important Concepts

- RLS on data tables can be set based on column values mapping data privileges to web-users
- RLS can easy allow for data owners to manage other users' access to their data

### SQL Overview

In this section we are building onto the already built `auth` schema while creating a new `data` schema. To begin we create a `auth.data_roles` table which will specifiy a role type and a description of associated privileges. Defaults are as follows, but because we're making it a separate table it's easy to add more roles as seen fit.

- `reader`: can only SELECT on data
- `writer`: can SELECT, INSERT, and UPDATE
- `deleter`: can SELECT, INSERT, UPDATE, and DELETE
- `manager`: all privileges and can allow other users to access their data

Next we create an arbitrary `data` schema with table definitions that represent hierarchical data. `Projects` and `Rocks`, where there is a **one to many** relationship, such that one project can have many rocks, but each rock has only one project.

Now, in the `auth` schema we construct another `projects` table, but instead of tracking data, it will track a mapping of user, from `auth.users`, to a `project_id` from `data.projects` as well as a permission based on the enum we created earlier. This mapping is what we will use in our row level securities on our data tables.

After granting access to our new tables and schema to our `api` db user, we will create a helper function and enact some table policies. The helper function `auth.current_user_projects()` is a function that returns a query from `auth.projects` of the project_id and the privilege the current user has. This function interally uses `auth.current_user()` to access the current logged in user.

The policies for the tables are relatively straight forward. The make sure that a) the current_user has the row project_id mapped to it in the `auth.projects` table and it also checks the user's `role` against a list. For instance, to update and insert on a data schema table the user must have one of the three following permissions: `writer`,`deleter`, or `manager`. Since the data is represented hierarchical, under `projects` it's easy enough to manage policies through project_id alone. But this could easily be adapted for more complex data models.

Some introductory inserts are added to aid in testing as well as a trigger function on the projects table. Every time a user creates a new project, that project_id and user_id is added to the `auth.projects` table with 'owner' privileges.

### Tests Summary

These tests are checking the table policies created, making sure that certain web-users can only see certain rows and ensuring that updates and failing when they're supposed to.

In these tests, we are also checking the user management capabilities of this design. Project owners can easily manage data permissions to other web users. But users can only manage permissions on projects that **they are owners** of.

### TL;DR

In the third test, we have extended the `auth` schema and row level securities on tables to show and hide data
based on arbitrary settings of data ownership. We have also allowed for the manipulation of data level privileges to be set by the data "owner."

### Resources

- [Supabase Managing user data](https://supabase.com/docs/guides/auth/managing-user-data)

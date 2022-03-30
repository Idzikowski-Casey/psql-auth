# Creation of an Auth Schema

### Basic application user management in postgres

### Important Concepts

- Ideally there is one database transaction to handle requests
- Application users can be stored and tracked in a custom schema
- Handling logins and sessions can be tracked using a custom schema and `current_setting`
- Row level security can easily be configured using `current_setting`

### SQL Overview

The SQL file (`/auth/database/fixtures/01-auth-schema.sql`) for these tests is a bit more complicated. Some comments are made in the file itself to aid understanding. Generally speaking this sql file does the following.

**Creates an `auth` schema with a `users` and `sessions` table**

The point of these two tables is to keep track of different application users, `users`, as well as their login and logout as sessions. Currently on successful login a session is assigned a `UUID` which is relatively safe. It's "properly" random however it may not be the safest in real world applications. A better alternative would be a `sign()` function based on a secret key that can be hidden from the source code, similar to how JSON WEB TOKENS are done.

**Creates utility functions**

There are a slew of SQL functions that are designed to aid in handling user sessions, logins and logouts. The **_current user_** is assumed by the `current_setting('auth.auth_token')` value which is accessed via the function `auth.getauth()`.

There are two `login` functions differentiated by their parameters. One takes in a `username` and `password` while the other takes in the session `UUID`. This enables a webuser to not need to login to their account every time they make a request. This is similar to how JWTs are used and stored in browser local storage.

A `logout` function removes the `current_setting` and removes the associated session `UUID` from the `sessions` table. This means a user will need to login again to access any data.

**Creates an `api` db role**

The model for this desgin is to have one general database role, `api`, that has usage privileges on the data tables, however is restricted by `ROW LEVEL SECURITY` policies on individual tables. For this instance, we create an `api` user that has usage on the auth schema and `SELECT` on `auth.users`.

**RLS on auth.users**

We enable row level security for the `auth.users` table and then write a policy that ensures the only rows that can be selected are those of the current user (`auth.curuser()`). No one can see anyone elses information.

### Resources

- [Supabase RLS guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Postgres auth](https://postgrest.org/en/stable/auth.html#schema-isolation)

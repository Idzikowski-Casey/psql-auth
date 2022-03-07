# A basic auth exploration in postgres

### testing general db roles and row level security options

### SQL Overview:

Contents in `/auth/database/fixtures/00-basic_auth.sql`.

In this first group of tests we create 4 users that do not inherit from their creator (which in this case
would be the superuser `postgres`), and we allow them to `LOGIN` (i.e establish a connection with the db). We next create a basic table called `messages` that holds text information on messages sent between users. In this table the `from_user` and `to_user` will be one of the users we just created.

Next we must enable [row level security](https://www.postgresql.org/docs/14/ddl-rowsecurity.html) for the `messages` table. To implement RLS, policies are created with boolean checks that correspond to accessing a row. **NOTE:** once RLS is enabled on a table policies **MUST** be set or else the data will be unaccessable by any DB role besides a superuser or one created with the `BYPASSRLS` keyword.

Table policies are created using the [`CREATE POLICY`](https://www.postgresql.org/docs/14/sql-createpolicy.html) command. To control for `SELECT` operation the `USING` logic check is applied and for `UPDATE, INSERT` the `WITH CHECK` is applied.

```sql
CREATE POLICY ensure_user ON messages
USING(current_user in (from_user, to_user) OR current_user = 'deleter')
WITH CHECK (current_user = from_user);
```

The policy above `ensure_user` compares the current database user (`current_user`) to the user in either the `from_user` or `to_user` when controling `SELECT` operations. We have also given the user `deleter` the ability to `SELECT` because when deleting the user inheritently calls the `SELECT` method (`WHERE` keyword calls a `SELECT`). For `UPDATE, INSERT` actions this policy allows only the action where the `current_user` is the same as `from_user` or whoever originally sent the message.

The last things we must do before creating tests is grant privileges on the `message` table to our users since they have `NOINHERIT`.

The tests, which can be found at `/auth/tests/test_basic_auth.py`, are testing these row level policies to ensure they are working correctly.

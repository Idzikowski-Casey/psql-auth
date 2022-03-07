from auth.database import Database, get_sql

def test_db_auth_sql():
    """ run auth schema sql file """
    sql = get_sql('01-auth-schema.sql')

    db = Database() # default postgres

    with db.conn.cursor() as cur:
        cur.execute(sql)
    
    sql = """ 
    SELECT rolname FROM pg_catalog.pg_roles WHERE rolinherit = FALSE AND rolname = 'api';
     """

    res = db.query(sql).fetchone()
    assert res.get('rolname') == 'api'

    sql = """ 
        SELECT * FROM auth.users;
     """

    res = db.query(sql).fetchall()
    assert len(res) == 2

def test_login_functions():
    """ test some of the functions created """

    user1 = {"username": "appuser1", "password": "password1", "id" : 1}
    user2 = {"username": "appuser2", "password": "password2", "id": 2}
    users = [user1, user2]

    db_api_user = Database('api')
    for user in users:

        sql = f""" 
            SELECT auth.login('{user["username"]}', '{user["password"]}');
        """
        ## test the login function
        res = db_api_user.query(sql).fetchall()
        assert len(res) == 1

        assert res[0].get('login') is not None

        # ensure the current user is the one logged in
        sql = """ SELECT auth.curuser(); """
        res = db_api_user.query(sql).fetchall()

        assert len(res) == 1 and res[0].get('curuser') == user["id"]

        sql = """ SELECT * FROM auth.users; """

        # ensure logged in user is only able to select themselves
        res = db_api_user.query(sql).fetchall()
        assert len(res) == 1 and res[0].get('username') == user["username"]

        # logout at end
        db_api_user.conn.cursor().execute("SELECT auth.logout();")
    
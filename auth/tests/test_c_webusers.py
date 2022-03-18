from auth.database import Database, get_sql

""" Testing the 3rd SQL file auth stuff. ROW LEVEL security on auth.projects,
 data.projects and data.rocks.
 
We need:
    - tests for viewing and editing data
    - test for viewing and editing auth.projects privileges
"""
logout_sql = """ SELECT auth.logout(); """
idz_login_sql = """ SELECT auth.login('cidzikowski', 'casey-password'); """
d_login_sql = """ SELECT auth.login('dquinn', 'daven-password') """
s_login_sql = """ SELECT auth.login('speters', 'shanan-password') """

def login(db: Database, sql):
    db.conn.cursor().execute(sql)

def logout(db: Database):
    db.conn.cursor().execute(logout_sql)

def test_web_user_sql():
    sql = get_sql('02-web-users.sql')

    db = Database()

    with db.conn.cursor() as cur:
        cur.execute(sql)
    
    sql = """ SELECT * FROM auth.projects; """

    res = db.query(sql).fetchall()

    assert len(res) == 5

def test_data_privileges():
    db = Database('api')

    res = db.query(idz_login_sql).fetchall()
    assert len(res) == 1
    assert res[0].get('login') is not None

    sql = """ SELECT * FROM data.rocks; """
    res = db.query(sql).fetchall()

    assert len(res) == 3
    for rock in res:
        assert rock.get('project_id') == 1
    
    db.conn.cursor().execute(logout_sql)

    res = db.query(d_login_sql).fetchall()

    res = db.query(sql).fetchall()
    assert len(res) == 6

    sql = """ UPDATE data.projects
              SET description = 'Daven is trying to edit this description! Will not work!'
              WHERE id = 3  
        """

    try: 
        db.conn.cursor().execute(sql)
        assert False
    except:
        assert True # insert failed!

    description = 'Daven is trying to edit this description! This will Work!'
    sql = f""" UPDATE data.projects
              SET description = '{description}'
              WHERE id = 1  
        """
    db.conn.cursor().execute(sql)

    sql = """ SELECT * FROM data.projects WHERE id = 1 """
    res = db.query(sql).fetchone()

    assert res.get('description') == description

def test_auth_projects_privileges():
    """ test project owners changing who can do what to their data """

    db = Database('api')

    ## first as Casey access auth.projects and change daven from writer to reader
    db.conn.cursor().execute(idz_login_sql)

    sql = """ SELECT * FROM auth.projects; """
    res = db.query(sql).fetchall()

    assert len(res) == 2

    update_sql = """ UPDATE auth.projects SET privilege = 'reader' WHERE user_id = 4; """
    db.conn.cursor().execute(update_sql)

    # now daven shouldn't be able to update project 1
    logout(db)
    login(db, d_login_sql)
    des = 'Daven will unnsuccessfully try to update caseys project'

    sql = f""" UPDATE data.projects
              SET description = '{des}'
              WHERE id = 1  
        """

    try:
        db.conn.cursor().execute(sql)
        assert False
    except:
        assert True
    
    sql = """ SELECT * FROM data.projects WHERE id = 1; """

    res = db.query(sql).fetchone()

    assert res.get('description') != des
    logout(db)

def test_make_owner():
    """ test making another webuser an owner of your project """

    db=Database('api')
    ## As shanan, grant Casey owner privileges.

    login(db, s_login_sql)

    sql = """ SELECT * FROM auth.projects; """

    res = db.query(sql).fetchall()

    assert len(res) == 2

    insert_sql = """ INSERT INTO auth.projects(user_id, project_id, privilege) VALUES
                        (3, 3, 'owner');
                 """
    
    db.conn.cursor().execute(insert_sql)
    res = db.query(sql).fetchall()
    
    assert len(res) == 3

    logout(db)
    
    # as casey see if you are owner and then do stuff
    login(db, idz_login_sql)

    res = db.query(sql).fetchall()

    # now casey can see his project rows and shanan's project rows
    assert len(res) == 5

    sql = """ 
            UPDATE data.rocks 
            SET time_period = 'ordovician' 
            WHERE lithology = 'Sandstone' AND project_id = 3; 
          """

    db.conn.cursor().execute(sql)

    sql = """ SELECT * FROM data.rocks; """
    res = db.query(sql).fetchall()
    assert len(res) == 6

    sandstone_row = list(filter(lambda rock: rock.get('lithology') == 'Sandstone', res))[0]
    assert sandstone_row.get('time_period') == 'ordovician'

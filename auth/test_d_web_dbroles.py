from .fixtures import Database, get_sql


""" 
Testing '03-web-db-roles.sql'. Creating individual database roles that can login to postgres
and keep the same row level privileges as their web-user role
"""

c_role = 'cidz'
c_password = 'casey-password'

idz_login_sql = """ SELECT auth.login('cidzikowski', 'casey-password'); """

s_role = 'shanan'
s_password = 'shanan-password'

s_login_sql = """ SELECT auth.login('speters', 'shanan-password') """

def login(db: Database, sql):
    db.conn.cursor().execute(sql)

def test_run_sql():
    db = Database()

    sql = get_sql('03-web-db-roles.sql')

    with db.conn.cursor() as cur:
        cur.execute(sql)
    
def test_create_db_role():
    """ login as cidzikowski and create db role """
    db = Database("api")
    login(db, idz_login_sql)

    create_role_sql = f""" SELECT auth.create_current_user_role('{c_role}', '{c_password}') """

    db.query(create_role_sql).fetchall()

    db.conn.cursor().execute(""" SELECT auth.logout(); """)

    idz_db = Database(c_role, c_password)

    res = idz_db.query(""" SELECT * FROM data.projects; """).fetchall()

    assert len(res) < 3

    res = idz_db.query(""" SELECT * FROM data.rocks """).fetchall()

    assert len(res) == 6

    login(db, s_login_sql)

    create_role_sql = f""" SELECT auth.create_current_user_role('{s_role}', '{s_password}') """

    db.query(create_role_sql).fetchall()

    s_db = Database(s_role, s_password)
    res = s_db.query(""" SELECT * FROM data.projects; """).fetchall()
    assert len(res) == 1
    
    res = s_db.query(""" SELECT * FROM data.rocks """).fetchall()
    assert len(res) == 3

def test_ensure_rls():
    s_db = Database(s_role, s_password)
    name = 'Shanan Edit, no work'
    sql = f""" UPDATE data.projects SET name = '{name}' WHERE id = 1 """
    
    try:
        s_db.conn.cursor().execute(sql)
        assert False
    except:
        assert True

    pg = Database()
    res = pg.query(""" SELECT name FROM data.projects WHERE id = 1 """).fetchone()
    assert res.get('name') != name    

    sql = """ INSERT INTO data.rocks(lithology, time_period, time, project_id)VALUES
                ('dacite', 'devonian', 450, 1); 
          """ 

    try:
        res = s_db.query(sql).fetchall()
        assert False
    except:
        assert True         
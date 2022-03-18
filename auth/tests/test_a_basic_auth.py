from .fixtures import Database, get_sql

def test_db_conn():

    db = Database() ## connect as postgres superuser

    res = db.query("select * from information_schema.tables;").fetchall()

    assert len(res) > 0

def test_run_auth_sql():
    """ runs the auth sql on db """
    sql = get_sql('00-basic_auth.sql')
    db = Database()

    with db.conn.cursor() as cur:
        cur.execute(sql)
    
    sql = """ 
    SELECT rolname FROM pg_catalog.pg_roles WHERE rolinherit = FALSE;
     """
    res = db.query(sql).fetchall()

    for row in res:
        assert row.get('rolname') in ['user1', 'user2', 'user3', 'deleter']

def test_select_rls():
    """ try selecting as diff users and ensuring some rows are hidden """

    db_user1 = Database('user1')

    res = db_user1.query('select * from messages').fetchall()

    # user1 is in each message as at least a from or to user
    assert len(res) == 3 

    for r in res:
        assert r.get('from_user') == 'user1' or r.get('to_user') == 'user1'

    db_user2 = Database('user2')
    res = db_user2.query('select * from messages').fetchall()

    assert len(res) == 2

    db_user3 = Database('user3')
    res = db_user3.query('select * from messages').fetchall()

    assert len(res) == 1

def test_inserts():
    """ test the insert capabilities of users """

    db1, db2, db3 = Database('user1'), Database('user2'), Database('user3')

    sql = """ INSERT INTO messages (from_user, to_user, message) VALUES (
                'user1', 'user2', 'I am the from user so this should work!'
            ) """

    db1.conn.cursor().execute(sql)

    res = db1.query("""select * from messages WHERE message like '%should work%'; """).fetchall()

    assert len(res) == 1 and res[0].get('from_user') == "user1"

    sql = """ INSERT INTO messages (from_user, to_user, message) VALUES (
                'user3', 'user2', 'This is a malicious attack by user1 to try inserting as user3, SHOULD NOT WORK'
            ) """

    try: 
        db1.conn.cursor().execute(sql)
        assert False
    except:
        assert True # insert failed!

    sql = """ INSERT INTO messages (from_user, to_user, message) VALUES (
                'user3', 'user2', 'user1 tried to send you a message from me but it did not work because of ROW LEVEL SECURITY!'
            ) """
    
    db3.conn.cursor().execute(sql)

    res = db3.query("""select * from messages WHERE message like '%ROW LEVEL%'; """).fetchall()

    assert len(res) == 1

def test_delete():
    """ test delete permissions """

    db3, db_deleter = Database('user3'), Database('deleter')

    sql = """ DELETE FROM messages WHERE from_user = 'user1'; """

    try: 
        db3.conn.cursor().execute(sql)
        assert False
    except:
        assert True # deletion failed!

    db_deleter.conn.cursor().execute(sql)

    db = Database()

    res = db.query(""" select * from messages WHERE from_user = 'user1' """).fetchall()
    assert len(res) == 0
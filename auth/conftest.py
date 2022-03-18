from .tests.fixtures import Database, get_sql
import pytest


def pytest_sessionstart():
    db = Database()
    clean = get_sql('clean_up.sql')
    with db.conn.cursor() as cur:
        cur.execute(clean)

import os
from psycopg import connect, rows
from .fixtures import get_sql

db_name = os.environ.get("POSTGRES_DB", "auth_test")
db_conn = os.environ.get("DBCONN", "localhost")
db_port = "5432"
if db_conn == "localhost":
    db_port = "5434"

class Database:
    def __init__(self, user: str = "postgres", autocommit: bool = True) -> None:
        conn_str = f"postgresql://{user}@{db_conn}:{db_port}/{db_name}"
        self.conn = connect(conn_str, autocommit=autocommit, row_factory=rows.dict_row)
    
    def query(self, sql, params=None):
        return self.conn.cursor().execute(sql, params)
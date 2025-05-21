import sqlite3
import os

def init_db(db_path):
    create_table = not os.path.exists(db_path)
    conn = sqlite3.connect(db_path)
    if create_table:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT,
                path TEXT,
                size INTEGER,
                md5sum TEXT
            )
        ''')
        conn.commit()
    conn.close()

def log_file_metadata(db_path, filename, path, size, md5sum):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute('INSERT INTO files (filename, path, size, md5sum) VALUES (?, ?, ?, ?)', 
                (filename, path, size, md5sum))
    conn.commit()
    conn.close()

def query_file_metadata(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute('SELECT filename, path, size, md5sum FROM files')
    rows = cur.fetchall()
    conn.close()
    return [{"filename": row[0], "path": row[1], "size": row[2], "md5sum": row[3]} for row in rows]

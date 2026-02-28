import sqlite3

conn = sqlite3.connect('sibit_app.db')
conn.execute('ALTER TABLE batch ADD COLUMN lokasi TEXT DEFAULT ""')
conn.commit()

cursor = conn.cursor()
cursor.execute('PRAGMA table_info(batch)')
print('Updated columns:', [row[1] for row in cursor.fetchall()])
conn.close()
print('Lokasi column added successfully!')

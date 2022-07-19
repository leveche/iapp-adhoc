#!/usr/bin/env python3

import re
import sys
import sqlite3 as sql

conn = sql.connect('/var/local/db.sqlite3')
cur = conn.cursor()

for line in sys.stdin:
    m = re.match(
            r"""^.* conn=(?P<conn>\d+) op=(?P<op>\d+) .* qtime=(?P<qtime>\d+\.\d+) etime=(?P<etime>\d+\.\d+) nentries=(?P<nentries>\d+).*$"""
            , line)
    if m:
        # print (m.group('conn', 'op', 'qtime', 'etime', 'nentries'))
        cur.execute("INSERT INTO stat values (?, ?, ?, ?, ?)"
                , m.group('conn', 'op', 'qtime', 'etime', 'nentries'))

conn.commit()

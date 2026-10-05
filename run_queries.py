"""
Run every query in sql/ against scn.db and save each result as a Markdown
table in results/. Run generate_data.py first.

Usage:
    python run_queries.py
"""

import sqlite3
from pathlib import Path

ROOT = Path(__file__).parent
con = sqlite3.connect(ROOT / "scn.db")
(ROOT / "results").mkdir(exist_ok=True)


def statements(sql):
    """Split a script into complete statements. Unlike a plain split on ';',
    this is not fooled by a semicolon inside a comment or a string."""
    out, buf = [], ""
    for line in sql.splitlines(keepends=True):
        buf += line
        if sqlite3.complete_statement(buf):
            out.append(buf)
            buf = ""
    if buf.strip():
        out.append(buf)  # last statement had no closing semicolon
    # drop chunks that are only comments or blank lines
    return [s for s in out
            if any(l.strip() and not l.strip().startswith("--") for l in s.splitlines())]


def to_markdown(cursor, rows):
    cols = [d[0] for d in cursor.description]
    fmt = lambda v: "" if v is None else str(v)
    lines = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    lines += ["| " + " | ".join(fmt(v) for v in r) + " |" for r in rows]
    return "\n".join(lines)


for path in sorted((ROOT / "sql").glob("*.sql")):
    if path.name.startswith("00_"):
        continue  # schema is applied by generate_data.py
    outputs = []
    for stmt in statements(path.read_text(encoding="utf-8")):
        try:
            cur = con.execute(stmt)
        except sqlite3.Error as err:
            print(f"\n!! {path.name}: {err}")
            continue
        if cur.description:  # it returned rows
            outputs.append(to_markdown(cur, cur.fetchall()))
    con.commit()
    if outputs:
        out = ROOT / "results" / (path.stem + ".md")
        out.write_text(f"# {path.stem}\n\n" + "\n\n".join(outputs) + "\n", encoding="utf-8")
        print(f"\n== {path.name} ==\n" + "\n\n".join(outputs))

con.close()

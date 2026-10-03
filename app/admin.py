"""
Admin tasks, run from a terminal (never exposed on the public URL).

    python -m app.admin clear-corrections   # before the pitch, so the demo's mark is the first one
    python -m app.admin rebuild-sqlite      # rebuild the local SQLite copy from csv/

Uses DATABASE_URL if set, otherwise the local SQLite file.
"""
import sys

from .db import Database


def main(argv):
    db = Database()
    if argv[:1] == ["clear-corrections"]:
        n = len(db.corrections())
        db.clear_corrections()
        print(f"Cleared corrections ({n} returns had marks) in {db.describe()}")
    elif argv[:1] == ["rebuild-sqlite"]:
        if db.kind != "sqlite":
            sys.exit("DATABASE_URL is set; rebuild-sqlite only touches the local SQLite file.")
        db.sqlite_path.unlink(missing_ok=True)
        db.build_sqlite()
        print(f"Rebuilt {db.sqlite_path}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])

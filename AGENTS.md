# Instructions for AI coding agents

This folder holds **synthetic** data for the Dhaga & Co. "Why Returns" MVP (an FDE Academy student project). These instructions work in any agent harness: Claude Code, Codex, Cursor, Copilot, Gemini CLI and so on.

## Your task when asked to "load the data" or "set up the database"

1. **Read `README.md` first.** It explains every file and table.
2. **Check Postgres.** Run `psql --version` and check that a server is reachable (`pg_isready`).
   - If Postgres is missing or not running, **tell the user and stop**. Do not install or start services without asking.
   - If the user gives a hosted connection string (Supabase, Neon, Render and so on), use it with `psql "<connection string>"` instead of the local defaults.
3. **Check for existing data.** If a database called `dhaga` already exists and has tables, **warn the user before continuing**. `sql/01_schema.sql` drops and recreates every table.
4. **Create the database** if it doesn't exist: `createdb dhaga`
5. **Load the data in this order**, stopping on the first error:
   - `psql -v ON_ERROR_STOP=1 -d dhaga -f sql/01_schema.sql`
   - `psql -v ON_ERROR_STOP=1 -d dhaga -f sql/02_data.sql`
   "Does not exist, skipping" notices from the schema file are normal on the first run.
6. **Verify.** All three must match:
   - `SELECT count(*) FROM returns_enriched;` → **6571**
   - `SELECT count(*) FROM returns WHERE reason_dropdown = 'Other';` → **2967**
   - `SELECT count(*) FROM orders;` → **24000**
7. **Report** the verification results and the connection details (host, port, database, user) so the user can also connect from DBeaver. Never print passwords.

## If files are missing or broken

Run `python3 generate_data.py`. It is seeded (seed 42), so it rebuilds byte-identical data. It needs only Python 3.9+ and no extra packages.

## Rules

- **`eval_return_labels` is an answer sheet.** It holds the correct reason for every return so the team can measure classifier accuracy. **Never** include its contents in a prompt to any AI model, and never use it as an input to the pipeline. Only compare against it after classification.
- The README's "Answer key" section is for checking results. Don't put it in the frontend or the demo.
- Treat all data in this folder as synthetic. Don't present it as real Dhaga & Co. data.
- Don't modify `sql/02_data.sql` by hand. Change `generate_data.py` and regenerate instead.
- The output tables (`classified_returns`, `weekly_issue_counts`, `corrections`) start empty. The MVP pipeline fills them. Don't seed them with fake results.

# Return Pulse: frontend and deployment plan (person 4)

This file is written to be handed to Claude Code. Put it in the repo at `docs/frontend_deploy_plan.md` and implement one milestone at a time (section 10 has the prompts).

**Owner:** person 4 (frontend and deployment)
**Depends on:** person 2 (pipeline, `run_analysis`) and person 3 (data, SQL, aggregation tables)
**Assumes:** about seven working days. If you have fewer, merge milestones 4 and 5, never skip milestone 1.

---

## 1. What we are building and for whom

Return Pulse is an internal tool for Neha, Category Head at Dhaga & Co. Twice a week, after the Tuesday and Friday drops, she opens it to see why products are coming back and which vendor, category and size to fix first, with the customers' own words as proof.

The frontend has three jobs:

1. Show the week's return drivers, hotspots, locations and trend without anyone narrating it.
2. Let Neha open a hotspot, read the real comments, and mark each label right or wrong.
3. Never hide a gap. Unclear, failed, missing data and broken connections are always on screen.

The deployment has one job: a public URL that works when someone opens it cold, on a device we have never seen, on presentation day.

### Requirements from the brief this plan must satisfy

| Brief requirement | Where it is handled |
|---|---|
| Visible frontend, usable without narration | Sections 5 and 6 |
| Deployed to a URL, running when the room opens it | Sections 7 and 9 |
| Built in VS Code, runs locally | Section 8 |
| Fails visibly | Section 6 |
| Cold start in five minutes from the README | Section 8 |
| Deploy something trivial in the first two days | Milestone 1 |
| Human review step designed on purpose | Fix list drill-down, section 5 |

---

## 2. Stack decisions

| Decision | Choice | Why |
|---|---|---|
| UI framework | Streamlit, Python 3.11 | Same language as the pipeline, fast to build dashboards, dataframe row selection and multipage navigation built in. Dev's team can read it. |
| Streamlit version | 1.40 or newer. Pin the exact version you install in `requirements.txt` | Needs `st.navigation`, `st.Page` and `st.dataframe(on_select=...)` |
| Charts | Altair (ships with Streamlit) | Lets us fix one colour per issue across every chart |
| Hosting | Hugging Face Spaces, Docker SDK | The brief names HF Spaces as the shortest path. Docker SDK avoids depending on the Streamlit SDK template and gives us control of the run command. |
| Deploy trigger | GitHub Actions pushes `main` to the Space | One repo per group lives on GitHub. Every merge to `main` redeploys. |
| Results storage | Fixtures (JSON/CSV) or database, chosen by env var | Frontend can be built from day 2 without waiting for the pipeline |
| Corrections storage | Postgres when `DATABASE_URL` is set (free Neon or Supabase), SQLite otherwise | HF Space disks reset on restart. Corrections must survive the demo. |
| Database access | SQLAlchemy + `psycopg[binary]` | One code path for SQLite and Postgres |
| Validation | Pydantic models for every shape crossing the frontend boundary | Matches the brief's structured-output rule and catches contract drift |

Do not add: React, a login system, LangChain in the UI layer, or any new dependency without asking.

---

## 3. Repository layout

The frontend owns `app/`, `fixtures/`, `tests/frontend/`, `Dockerfile`, `.streamlit/`, `.github/workflows/`. It does not edit `pipeline/`.

```
return-pulse/
  README.md                  # HF front matter at top, then the human README
  Dockerfile
  requirements.txt
  .env.example               # every env var, with safe defaults, no real keys
  .streamlit/config.toml     # theme and server settings
  app/
    streamlit_app.py         # entry point, st.navigation, shared sidebar
    config.py                # reads env vars, one Settings object
    contracts.py             # Pydantic models + issue taxonomy (shared with pipeline)
    build_info.json          # written by the deploy workflow, never edited by hand
    data/
      repo.py                # ResultsRepo protocol
      fixture_repo.py        # reads fixtures/
      db_repo.py             # reads person 3's tables
      corrections.py         # CorrectionsStore (Postgres or SQLite)
      pipeline_client.py     # calls pipeline.run_analysis, or the stub
      pipeline_stub.py       # fake run with progress, returns a fixture run_id
    pages/
      this_week.py
      fix_list.py
      locations.py
      trend.py
      accuracy_cost.py
      system_status.py
    ui/
      components.py          # kpi row, issue bar chart, banners, quote card
      copy.py                # every user-facing string in one place
      theme.py               # issue colours, status colours
  fixtures/
    runs.json
    issue_counts.csv
    hotspots.csv
    returns.csv              # 500+ real-shaped rows, Hinglish, typos, junk
    locations.csv
    trend.csv
    summary.json
    accuracy.json
  pipeline/                  # owned by person 2, frontend imports run_analysis only
  docs/
    discovery_note.md
    build_note.md
    data_contract.md         # copy of section 4, agreed on day 2
    frontend_deploy_plan.md  # this file
  tests/
    frontend/
      test_contracts.py
      test_pages.py          # Streamlit AppTest per page
      test_failure_states.py
  .github/workflows/
    ci.yml
    deploy.yml
    keepalive.yml
```

---

## 4. The data contract (agree with persons 2 and 3 on day 2)

This is the most important section for the group. The frontend builds against these shapes using fixtures. Person 3's tables and person 2's pipeline must produce the same shapes. Put the Pydantic models in `app/contracts.py`, and copy this section to `docs/data_contract.md` once agreed.

### Issue taxonomy (shared constant)

```python
ISSUES = [
    ("too_small",       "Too small"),
    ("too_large",       "Too large"),
    ("colour_mismatch", "Colour not as shown"),
    ("fabric_quality",  "Fabric or quality"),
    ("damaged",         "Damaged"),
    ("wrong_item",      "Wrong item sent"),
    ("late_delivery",   "Arrived too late"),
    ("changed_mind",    "Changed mind"),
    ("unclear",         "Unclear"),
]
# "failed" is a status, not an issue. It is always shown separately.
```

### Shapes

**RunSummary**, one per analysis run

| Field | Type | Notes |
|---|---|---|
| run_id | str | |
| week_start | date | Monday of the analysed week |
| created_at | datetime | |
| status | `complete` / `partial` / `failed` | `partial` means some batches failed |
| data_label | `synthetic` / `real` | Drives the demo-data footer |
| total_returns | int | |
| dropdown_count | int | Reason came from the dropdown, no model |
| gate_unclear_count | int | Empty or junk "Other" text, no model |
| cheap_model_count | int | |
| strong_model_count | int | Second opinions |
| unclear_count | int | Final unclear, any source |
| failed_count | int | Validation failed after retry |
| known_reason_share | float | 0 to 1 |
| cost_usd | float | Actual model spend for this run |
| models | dict | `{"cheap": "...", "strong": "..."}` |

**IssueCount**: `run_id, issue, count, share`

**Hotspot**

| Field | Type | Notes |
|---|---|---|
| hotspot_id | str | |
| vendor_id, vendor_name | str | |
| category, size | str | |
| issue | str | From the taxonomy |
| cell_returns | int | All returns in this vendor × category × size |
| issue_returns | int | Returns in the cell with this issue |
| issue_rate | float | issue_returns / cell_returns |
| baseline_rate | float | Same issue's rate across the category |
| ratio | float | issue_rate / baseline_rate |

**ReturnRow**, one classified return

| Field | Type | Notes |
|---|---|---|
| return_id, order_id, sku | str | |
| vendor_id, category, size, city | str | |
| return_date | date | |
| dropdown_reason | str or null | |
| comment_text | str or null | Raw customer text. Untrusted: always escape before rendering |
| issue | str | |
| confidence | float or null | Null for dropdown and gate |
| evidence_span | str or null | Must be an exact substring of comment_text |
| source | `dropdown` / `gate` / `cheap` / `strong` | |
| status | `ok` / `unclear` / `failed` | |
| failure_reason | str or null | Shown on screen when status is failed |
| hotspot_id | str or null | |

**LocationCount**: `run_id, city, issue, count, share_of_city_returns`

**TrendPoint**: `week_start, issue, count, data_label`

**Summary**: `run_id, status (ok / unavailable), lines: list[str], unavailable_reason: str or null`

**Correction**

| Field | Type |
|---|---|
| correction_id | str |
| return_id, run_id | str |
| original_issue | str |
| verdict | `correct` / `wrong` |
| corrected_issue | str or null (required when wrong) |
| reviewer | str |
| created_at | datetime |

**AccuracyReport**: `eval_set_size, eval_accuracy, reviewed_count, reviewed_accuracy, confusion: list[{true_issue, predicted_issue, count}]`

### Interfaces

```python
# app/data/repo.py
class ResultsRepo(Protocol):
    def health(self) -> HealthReport: ...
    def list_runs(self) -> list[RunSummary]: ...
    def get_run(self, run_id: str) -> RunSummary: ...
    def issue_counts(self, run_id: str) -> list[IssueCount]: ...
    def hotspots(self, run_id: str) -> list[Hotspot]: ...
    def hotspot_returns(self, run_id: str, hotspot_id: str) -> list[ReturnRow]: ...
    def returns(self, run_id: str, status: str | None = None) -> list[ReturnRow]: ...
    def locations(self, run_id: str) -> list[LocationCount]: ...
    def trend(self) -> list[TrendPoint]: ...
    def summary(self, run_id: str) -> Summary: ...
    def accuracy(self, run_id: str) -> AccuracyReport: ...

# Owned by person 2. The frontend calls it through app/data/pipeline_client.py.
def run_analysis(
    week_start: date,
    max_rows: int,
    on_progress: Callable[[int, int, str], None],  # done, total, stage label
) -> str:  # run_id
    ...
```

`DATA_SOURCE=fixtures` selects `FixtureRepo`. `DATA_SOURCE=db` selects `DbRepo`. If `pipeline` cannot be imported, `pipeline_client` falls back to `pipeline_stub` and the UI says live analysis is in demo mode.

---

## 5. Screens

General rules for every page:

- The page title is the question it answers, in plain words.
- Every number has its denominator: "212 of 517 returns", not "41%" alone.
- One colour per issue, the same on every chart (`ui/theme.py`).
- Footer on every page when `data_label` is synthetic: "Demo data. Synthetic, shaped like Dhaga's returns."
- The sidebar shows: selected run (week and created time), run status, and a link to System status.
- Default view loads the latest saved run, so the app is useful even if the model API is down.

### 5.1 This week (home): "What is causing returns this week?"

- **KPI row:** returns analysed; reason known (share and count); unclear (count, links to the list); failed (count, links to the list); run cost.
  - Unclear and failed are always shown, even when zero.
- **Return drivers:** horizontal bar chart of issues, sorted by count, with counts on the bars.
- **This week in three lines:** the model summary. If `status == unavailable`, show "Summary unavailable: {reason}. The numbers below are complete." Never hide the panel.
- **Analyse this week** button (section 5.7 for the flow).
- Small "How to read this page" expander with three sentences, for a first-time user.

### 5.2 Fix list: "Which vendor, category and size should we fix first?"

This is the screen the demo is built around. Spend design effort here.

- **Table of hotspots**, sorted by ratio, then issue_returns.
  - Columns: vendor, category, size, issue, returns ("212 of 517"), rate, category baseline, "× baseline".
  - Rows at 2× baseline or above get the attention colour.
- **Selecting a row** opens the drill-down below the table (`st.dataframe(on_select="rerun", selection_mode="single-row")`).
- **Drill-down:**
  - Header sentence: "V07 kurtis in size M: 41% of returns say too small, against 12% for kurtis overall."
  - **Quote cards**, one per return: the customer's comment set large, with the evidence phrase highlighted; below it the label, confidence, and source badge ("Read by cheap model", "Second opinion", "From dropdown").
  - Under each card: **Mark correct** and **Mark wrong**. Mark wrong opens a select box for the right issue and a **Save correction** button. After saving, show "Correction saved" and update the accuracy figure on the page.
  - Show 10 cards, then "Show 10 more".
- **Empty state:** "No hotspots this week. A hotspot needs at least {N} returns and a rate at least {X}× the category baseline. Change thresholds in System status."

### 5.3 Locations: "Which cities have which problem?"

- Table: city × issue, share of that city's returns, with counts.
- Fixed note under the table: "Damaged and wrong-item returns often come from courier or warehouse handling, not the product. Check these with the supply chain team."

### 5.4 Trend: "Is it getting better?"

- Line chart: returns per week for a chosen issue (default: the top issue this week).
- If any point has `data_label == synthetic`: banner "This trend uses synthetic dated data. We don't yet know how much returns history Dhaga holds."
- If fewer than 4 weeks exist: "Not enough weeks to show a trend yet ({n} so far)."

### 5.5 Accuracy and cost: "Can we trust these labels, and what did this cost?"

- **Accuracy against the labelled set:** "{eval_accuracy} on {eval_set_size} comments labelled by hand."
- **Accuracy from Neha's reviews:** "{reviewed_accuracy} on {reviewed_count} labels checked this week."
- **Where it gets confused:** confusion table, largest off-diagonal first ("Fabric or quality labelled as Too small: 7").
- **Run cost:** this run's cost, cost per return analysed, and the yearly projection at 48,000 orders a week with the arithmetic written out on screen. Take numbers from `RunSummary`, not hard-coded.
- **Where the work went:** dropdown / gate / cheap model / second opinion / unclear / failed counts, so the routing is visible.

### 5.6 System status: "Is everything connected?"

This is the Day 1 page. It stays in the app permanently.

- Build: commit SHA and deploy time from `app/build_info.json`, or "local build" if missing.
- Data source: fixtures or database, and the row count of each table it reads.
- Database: reachable or not, with the error message.
- Model API key: configured or not. Never call the API from this page and never show the key.
- Corrections storage: "Saved permanently (Postgres)" or "Saved temporarily. Resets when the app restarts (SQLite)."
- Thresholds: minimum hotspot size, ratio threshold, confidence threshold, read from settings.
- **Admin, behind passcode:** "Clear demo corrections" (used before the pitch).

### 5.7 Live analysis flow

1. **Analyse this week** is disabled with a reason if: no API key ("Live analysis needs a model API key. Showing the last saved run."), or the pipeline isn't connected ("Live analysis is in demo mode").
2. If `APP_PASSCODE` is set, ask for it. The URL is public and every run costs money.
3. **Before running, show an estimate:** "{n} returns this week. About {m} comments will be read by a model. Estimated cost: ${x}." Cap at `MAX_ROWS_PER_RUN` (default 2,000) and say so if capped.
4. Run with `st.status` and a progress bar fed by `on_progress` ("Reading comments: batch 120 of 328").
5. **On finish:**
   - `complete`: switch to the new run.
   - `partial`: switch to it with a banner "{failed} comments could not be read and are listed as failed."
   - Exception: "Analysis stopped: {reason}. Your last saved run is still shown."

---

## 6. Failure states (every one must be visible and tested)

| Condition | What the screen says | Test |
|---|---|---|
| Database unreachable | Red banner on every page: "Can't reach the database: {error}. Showing nothing rather than stale numbers." | `DATABASE_URL` pointing at a closed port |
| No runs exist | "No analysis yet. Run Analyse this week, or load the demo run." | Empty fixtures dir |
| Run status partial | Banner with failed count, link to the failed list | Fixture with `status: partial` |
| Return row failed | Card shows "Couldn't read this comment: {failure_reason}" in place of a label | Fixture row with `status: failed` |
| Return row unclear | Card shows label "Unclear", with the comment, never hidden | Fixture rows |
| Summary unavailable | Panel stays, shows reason, says the numbers below are complete | Fixture summary `unavailable` |
| Model key missing | Analyse disabled with reason, last saved run shown | Unset env var |
| Pipeline import fails | Demo-mode notice, stub used | Rename `pipeline/` locally |
| Corrections on SQLite in the Space | Sidebar notice: corrections reset on restart | Run without `DATABASE_URL` |
| Uploaded CSV has wrong columns (if upload is built) | "Missing columns: {list}. Expected: {list}." | Bad CSV |
| Evidence span not in comment | Show comment without highlight, flag "evidence mismatch" | Fixture row |

Rule: never `st.exception` a raw traceback to Neha. Catch, show a sentence that says what happened and what to do, log the traceback to stdout.

---

## 7. Deployment

### 7.1 Hugging Face Space

- **Create the Space under a group organisation**, not one person's account, so all five can access it. Use the Docker SDK and free CPU hardware.
- **Root `README.md` starts with:**

```yaml
---
title: Return Pulse
emoji: 📦
colorFrom: indigo
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---
```

- **Space secrets (Settings, Variables and secrets):** `LLM_API_KEY` (or whatever person 2 names it), `DATABASE_URL`, `APP_PASSCODE`, `DATA_SOURCE`, `MAX_ROWS_PER_RUN`. Never commit any of these.
- **Set a spending limit on the model provider key**, separate from your personal keys.

### 7.2 Dockerfile

```dockerfile
FROM python:3.11-slim
RUN useradd -m -u 1000 user
USER user
ENV PATH="/home/user/.local/bin:$PATH" PYTHONUNBUFFERED=1
WORKDIR /home/user/app
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt
COPY --chown=user . .
EXPOSE 7860
CMD ["streamlit", "run", "app/streamlit_app.py", \
     "--server.port=7860", "--server.address=0.0.0.0", "--server.headless=true"]
```

### 7.3 GitHub Actions

- **`ci.yml`** runs on every pull request: install, `ruff check`, `pytest tests/frontend`.
- **`deploy.yml`** runs on push to `main`:
  1. Run the tests. Do not deploy on red.
  2. Write `app/build_info.json` with the commit SHA and UTC time.
  3. Commit it on a throwaway branch and force-push to the Space's `main` using `HF_TOKEN` (a GitHub secret with write access to the Space).
  4. Poll the Space URL for up to 10 minutes until `/_stcore/health` returns `ok`. Fail the job if it never does, so a broken deploy is visible in GitHub.
- **`keepalive.yml`** runs on a schedule (every 6 hours) and requests the app URL and `/_stcore/health`.
  - Free Spaces go to sleep after a period without visitors; check the current rule in your Space settings. The ping keeps it awake and tells you early if it died.
  - It does not replace opening the URL yourself before the pitch.

### 7.4 Things that commonly break on Spaces

- **Files over 10 MB** are rejected without Git LFS. Keep fixtures small, or generate the demo database at container start from person 3's seeded generator.
- **The Space disk resets on restart.** Anything written at runtime (corrections, uploaded files) is lost unless it goes to Postgres.
- **CSV upload returns 403 inside the Space.** This is a known issue on some Streamlit-in-Spaces setups. If you hit it, add `--server.enableXsrfProtection=false` to the run command and write down why in the README.
- **The build is slow because `requirements.txt` changed.** Copy requirements before the code (as above) so Docker caches the install layer.

### 7.5 Rollback

- Tag the last known-good commit `demo-ready` whenever the demo path works end to end.
- To roll back, revert on `main` and let `deploy.yml` redeploy. In an emergency, run the deploy workflow manually on the `demo-ready` tag (`workflow_dispatch` with a ref input).

### 7.6 Backup URL (milestone 6, optional but recommended)

Deploy the same Docker image to a second free host (Render or similar) from the same repo. It will also sleep when idle, so open it 30 minutes before the pitch. Put both URLs in the README.

---

## 8. Local cold start (the README section)

A stranger must get this running in five minutes. Fixtures mode needs no keys and no database.

```bash
git clone <repo-url> && cd return-pulse
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # defaults to DATA_SOURCE=fixtures
streamlit run app/streamlit_app.py
```

Also document: `docker build -t return-pulse . && docker run -p 7860:7860 --env-file .env return-pulse`.

The README also needs (brief, section 11): what it does, how to run it, what input it expects, and what it does when something goes wrong (link to the failure table in section 6).

**Test it:** a teammate who hasn't touched the frontend follows the README on their own machine with a timer. Fix whatever slows them down.

---

## 9. Design direction

Internal tool, used by one busy person, twice a week. Clarity first. Spend the design boldness in one place: **the customer's own words on the Fix list.** Everything else is quiet.

**Palette, from the trade:** indigo dye and undyed cotton.

| Token | Hex | Use |
|---|---|---|
| Indigo | `#24346B` | Primary buttons, selected rows, links (`primaryColor`) |
| Ink | `#1A2033` | Body text (`textColor`) |
| White | `#FFFFFF` | Page background |
| Mist | `#EDF0F6` | Sidebar and panels (`secondaryBackgroundColor`) |
| Madder | `#B5322E` | Reserved for "needs attention": hotspots at 2× baseline or above, database errors |
| Turmeric | `#B07A0C` | Unclear, failed, partial-run warnings |

**Issue colours:** a fixed categorical mapping in `ui/theme.py`, used by every chart through an Altair scale with an explicit domain. Unclear is always grey. Don't rely on colour alone: every bar and cell also carries its label and count.

**Type:** Streamlit's default sans-serif. Quote cards set the comment at about 1.25× body size with generous line height. Highlight the evidence phrase with a background tint, not bold.

**Copy rules:** sentence case everywhere. Buttons say what they do: "Analyse this week", "Mark correct", "Mark wrong", "Save correction", "Clear demo corrections". The result message uses the same verb ("Correction saved"). Errors say what happened and what to do, without apology. Keep all strings in `ui/copy.py`.

**Security note:** `comment_text` is customer-written. Escape it before any HTML rendering, or render with plain `st.markdown` and Streamlit's colour-background syntax for the highlight. Never use `unsafe_allow_html=True` on unescaped comment text.

**Check on a phone:** open the deployed URL on a phone browser at least once per milestone. Tables must scroll sideways inside their container; the page must not.

---

## 10. Milestones

Each milestone ends with a deploy to the live URL. Do not start the next one until "Done when" is true.

### Milestone 1, Day 1: a trivial page, live

**Tasks**
- Repo skeleton from section 3: empty pages are fine.
- `config.py`, `build_info.json` reader, `system_status.py` showing build info, data source, and the key/database checks from section 5.6 (database checks can say "not configured" today).
- `.streamlit/config.toml` with the theme from section 9.
- Dockerfile, root README front matter, `.env.example`.
- `ci.yml`, `deploy.yml` (with the health poll), `keepalive.yml`.
- Create the HF Space under the group org, add secrets, add `HF_TOKEN` to GitHub.

**Done when**
- The Space URL opens on a phone and shows the commit SHA of the latest merge.
- A second merge changes the SHA on screen without anyone touching the Space by hand.
- The URL is pinned in the group chat.

### Milestone 2, Day 2: contract agreed, home page on fixtures

**Tasks**
- Meet persons 2 and 3 for 30 minutes. Agree section 4, then commit `docs/data_contract.md` and `app/contracts.py`.
- Write fixtures: at least 500 return rows, real-shaped (Hinglish, typos, "theek nahi", empty, junk). Include the planted V07 kurti size M "too small" hotspot, some unclear rows, some failed rows, one evidence-mismatch row.
  - Write a portion of the comments by hand.
- `FixtureRepo`, `ui/theme.py`, `ui/components.py`, `this_week.py`.
- `tests/frontend/test_contracts.py`: every fixture file validates against the Pydantic models.

**Done when**
- The live URL shows the home page with KPIs, drivers chart and summary from fixtures.
- Unclear and failed counts are visible.
- Contract tests pass in CI.

### Milestone 3, Day 3: Fix list, drill-down, corrections

**Tasks**
- `fix_list.py` with table, row selection, drill-down and quote cards.
- `CorrectionsStore` (Postgres when `DATABASE_URL` is set, else SQLite).
- Accuracy figure on the page updates after a correction.
- Create the free Postgres instance and set `DATABASE_URL` in the Space.

**Done when**
- On the live URL: select the V07 hotspot, read the comments, mark one wrong with a corrected label, see "Correction saved" and the accuracy change.
- Restart the Space: the correction is still there.

### Milestone 4, Day 4: remaining pages and every failure state

**Tasks**
- `locations.py`, `trend.py`, `accuracy_cost.py`.
- Every row in the section 6 table implemented.
- `tests/frontend/test_failure_states.py` and `test_pages.py` using `streamlit.testing.v1.AppTest`: each page renders without exceptions on fixtures and on each failure fixture.

**Done when**
- All six pages work on the live URL.
- Each failure state can be triggered locally and shows its sentence.
- CI green.

### Milestone 5, Day 5: real pipeline and live analysis

**Tasks**
- `DbRepo` against person 3's tables.
- `pipeline_client.py` calling person 2's `run_analysis`, falling back to the stub.
- Live analysis flow from section 5.7: passcode, estimate, cap, progress, outcome handling.
- Switch the Space to `DATA_SOURCE=db`.

**Done when**
- On the live URL: enter the passcode, see the estimate, run a capped analysis, watch progress, land on the new run.
- Kill the API key in the Space: the button disables with its reason and the last run still shows.

### Milestone 6, Day 6: harden

**Tasks**
- Teammate does the timed README cold start. Fix what slowed them down.
- Open the live URL on two devices nobody in the group has used.
- Optional backup URL (section 7.6).
- Tag `demo-ready`.
- Record a 90-second screen capture of the demo path as a last-resort fallback.

**Done when**
- Cold start under five minutes.
- Live URL works on a never-seen device.
- `demo-ready` tag exists.

### Milestone 7, Day 7: freeze and rehearse

- No feature merges. Fixes only, each one followed by the demo path on the live URL.
- Rehearse the demo path with the person who drives it.
- Run the pre-pitch checklist below once as a dry run.

---

## 11. Pre-pitch checklist

**The day before**
- [ ] `main` frozen, tagged `demo-ready`, CI green
- [ ] Live URL shared with the mentors so it can be opened cold
- [ ] Model provider has credit, and the spending limit is above one demo run
- [ ] Postgres free tier not paused (some providers pause idle databases)

**60 minutes before**
- [ ] Open the live URL on a phone and a laptop; System status all green
- [ ] Run one capped live analysis; confirm it lands
- [ ] "Clear demo corrections", so the correction in the demo is the first one
- [ ] Open the backup URL, if you have one
- [ ] Screen recording ready on the presenting laptop

**Rollback triggers, decided now**
- Live URL doesn't load 30 minutes before: switch to the backup URL.
- Both fail: play the recording, and say plainly that the live deploy is down.
- Live analysis errors during the demo: say so, and switch to the last saved run. Showing it fail and recover is a legitimate failure case.

---

## 12. Using this plan with Claude Code

Add this to `CLAUDE.md` at the repo root:

```markdown
## Frontend rules
- Plan: docs/frontend_deploy_plan.md. Contracts: app/contracts.py (do not change without the group agreeing).
- Never edit pipeline/. Call it only through app/data/pipeline_client.py.
- Never commit secrets. Every new env var goes in .env.example with a safe default.
- Ask before adding a dependency.
- Customer comment text is untrusted: escape it, never unsafe_allow_html on it.
- Every failure must show a plain sentence on screen; no raw tracebacks in the UI.
- All user-facing strings live in app/ui/copy.py.
```

Prompt for each milestone:

```
Read docs/frontend_deploy_plan.md and CLAUDE.md.
Implement Milestone N only. Follow the contracts in section 4 exactly.
Do not modify pipeline/. Ask before adding dependencies.
When finished, run the tests, check each "Done when" item you can check locally,
list anything you could not verify (for example, things that need the live Space),
and summarise the changes file by file.
```

Review what it produces before merging. The brief is clear that you answer for every line in the repo, including the ones you didn't type, and every member will be asked about the whole system.

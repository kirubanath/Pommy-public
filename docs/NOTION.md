# Connecting Pommy to Notion

I log every focus and break session to a Notion database that lives in *your* workspace — not mine. Set it up once and forget about it.

## 1. Create the database

In Notion, make a new full-page database. Add these properties exactly as named:

| Property name    | Type   | Notes                             |
|------------------|--------|-----------------------------------|
| `Task`           | Title  | Already there by default.         |
| `Category`       | Select | e.g. `Work`, `Study`, `Personal`. |
| `Type`           | Select | Values: `focus`, `break`.         |
| `Date`           | Date   | The day of the session.           |
| `Duration (min)` | Number | Planned duration in minutes.      |
| `Overflow (min)` | Number | Time past the planned end.        |
| `Device`         | Select | e.g. `MacBook`, `Desktop`.        |
| `Notes`          | Text   | Reflections from the stop sheet.  |

## 2. Create an integration

1. Go to [notion.so/profile/integrations](https://notion.so/profile/integrations).
2. **+ New integration** → name it `Pommy`, scope it to your workspace.
3. Copy the **Internal Integration Token** (starts with `ntn_…` or `secret_…`).

## 3. Share the database with me

In your new database: **• • •** → **Connections** → search `Pommy` → **Confirm**. Without this I can't write anything.

## 4. Paste it in

Open **Settings → Notion** and fill in:

- **Token** — from step 2.
- **Database ID** — the 32-character ID at the end of your database URL:
  `notion.so/<workspace>/<MyDatabase>-`**`abcdef0123…`**`?v=…`
- **Tracker URL** — the full database page URL (used by the *Open Notion* shortcut).

Click **Validate**. If all is well, I'll say "Connected" and start logging from your next session.

## Custom column names

Prefer `Task name` over `Task`? Edit `~/Library/Application Support/Pommy/config/notion_schema.json` and change the `notion_name` for any field. I re-read that file on every save.

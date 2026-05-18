# BillingTool

## Supabase keep-alive (free tier)

Free Supabase projects pause after ~7 days without database activity. A GitHub Action runs twice weekly and performs **one read-only** request (`settings?select=key&limit=1`) — no writes, migrations, or RPCs.

**One-time setup** (GitHub → repo **Settings** → **Secrets and variables** → **Actions**):

| Secret | Value |
|--------|--------|
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Same page → `anon` `public` key |

Use the **Invoicing Cycles** project URL/key if that is the database this app uses. After adding secrets, run **Actions** → **Supabase keep-alive** → **Run workflow** once to verify.

If the project is already paused, restore it in the [Supabase dashboard](https://supabase.com/dashboard) before the workflow can succeed.
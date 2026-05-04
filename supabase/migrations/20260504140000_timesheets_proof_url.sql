-- Optional proof link on timesheets (used by UI and Google Sheet import)
ALTER TABLE timesheets ADD COLUMN IF NOT EXISTS proof_url TEXT;

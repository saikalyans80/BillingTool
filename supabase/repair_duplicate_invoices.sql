-- One-time repair: remove duplicate invoice rows per (consultant_id, billing_cycle_id)
-- so CREATE UNIQUE INDEX invoices_consultant_billing_cycle_key can succeed.
--
-- Run in Supabase SQL editor (as postgres). Order: 1) preview 2) delete 3) create index.

-- ---------------------------------------------------------------------------
-- 1) PREVIEW rows that would be removed (rn > 1)
-- ---------------------------------------------------------------------------
WITH ranked AS (
  SELECT
    id,
    consultant_id,
    billing_cycle_id,
    status,
    invoice_number,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY consultant_id, billing_cycle_id
      ORDER BY
        CASE status
          WHEN 'double_verified' THEN 1
          WHEN 'invoiced_awaiting_verification' THEN 2
          WHEN 'invoiced' THEN 3
          WHEN 'pending' THEN 4
          ELSE 5
        END,
        verified_at DESC NULLS LAST,
        COALESCE(invoice_date::timestamptz, created_at) DESC NULLS LAST,
        created_at DESC,
        id ASC
    ) AS rn
  FROM public.invoices
)
SELECT id, consultant_id, billing_cycle_id, status, invoice_number, created_at, rn
FROM ranked
WHERE rn > 1
ORDER BY consultant_id, billing_cycle_id, rn;

-- ---------------------------------------------------------------------------
-- 2) DELETE duplicates (keeps one row per pair: most finalized / newest)
-- ---------------------------------------------------------------------------
-- Run only after you agree with the preview above.
/*
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY consultant_id, billing_cycle_id
      ORDER BY
        CASE status
          WHEN 'double_verified' THEN 1
          WHEN 'invoiced_awaiting_verification' THEN 2
          WHEN 'invoiced' THEN 3
          WHEN 'pending' THEN 4
          ELSE 5
        END,
        verified_at DESC NULLS LAST,
        COALESCE(invoice_date::timestamptz, created_at) DESC NULLS LAST,
        created_at DESC,
        id ASC
    ) AS rn
  FROM public.invoices
)
DELETE FROM public.invoices
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
*/

-- ---------------------------------------------------------------------------
-- 3) Create unique index (or re-run tail of 20260507120000_fix_profiles_rls_recursion.sql)
-- ---------------------------------------------------------------------------
-- After delete succeeds:
-- CREATE UNIQUE INDEX IF NOT EXISTS invoices_consultant_billing_cycle_key
--   ON public.invoices (consultant_id, billing_cycle_id);

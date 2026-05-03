-- InvoiceFlow: server-side pending invoice generation + idempotency
-- Apply via Supabase SQL editor or `supabase db push`.

-- One open or finalized invoice row per consultant per billing cycle (matches client logic)
CREATE UNIQUE INDEX IF NOT EXISTS invoices_consultant_billing_cycle_key
  ON public.invoices (consultant_id, billing_cycle_id);

CREATE OR REPLACE FUNCTION public.generate_pending_invoices()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (timezone('utc', now()))::date;
  n_inserted int := 0;
BEGIN
  INSERT INTO public.invoices (consultant_id, billing_cycle_id, client_id, status, billing_rate)
  SELECT
    cbc.consultant_id,
    cbc.billing_cycle_id,
    bc.client_id,
    'pending',
    COALESCE(cbc.billing_rate, ccr.billing_rate)
  FROM public.consultant_billing_cycles cbc
  INNER JOIN public.billing_cycles bc ON bc.id = cbc.billing_cycle_id
  LEFT JOIN public.consultant_client_rates ccr
    ON ccr.consultant_id = cbc.consultant_id AND ccr.client_id = bc.client_id
  WHERE bc.end_date < v_today
    AND (cbc.start_date IS NULL OR bc.end_date >= cbc.start_date)
    AND (cbc.end_date IS NULL OR cbc.end_date >= bc.start_date)
    AND NOT EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.consultant_id = cbc.consultant_id
        AND inv.billing_cycle_id = cbc.billing_cycle_id
        AND inv.status IN ('pending', 'invoiced')
    )
  ON CONFLICT (consultant_id, billing_cycle_id) DO NOTHING;

  GET DIAGNOSTICS n_inserted = ROW_COUNT;
  RETURN n_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_pending_invoices() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_pending_invoices() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_pending_invoices() TO service_role;

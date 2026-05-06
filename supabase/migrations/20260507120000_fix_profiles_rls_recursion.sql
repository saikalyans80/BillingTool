-- Fix: profiles_select_admin used EXISTS (SELECT FROM profiles …), which re-entered
-- profiles RLS and caused "infinite recursion detected in policy for relation profiles".
-- Fix: SECURITY DEFINER is_global_admin() reads profiles without RLS.
--
-- Also ensures invoices (consultant_id, billing_cycle_id) unique index exists for
-- generate_pending_invoices() ON CONFLICT. If index creation fails, dedupe first:
--   SELECT consultant_id, billing_cycle_id, count(*) FROM invoices GROUP BY 1,2 HAVING count(*) > 1;

CREATE OR REPLACE FUNCTION public.is_global_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'global_admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_global_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_global_admin() TO authenticated;

DROP POLICY IF EXISTS "profiles_select_admin" ON public.profiles;
CREATE POLICY "profiles_select_admin" ON public.profiles
  FOR SELECT TO authenticated
  USING (public.is_global_admin());

DROP POLICY IF EXISTS "invoices_update_admin" ON public.invoices;
CREATE POLICY "invoices_update_admin" ON public.invoices
  FOR UPDATE TO authenticated
  USING (public.is_global_admin())
  WITH CHECK (public.is_global_admin());

DROP POLICY IF EXISTS "invoices_delete_admin" ON public.invoices;
CREATE POLICY "invoices_delete_admin" ON public.invoices
  FOR DELETE TO authenticated
  USING (public.is_global_admin());

CREATE UNIQUE INDEX IF NOT EXISTS invoices_consultant_billing_cycle_key
  ON public.invoices (consultant_id, billing_cycle_id);

REVOKE ALL ON FUNCTION public.generate_pending_invoices() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_pending_invoices() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_pending_invoices() TO service_role;

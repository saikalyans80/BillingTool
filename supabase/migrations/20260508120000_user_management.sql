-- InvoiceFlow: User Management RPC
-- Allows Global Admins to fetch a list of all users and their roles from auth.users and public.profiles

CREATE OR REPLACE FUNCTION public.get_users_for_admin()
RETURNS TABLE (id UUID, email TEXT, role TEXT, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify the caller is a global admin
  IF NOT public.is_global_admin() THEN
    RAISE EXCEPTION 'Access denied. Only global_admin can view all users.';
  END IF;

  RETURN QUERY
  SELECT 
    u.id, 
    u.email::TEXT, 
    p.role,
    u.created_at
  FROM auth.users u
  LEFT JOIN public.profiles p ON u.id = p.id
  ORDER BY u.created_at DESC;
END;
$$;

-- Revoke execute from public to be safe
REVOKE ALL ON FUNCTION public.get_users_for_admin() FROM PUBLIC;

-- Grant execute to authenticated users (the function internally enforces global_admin)
GRANT EXECUTE ON FUNCTION public.get_users_for_admin() TO authenticated;

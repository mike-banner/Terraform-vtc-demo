import { createClient } from "@supabase/supabase-js";

export function createAdminClient(locals?: App.Locals | Record<string, unknown>) {
  const runtime = (locals as any)?.runtime?.env;
  const key =
    runtime?.SUPABASE_SERVICE_ROLE_KEY ??
    import.meta.env.SUPABASE_SERVICE_ROLE_KEY;
  const url =
    runtime?.PUBLIC_SUPABASE_URL ??
    import.meta.env.PUBLIC_SUPABASE_URL;

  return createClient(
    url,
    key,
  );
}

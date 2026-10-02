// Supabase Edge Function: admin-users
//
// Handles the 3 operations that require the service-role key
// (createUser, resetPassword, deleteUser) — this key must NEVER be
// shipped in the Flutter app, so these run here instead. The function
// re-checks that the CALLER is an admin (via their own JWT) before
// doing anything privileged, so this is safe to call from the app.
//
// Deploy:
//   supabase functions new admin-users        (creates the folder)
//   -> paste this file in as index.ts
//   supabase functions deploy admin-users
//
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
// injected automatically by Supabase — no manual secret-setting needed.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401, headers: cors });
  }

  // Client scoped to the CALLER's own JWT — used only to verify who's calling.
  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await callerClient.auth.getUser();
  const user = userData?.user;
  if (!user) return new Response("Unauthorized", { status: 401, headers: cors });

  const { data: profile } = await callerClient
    .from("profiles")
    .select("tier")
    .eq("id", user.id)
    .single();
  if (profile?.tier !== "admin") {
    return new Response("Forbidden — admin only", { status: 403, headers: cors });
  }

  // Admin client — service role, full privileges. Only used server-side,
  // never returned to the caller.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const body = await req.json();
  const { action } = body;

  try {
    if (action === "listUsers") {
      // Join auth.users (for email — only readable via the service role)
      // with profiles (for username/tier/status/...), keyed by id.
      const { data: authList, error: authErr } = await admin.auth.admin.listUsers({
        perPage: 1000,
      });
      if (authErr) throw authErr;
      const emailById = new Map(authList.users.map((u) => [u.id, u.email ?? ""]));

      const { data: profiles, error: profErr } = await admin
        .from("profiles")
        .select()
        .order("created_at");
      if (profErr) throw profErr;

      const users = (profiles ?? []).map((p: Record<string, unknown>) => ({
        ...p,
        email: emailById.get(p.id as string) ?? "",
      }));
      return new Response(JSON.stringify({ users }), { status: 200, headers: cors });
    }

    if (action === "createUser") {
      const { username, email, password, tier } = body;
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { username },
      });
      if (error) throw error;
      if (tier && tier !== "basic") {
        await admin.from("profiles").update({ tier }).eq("id", data.user!.id);
      }
      return new Response(JSON.stringify({ ok: true, userId: data.user!.id }), {
        status: 200,
        headers: cors,
      });
    }

    if (action === "resetPassword") {
      const { userId, newPassword } = body;
      const { error } = await admin.auth.admin.updateUserById(userId, {
        password: newPassword,
      });
      if (error) throw error;
      return new Response(JSON.stringify({ ok: true }), { status: 200, headers: cors });
    }

    if (action === "deleteUser") {
      const { userId } = body;
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) throw error;
      return new Response(JSON.stringify({ ok: true }), { status: 200, headers: cors });
    }

    return new Response("Unknown action", { status: 400, headers: cors });
  } catch (err) {
    return new Response(String(err?.message ?? err), { status: 400, headers: cors });
  }
});
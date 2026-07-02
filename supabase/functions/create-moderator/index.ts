import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!

    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey)

    const { data: profile, error: profileError } = await adminClient
      .from("users")
      .select("role")
      .eq("id", user.id)
      .single()

    if (profileError || profile?.role !== "admin") {
      return new Response(JSON.stringify({ error: "Only admins can create moderators" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const body = await req.json()
    const name = (body.name as string)?.trim()
    const email = (body.email as string)?.trim().toLowerCase()
    const password = body.password as string
    const phone = ((body.phone as string) || "").trim()

    if (!name || !email || !password) {
      return new Response(JSON.stringify({ error: "Name, email and password are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    if (password.length < 6) {
      return new Response(JSON.stringify({ error: "Password must be at least 6 characters" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { data: existing } = await adminClient
      .from("users")
      .select("id, role")
      .eq("email", email)
      .maybeSingle()

    if (existing) {
      return new Response(JSON.stringify({ error: "Email already registered" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, phone, role: "moderator" },
    })

    if (createError || !created.user) {
      return new Response(JSON.stringify({ error: createError?.message || "Failed to create user" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const newUserId = created.user.id

    await adminClient.from("users").upsert({
      id: newUserId,
      email,
      name,
      phone,
      role: "moderator",
      moderator_active: true,
      promoted_by: user.id,
      promoted_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })

    await adminClient.rpc("log_staff_action", {
      p_actor_id: user.id,
      p_actor_role: "admin",
      p_action: "moderator_created",
      p_entity_type: "user",
      p_entity_id: newUserId,
      p_summary: `Registered new moderator: ${name} (${email})`,
      p_details: { email, name, phone },
    })

    return new Response(
      JSON.stringify({
        success: true,
        user: { id: newUserId, email, name, role: "moderator" },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})

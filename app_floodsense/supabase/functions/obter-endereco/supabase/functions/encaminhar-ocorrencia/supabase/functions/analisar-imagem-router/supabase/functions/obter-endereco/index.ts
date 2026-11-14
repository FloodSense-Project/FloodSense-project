import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(dados: unknown, status = 200) {
  return new Response(JSON.stringify(dados), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return responder({ erro: "Método inválido." }, 405);
  }

  try {
    const autorizacao = req.headers.get("Authorization");

    if (!autorizacao?.startsWith("Bearer ")) {
      return responder({ erro: "Entre na sua conta." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { auth: { persistSession: false } },
    );

    const token = autorizacao.slice(7);
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      return responder({ erro: "Sua sessão expirou. Entre novamente." }, 401);
    }

    let corpo;

    try {
      corpo = await req.json();
    } catch {
      return responder({ erro: "Dados inválidos." }, 400);
    }

    const latitude = corpo?.latitude;
    const longitude = corpo?.longitude;

    if (
      typeof latitude !== "number" ||
      typeof longitude !== "number" ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 ||
      Math.abs(longitude) > 180
    ) {
      return responder({ erro: "Coordenadas inválidas." }, 400);
    }

    const chave = Deno.env.get("OPENCAGE_API_KEY");

    if (!chave) {
      return responder({ erro: "Serviço de endereço não configurado." }, 500);
    }

    const url = new URL("https://api.opencagedata.com/geocode/v1/json");
    url.searchParams.set("key", chave);
    url.searchParams.set("q", `${latitude},${longitude}`);
    url.searchParams.set("language", "pt-BR");
    url.searchParams.set("limit", "1");
    url.searchParams.set("no_annotations", "1");

    const resposta = await fetch(url, {
      signal: AbortSignal.timeout(10000),
    });

    if (!resposta.ok) {
      return responder(
        { erro: "O serviço de endereço está indisponível. Tente novamente." },
        502,
      );
    }

    const resultado = await resposta.json();
    const endereco = resultado.results?.[0]?.formatted;

    if (typeof endereco !== "string" || !endereco.trim()) {
      return responder(
        { erro: "Nenhum endereço encontrado para esta posição." },
        404,
      );
    }

    return responder({ endereco });
  } catch {
    return responder(
      { erro: "Não foi possível consultar o endereço. Tente novamente." },
      502,
    );
  }
});
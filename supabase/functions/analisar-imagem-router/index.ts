
const categorias = [
  "alagamento",
  "buraco",
  "entulho",
  "poste apagado",
  "outro problema urbano",
  "nenhum problema identificável",
  "inconclusivo",
];

const prompt = `
Você é o sistema de visão computacional do FloodSense.

Analise a fotografia e classifique o problema urbano
em exatamente uma das categorias abaixo:

- alagamento
- buraco
- entulho
- poste apagado
- outro problema urbano
- nenhum problema identificável
- inconclusivo

Se houver água de enchente cobrindo uma rua ou
invadindo uma área urbana, classifique como alagamento.

Não invente problemas que não estejam visíveis.

Responda APENAS com JSON:
{"categoria":"nome_da_categoria"}
`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(dados: object, status = 200) {
  return new Response(JSON.stringify(dados), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function extrairCategoria(texto: string): string {
  const encontrado = texto.match(/\{[\s\S]*?\}/);

  if (!encontrado) {
    throw new Error("Resposta sem JSON");
  }

  const dados = JSON.parse(encontrado[0]);

  if (!categorias.includes(dados.categoria)) {
    throw new Error("Categoria inválida");
  }

  return dados.categoria;
}

async function chamarIA(
  provedor: string,
  chave: string,
  base64: string,
  mimeType: string
) {
  const imagem = `data:${mimeType};base64,${base64}`;

  let url: string;
  let headers: Record<string, string>;
  let body: object;

  if (provedor === "Gemini") {
    url =
      "https://generativelanguage.googleapis.com/v1beta/" +
      "models/gemini-3.5-flash-lite:generateContent";

    headers = {
      "Content-Type": "application/json",
      "x-goog-api-key": chave,
    };

    body = {
      contents: [{
        parts: [
          {
            inline_data: {
              mime_type: mimeType,
              data: base64,
            },
          },
          { text: prompt },
        ],
      }],
      generationConfig: {
        responseMimeType: "application/json",
      },
    };
  } else {
    url = provedor === "Groq"
      ? "https://api.groq.com/openai/v1/chat/completions"
      : "https://openrouter.ai/api/v1/chat/completions";

    headers = {
      "Content-Type": "application/json",
      Authorization: `Bearer ${chave}`,
    };

    const modelo = provedor === "Groq"
      ? "qwen/qwen3.8-27b"
      : "nvidia/nemotron-3.5-super-vl:free";

    body = {
      model: modelo,
      messages: [{
        role: "user",
        content: [
          { type: "text", text: prompt },
          {
            type: "image_url",
            image_url: { url: imagem },
          },
        ],
      }],
      temperature: 0,
      max_tokens: 512,
    };
  }

  const resposta = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20000),
  });

  if (!resposta.ok) {
    throw new Error(`HTTP ${resposta.status}`);
  }

  const dados = await resposta.json();

  let texto: string;

  if (provedor === "Gemini") {
    const partes = dados.candidates?.[0]?.content?.parts;

    texto = Array.isArray(partes)
      ? partes.map((p: { text?: string }) => p.text || "").join("")
      : "";
  } else {
    const conteudo = dados.choices?.[0]?.message?.content;

    texto = typeof conteudo === "string"
      ? conteudo
      : Array.isArray(conteudo)
        ? conteudo.map((p: { text?: string }) => p.text || "").join("")
        : "";
  }

  if (!texto.trim()) {
    throw new Error("Resposta vazia");
  }

  return extrairCategoria(texto);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return responder(
      { sucesso: false, erro: "Método não permitido" },
      405
    );
  }

  try {
    const dados = await req.json();
    const mimeType = dados.mimeType || "image/jpeg";

    if (!["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
      return responder({
        sucesso: false,
        erro: "Formato de imagem inválido",
      }, 400);
    }

    if (typeof dados.base64 !== "string") {
      return responder({
        sucesso: false,
        erro: "Nenhuma imagem enviada",
      }, 400);
    }

    const base64 = dados.base64
      .replace(/^data:image\/[^;]+;base64,/, "")
      .replace(/\s/g, "");

    if (!base64) {
      return responder({
        sucesso: false,
        erro: "Imagem vazia",
      }, 400);
    }

    if (base64.length > 9000000) {
      return responder({
        sucesso: false,
        erro: "Imagem muito grande",
      }, 413);
    }

    const provedores = [
      {
        nome: "Groq",
        chave: Deno.env.get("GROQ_API_KEY"),
      },
      {
        nome: "Gemini",
        chave: Deno.env.get("GEMINI_API_KEY"),
      },
      {
        nome: "OpenRouter",
        chave: Deno.env.get("OPENROUTER_API_KEY"),
      },
    ];

    const tentativas = [];

    for (const provedor of provedores) {
      if (!provedor.chave) {
        tentativas.push({
          provedor: provedor.nome,
          erro: "Chave não configurada",
        });
        continue;
      }

      try {
        const categoria = await chamarIA(
          provedor.nome,
          provedor.chave,
          base64,
          mimeType
        );

        return responder({
          sucesso: true,
          categoria,
          ehAlagamento: categoria === "alagamento",
          provedor: provedor.nome,
        });
      } catch (erro) {
        const mensagem = erro instanceof Error
          ? erro.message
          : "Erro desconhecido";

        console.error(`Falha em ${provedor.nome}: ${mensagem}`);

        tentativas.push({
          provedor: provedor.nome,
          erro: mensagem,
        });
      }
    }

    return responder({
      sucesso: false,
      erro: "Nenhuma IA conseguiu analisar a imagem",
      tentativas,
    }, 503);

  } catch (erro) {
    console.error("Erro no router:", String(erro));

    return responder({
      sucesso: false,
      erro: "Erro ao processar a requisição",
    }, 400);
  }
});

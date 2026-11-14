import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@7";
import { Buffer } from "node:buffer";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const statusEncaminhada = "ENCAMINHADA AO ÓRGÃO RESPONSÁVEL";

function responder(dados: unknown, status = 200) {
  return new Response(JSON.stringify(dados), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
function textoSeguro(valor: unknown): string {
  return String(valor ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return responder({ erro: "Método inválido." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const smtpUser = Deno.env.get("SMTP_USER")?.trim();
  const smtpPass = Deno.env.get("SMTP_PASS")?.replace(/\s/g, "");
  const destinatario = Deno.env.get("EMAIL_DESTINO")?.trim();

  if (
    !supabaseUrl || !serviceKey ||
    !smtpUser || !smtpPass || !destinatario
  ) {
    return responder({ erro: "Configuração de envio incompleta." }, 500);
  }

  const banco = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let idOcorrencia: number | null = null;
  let envioReservado = false;
  let emailConfirmado = false;
  let etapa = "autenticação";

  try {
    const autorizacao = req.headers.get("Authorization");

    if (!autorizacao?.startsWith("Bearer ")) {
      return responder({ erro: "Entre na sua conta." }, 401);
    }

    const { data: sessao, error: erroSessao } =
      await banco.auth.getUser(autorizacao.slice(7));

    if (erroSessao || !sessao.user) {
      return responder({ erro: "Sessão inválida. Entre novamente." }, 401);
    }

    const corpo = await req.json().catch(() => null);
    const id = corpo?.id_ocorrencia;

    if (!Number.isSafeInteger(id) || id <= 0) {
      return responder({ erro: "Número de registro inválido." }, 400);
    }

    idOcorrencia = id;
    etapa = "consulta da ocorrência";

    const { data: ocorrencia, error: erroOcorrencia } = await banco
      .from("ocorrencia")
      .select("id_ocorrencia, descricao, latitude, longitude")
      .eq("id_ocorrencia", id)
      .eq("id_usuario", sessao.user.id)
      .maybeSingle();

    if (erroOcorrencia) throw erroOcorrencia;

    if (!ocorrencia) {
      return responder({ erro: "Ocorrência não encontrada." }, 404);
    }

    const { data: controle, error: erroControle } = await banco
      .from("envio_ocorrencia")
      .select("estado")
      .eq("id_ocorrencia", id)
      .maybeSingle();

    if (erroControle) throw erroControle;

    if (controle?.estado === "ENVIADO") {
      const { error } = await banco
        .from("ocorrencia")
        .update({ status: statusEncaminhada })
        .eq("id_ocorrencia", id)
        .select("id_ocorrencia")
        .single();

      if (error) throw error;

      return responder({
        enviado: true,
        mensagem: "O e-mail já foi enviado. Status atualizado.",
      });
    }

    if (controle) {
      return responder({
        erro: "Este envio está em andamento ou precisa de conferência.",
      }, 409);
    }

    etapa = "conferência da análise";

    const { data: analises, error: erroAnalise } = await banco
      .from("analise_ia")
      .select("classificacao")
      .eq("id_ocorrencia", id)
      .eq("resultado", "APROVADA")
      .limit(1);

    if (erroAnalise) throw erroAnalise;

    if (!analises?.length) {
      return responder({
        erro: "A ocorrência ainda não tem uma análise aprovada.",
      }, 409);
    }

    etapa = "leitura da foto";

    const { data: imagem, error: erroImagem } = await banco
      .from("imagem")
      .select("caminho_imagem")
      .eq("id_ocorrencia", id)
      .limit(1)
      .maybeSingle();

    if (erroImagem) throw erroImagem;

    if (!imagem?.caminho_imagem) {
      return responder({ erro: "Foto da ocorrência não encontrada." }, 404);
    }

    const urlFoto = new URL(imagem.caminho_imagem);
    const origemSupabase = new URL(supabaseUrl);
    const prefixo = "/storage/v1/object/public/ocorrencias/";

    if (
      urlFoto.origin !== origemSupabase.origin ||
      !urlFoto.pathname.startsWith(prefixo)
    ) {
      return responder({ erro: "Caminho da foto inválido." }, 400);
    }

    const caminhoFoto = decodeURIComponent(
      urlFoto.pathname.slice(prefixo.length),
    );

    if (!caminhoFoto.startsWith(`${sessao.user.id}/`)) {
      return responder({ erro: "Foto incompatível com o usuário." }, 403);
    }

    const { data: arquivo, error: erroArquivo } = await banco.storage
      .from("ocorrencias")
      .download(caminhoFoto);

    if (erroArquivo || !arquivo) {
      return responder({ erro: "Não foi possível carregar a foto." }, 502);
    }

    if (arquivo.size > 10 * 1024 * 1024) {
      return responder({ erro: "A foto excede o limite de 10 MB." }, 400);
    }

    const latitude = Number(ocorrencia.latitude);
    const longitude = Number(ocorrencia.longitude);

    if (
      ocorrencia.latitude == null ||
      ocorrencia.longitude == null ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 ||
      Math.abs(longitude) > 180
    ) {
      return responder({ erro: "Localização inválida." }, 400);
    }

    let endereco = `${latitude}, ${longitude}`;

    try {
      const consulta = await banco.functions.invoke("obter-endereco", {
        headers: { Authorization: autorizacao },
        body: { latitude, longitude },
      });

      if (!consulta.error && consulta.data?.endereco) {
        endereco = consulta.data.endereco;
      }
    } catch {
      // As coordenadas continuam disponíveis se a consulta falhar.
    }

    const { count: numeroUsuario, error: erroNumero } = await banco
      .from("ocorrencia")
      .select("id_ocorrencia", { count: "exact", head: true })
      .eq("id_usuario", sessao.user.id)
      .lte("id_ocorrencia", id);

    if (erroNumero) throw erroNumero;

    etapa = "reserva do envio";

    const { error: erroReserva } = await banco
      .from("envio_ocorrencia")
      .insert({ id_ocorrencia: id, estado: "PROCESSANDO" });

    if (erroReserva?.code === "23505") {
      return responder({
        erro: "Já existe uma tentativa de envio para esta ocorrência.",
      }, 409);
    }

    if (erroReserva) throw erroReserva;
    envioReservado = true;

    const transporte = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user: smtpUser, pass: smtpPass },
      connectionTimeout: 15000,
      greetingTimeout: 15000,
      socketTimeout: 30000,
    });

    const mapa = new URL("https://www.google.com/maps/search/");
    mapa.searchParams.set("api", "1");
    mapa.searchParams.set("query", `${latitude},${longitude}`);

    etapa = "envio pelo Gmail";
    
    const dataEnvio = new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone: "America/Sao_Paulo",
  }).format(new Date());

    const htmlEmail = `
    <!DOCTYPE html>
    <html lang="pt-BR">
    <body style="margin:0;padding:0;background:#e8f7ff;font-family:Arial,sans-serif;color:#334155;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
       <tr>
        <td align="center" style="padding:24px 12px;">
         <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
          style="max-width:640px;background:#ffffff;border-radius:20px;overflow:hidden;">

          <tr>
            <td style="padding:30px;background:#0754a5;color:#ffffff;">
              <p style="margin:0 0 8px;font-size:28px;font-weight:bold;">
                FloodSense
              </p>
              <p style="margin:0;font-size:15px;line-height:1.5;">
                Monitoramento e registro de alagamentos
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:28px;">
              <p style="margin:0 0 10px;color:#0754a5;font-size:24px;font-weight:bold;">
                Nova ocorrência aprovada
              </p>
              <p style="margin:0 0 20px;line-height:1.6;">
                Uma ocorrência passou pela análise de imagem e está
                disponível para avaliação da equipe responsável.
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                style="background:#f0f7ff;border-radius:12px;">
                <tr>
                  <td style="padding:18px;line-height:1.8;">
                    <strong>Ocorrência:</strong> ${textoSeguro(numeroUsuario)}<br>
                    <strong>Identificador interno:</strong> ${textoSeguro(id)}<br>
                    <strong>Data do encaminhamento:</strong> ${textoSeguro(dataEnvio)} — Brasília<br>
                    <strong>Análise de imagem:</strong> APROVADA<br>
                    <strong>Classificação:</strong>
                    ${textoSeguro(analises[0].classificacao || "Não informada")}
                  </td>
                </tr>
              </table>

              <h2 style="margin:26px 0 10px;color:#0754a5;font-size:18px;">
                Descrição da ocorrência
              </h2>
              <p style="margin:0;line-height:1.7;white-space:pre-wrap;overflow-wrap:anywhere;">${textoSeguro(ocorrencia.descricao || "Sem descrição")}</p>

              <h2 style="margin:26px 0 10px;color:#0754a5;font-size:18px;">
                Localização
              </h2>
              <p style="margin:0 0 8px;line-height:1.7;">
                ${textoSeguro(endereco)}
              </p>
              <p style="margin:0;font-size:13px;color:#64748b;">
                Latitude: ${textoSeguro(latitude)}<br>
                Longitude: ${textoSeguro(longitude)}
              </p>

              <table role="presentation" cellpadding="0" cellspacing="0"
                style="margin-top:20px;">
                <tr>
                  <td style="background:#ff861d;border-radius:10px;">
                    <a href="${textoSeguro(mapa.toString())}"
                      style="display:inline-block;padding:15px 22px;color:#ffffff;text-decoration:none;font-weight:bold;">
                      Ver localização no mapa
                    </a>
                  </td>
                </tr>
              </table>

              <h2 style="margin:28px 0 14px;color:#0754a5;font-size:18px;">
                Foto da ocorrência
              </h2>
              <img src="cid:foto-ocorrencia"
                alt="Foto enviada com a ocorrência"
                width="560"
                style="display:block;width:100%;max-width:560px;height:auto;border:2px solid #d7e7f0;border-radius:14px;">

              <p style="margin:14px 0 0;font-size:13px;color:#64748b;line-height:1.6;">
                A imagem também acompanha este e-mail como anexo.
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:20px 28px;background:#f0f7ff;font-size:12px;line-height:1.7;color:#64748b;">
              Mensagem automática do FloodSense.<br>
              Para identificar este registro, utilize o identificador interno
              ${textoSeguro(id)}.
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;

    const confirmacao = await transporte.sendMail({
      from: { name: "FloodSense", address: smtpUser },
      to: destinatario,
      html: htmlEmail,
      subject: `FloodSense — Ocorrência ${numeroUsuario}`,
      text: [
        `Ocorrência ${numeroUsuario}`,
        `Identificador interno: ${id}`,
        "",
        "Descrição:",
        ocorrencia.descricao || "Sem descrição",
        "",
        `Localização: ${endereco}`,
        `Coordenadas: ${latitude}, ${longitude}`,
        `Mapa: ${mapa.toString()}`,
        "",
        `Análise aprovada. Classificação: ${
          analises[0].classificacao || "Não informada"
        }`,
        "",
        "A foto da ocorrência está anexada.",
      ].join("\n"),
      attachments: [{
        filename: caminhoFoto.split("/").pop() || "foto",
        content: Buffer.from(await arquivo.arrayBuffer()),
        contentType: arquivo.type || "application/octet-stream",
        cid: "foto-ocorrencia",
      }],
    });

    if (!confirmacao.accepted?.length) {
      throw new Error("Envio sem confirmação do servidor.");
    }

    emailConfirmado = true;
    etapa = "confirmação do envio";

    const { error: erroConfirmacao } = await banco
      .from("envio_ocorrencia")
      .update({
        estado: "ENVIADO",
        enviado_em: new Date().toISOString(),
      })
      .eq("id_ocorrencia", id)
      .select("id_ocorrencia")
      .single();

    if (erroConfirmacao) throw erroConfirmacao;

    etapa = "atualização do status";

    const { error: erroStatus } = await banco
      .from("ocorrencia")
      .update({ status: statusEncaminhada })
      .eq("id_ocorrencia", id)
      .select("id_ocorrencia")
      .single();

    if (erroStatus) throw erroStatus;

    return responder({
      enviado: true,
      mensagem: "Ocorrência encaminhada ao órgão responsável.",
    });
  } catch {
    console.error(`Falha no encaminhamento durante: ${etapa}`);

    if (envioReservado && idOcorrencia !== null) {
      await banco
        .from("envio_ocorrencia")
        .update({ estado: "INCERTO" })
        .eq("id_ocorrencia", idOcorrencia)
        .eq("estado", "PROCESSANDO");
    }

    return responder({
      enviado: emailConfirmado,
      erro: emailConfirmado
        ? "E-mail enviado, mas a atualização do registro precisa de conferência."
        : `Falha durante ${etapa}. Confira os registros da função antes de repetir.`,
    }, 502);
  }
});
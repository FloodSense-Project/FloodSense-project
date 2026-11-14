-- FloodSense. Executar em um projeto Supabase apos database/schema.sql.
-- Complemento baseado na configuracao exportada em 14/11/2026.
-- Contem estrutura e politicas. Os registros e segredos sao configurados separadamente.
BEGIN;

ALTER TABLE public.usuario ALTER COLUMN nome SET DEFAULT '';
ALTER TABLE public.usuario ALTER COLUMN email SET DEFAULT '';

CREATE TABLE IF NOT EXISTS public.envio_ocorrencia (
    id_ocorrencia BIGINT PRIMARY KEY REFERENCES public.ocorrencia(id_ocorrencia) ON DELETE CASCADE,
    estado TEXT NOT NULL DEFAULT 'PROCESSANDO'
        CHECK (estado IN ('PROCESSANDO', 'ENVIADO', 'INCERTO')),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    enviado_em TIMESTAMPTZ
);

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.usuario (
    id_usuario,
    nome,
    email
  )
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'nome', ''),
      'Usuário'
    ),
    NEW.email
  );

  RETURN NEW;
END;
$function$
;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS habilitada explicitamente nas tabelas do aplicativo.
ALTER TABLE public.usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocorrencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.imagem ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analise_ia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.envio_ocorrencia ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.envio_ocorrencia FROM anon, authenticated;
GRANT ALL ON TABLE public.envio_ocorrencia TO service_role;
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT SELECT, INSERT ON public.usuario, public.ocorrencia, public.imagem, public.analise_ia TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.ocorrencia_id_ocorrencia_seq,
    public.imagem_id_imagem_seq, public.analise_ia_id_analise_seq TO authenticated;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('ocorrencias', 'ocorrencias', true, NULL, NULL)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Politicas preservadas conforme a exportacao recebida.
DROP POLICY IF EXISTS "usuarios_criam_proprio_perfil" ON "public"."usuario";
CREATE POLICY "usuarios_criam_proprio_perfil" ON "public"."usuario" AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((( SELECT auth.uid() AS uid) = id_usuario));

DROP POLICY IF EXISTS "usuarios_visualizam_proprio_perfil" ON "public"."usuario";
CREATE POLICY "usuarios_visualizam_proprio_perfil" ON "public"."usuario" AS PERMISSIVE FOR SELECT TO authenticated
USING ((( SELECT auth.uid() AS uid) = id_usuario));

DROP POLICY IF EXISTS "usuarios_enviam_fotos 1mzt4m4_0" ON "storage"."objects";
CREATE POLICY "usuarios_enviam_fotos 1mzt4m4_0" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((bucket_id = 'ocorrencias'::text));

DROP POLICY IF EXISTS "usuarios_criam_proprias_ocorrencias" ON "public"."ocorrencia";
CREATE POLICY "usuarios_criam_proprias_ocorrencias" ON "public"."ocorrencia" AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((( SELECT auth.uid() AS uid) = id_usuario));

DROP POLICY IF EXISTS "usuarios_visualizam_proprias_ocorrencias" ON "public"."ocorrencia";
CREATE POLICY "usuarios_visualizam_proprias_ocorrencias" ON "public"."ocorrencia" AS PERMISSIVE FOR SELECT TO authenticated
USING ((( SELECT auth.uid() AS uid) = id_usuario));

DROP POLICY IF EXISTS "usuarios_criam_proprias_imagens" ON "public"."imagem";
CREATE POLICY "usuarios_criam_proprias_imagens" ON "public"."imagem" AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((EXISTS ( SELECT 1
   FROM ocorrencia o
  WHERE ((o.id_ocorrencia = imagem.id_ocorrencia) AND (o.id_usuario = ( SELECT auth.uid() AS uid))))));

DROP POLICY IF EXISTS "usuarios_visualizam_proprias_imagens" ON "public"."imagem";
CREATE POLICY "usuarios_visualizam_proprias_imagens" ON "public"."imagem" AS PERMISSIVE FOR SELECT TO authenticated
USING ((EXISTS ( SELECT 1
   FROM ocorrencia o
  WHERE ((o.id_ocorrencia = imagem.id_ocorrencia) AND (o.id_usuario = ( SELECT auth.uid() AS uid))))));

DROP POLICY IF EXISTS "usuarios_inserem_analises_proprias" ON "public"."analise_ia";
CREATE POLICY "usuarios_inserem_analises_proprias" ON "public"."analise_ia" AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK ((EXISTS ( SELECT 1
   FROM ocorrencia o
  WHERE ((o.id_ocorrencia = analise_ia.id_ocorrencia) AND (o.id_usuario = ( SELECT auth.uid() AS uid))))));

DROP POLICY IF EXISTS "usuarios_visualizam_proprias_analises" ON "public"."analise_ia";
CREATE POLICY "usuarios_visualizam_proprias_analises" ON "public"."analise_ia" AS PERMISSIVE FOR SELECT TO authenticated
USING ((EXISTS ( SELECT 1
   FROM ocorrencia o
  WHERE ((o.id_ocorrencia = analise_ia.id_ocorrencia) AND (o.id_usuario = ( SELECT auth.uid() AS uid))))));

COMMIT;

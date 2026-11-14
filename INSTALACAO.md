# Instalação do FloodSense

## Requisitos para executar a versão web

- Git.
- Flutter SDK com Dart compatível com `^3.13.4`, conforme `app_floodsense/pubspec.yaml`.
- Google Chrome.
- VS Code com as extensões Flutter e Dart, se usar esse editor.
- Um projeto Supabase configurado conforme as etapas abaixo.

Execute no terminal para conferir a instalação.

```powershell
git --version
flutter --version
flutter doctor
```

## Baixar e abrir o aplicativo

```powershell
git clone --branch tiago/banco-supabase --single-branch https://github.com/andre-fernandes1943/FloodSense-project.git
cd FloodSense-project/app_floodsense
flutter pub get
flutter run -d chrome --web-port=8080
```

Abra `http://localhost:8080/`. Autorize a localização quando o navegador solicitar. O comando `flutter pub get` baixa as dependências declaradas no projeto.

Para gerar a versão web compilada, execute dentro de `app_floodsense`.

```powershell
flutter build web
```

Os arquivos gerados ficam em `app_floodsense/build/web`. Para publicar o aplicativo, essa pasta precisa ser disponibilizada em uma hospedagem web com HTTPS.

## Configurar um novo projeto Supabase

### Banco e armazenamento

No SQL Editor do novo projeto, execute os arquivos nesta ordem.

1. `database/schema.sql`.
2. `database/002_configuracao_supabase.sql`.

O primeiro arquivo cria as tabelas iniciais. O segundo adiciona o controle de envio de e-mail, o gatilho de criação de perfil, as políticas de acesso e o bucket `ocorrencias`.

O bucket está configurado como público, conforme o ambiente de teste. Quem tiver a URL pública de uma foto poderá acessá-la. Os arquivos SQL representam a estrutura e a configuração exportada. Os usuários, as ocorrências e as fotos existentes precisam de uma migração separada se forem necessários no novo projeto.

### Funções do backend

No painel de Edge Functions do Supabase, crie e publique as funções abaixo usando o conteúdo dos respectivos arquivos.

| Nome da função | Arquivo |
| --- | --- |
| `analisar-imagem-router` | `supabase/functions/analisar-imagem-router/index.ts` |
| `obter-endereco` | `supabase/functions/obter-endereco/index.ts` |
| `encaminhar-ocorrencia` | `supabase/functions/encaminhar-ocorrencia/index.ts` |

As opções de autenticação do gateway das funções precisam ser conferidas no projeto de destino. Essa configuração do painel ainda precisa ser documentada e validada em uma instalação nova. As funções `obter-endereco` e `encaminhar-ocorrencia` também verificam o usuário no próprio código. O roteador de IA depende da proteção configurada no gateway.

### Segredos das funções

Cadastre os valores no painel de segredos das Edge Functions do projeto.

| Nome | Valor esperado |
| --- | --- |
| `OPENCAGE_API_KEY` | Chave OpenCage para converter coordenadas em endereço |
| `SMTP_USER` | Conta Gmail usada para enviar as ocorrências |
| `SMTP_PASS` | Senha de aplicativo dessa conta Google |
| `EMAIL_DESTINO` | E-mail que receberá as ocorrências |
| `GROQ_API_KEY` | Chave Groq, se esse provedor for utilizado |
| `GEMINI_API_KEY` | Chave Gemini, se esse provedor for utilizado |
| `OPENROUTER_API_KEY` | Chave OpenRouter, se esse provedor for utilizado |

Configure pelo menos um dos três provedores de IA. O código tenta Groq, Gemini e OpenRouter nessa ordem e pula provedores sem chave. A disponibilidade depende das contas, modelos e cotas dos serviços contratados.

As funções também usam `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY`, disponibilizados pelo ambiente Supabase hospedado. A chave `service_role` deve permanecer no backend.

O envio de ocorrências usa Gmail SMTP na porta 465 com TLS. A conta precisa permitir senha de aplicativo. Neste protótipo, configure `EMAIL_DESTINO` com o e-mail da FloodSense. O texto exibido no app é “ENCAMINHADA AO ÓRGÃO RESPONSÁVEL”, enquanto o destinatário real é o endereço configurado.

### Conectar o Flutter ao projeto

Em `app_floodsense/lib/main.dart`, localize `Supabase.initialize` e configure a URL e a chave pública do projeto de destino. Use a chave pública de cliente nesse arquivo.

### Cadastro e recuperação de senha

No painel de Authentication do Supabase, configure a URL do site e a URL de redirecionamento permitida para o teste local como `http://localhost:8080/`.

Configure o SMTP de Authentication com a conta remetente e sua senha de aplicativo. Essa configuração de e-mails de autenticação é separada dos segredos usados pela função de encaminhamento.

No template de recuperação de senha, o link usado pelo aplicativo é o seguinte.

```html
<a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&amp;type=recovery">Redefinir minha senha</a>
```

O arquivo `app_floodsense/lib/Tela_inicial.dart` contém o redirecionamento `http://localhost:8080/`. Ao hospedar o aplicativo, atualize esse endereço no código e nas URLs permitidas do Supabase para o endereço HTTPS publicado.

## Conferir o funcionamento

1. Criar uma conta, concluir a confirmação de e-mail se habilitada e fazer login.
2. Solicitar recuperação de senha e testar o link recebido.
3. Permitir a localização e conferir o endereço mostrado.
4. Selecionar uma foto e registrar uma ocorrência aprovada pela IA.
5. Conferir a ocorrência em “Minhas ocorrências”, abrir os detalhes e verificar foto e status.
6. Conferir o marcador no mapa.
7. Confirmar o recebimento do e-mail com foto, descrição e localidade no destinatário configurado.

O controle `envio_ocorrencia` evita reenvio automático do mesmo registro. Se o estado ficar `PROCESSANDO` ou `INCERTO`, confira os logs da função e a caixa de entrada antes de tentar resolver o envio. A tela de cadastro envia uma nova ocorrência quando o formulário é preenchido novamente.

## Estado da validação

A compilação web foi concluída no ambiente de desenvolvimento. A instalação em um projeto Supabase vazio e a entrega completa do e-mail ainda precisam ser verificadas com o roteiro acima.

O teste padrão de contador em `app_floodsense/test/widget_test.dart` ainda precisa ser adaptado ao aplicativo. Há avisos do analisador sobre nomes de arquivos Dart. A execução em Android e iOS precisa de configuração e testes próprios, incluindo permissões nativas de câmera, fotos e localização.

A aprovação é atualmente gravada pelo cliente na tabela `analise_ia`. Para garantir a validação em um ambiente de produção, a análise e a autorização de encaminhamento precisam ser controladas pelo backend.

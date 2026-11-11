# CertiFeasy 🎓

O **CertiFeasy** é um gerador de certificados em lote feito em Flutter, pensado para eventos, cursos e workshops. Ele roda no navegador em **https://certifeasy.vercel.app** e também pode ser compilado como app de desktop ou celular.

Você envia a arte do certificado (frente e, se quiser, verso), carrega a lista de participantes em CSV, escreve o texto com as variáveis de cada pessoa e gera tudo de uma vez: em **PDF** para impressão, em **ZIP com PNGs** ou **por e-mail**, com o certificado de cada participante anexado.

---

## ✨ Funcionalidades

- **Geração em lote via CSV, TSV ou Excel:** cada linha vira um certificado. Os CSVs tradicionais continuam aceitando separadores `;` ou `,` e **exigindo** `nome`, `evento`, `data`, `horas` e `email`. Para apresentação de trabalhos, planilhas com `orientador` e `nome_trabalho` também podem ser importadas **sem a coluna `horas`** — ela fica vazia somente nesse caso. Arquivos tabulados `.tsv` ou `.txt`, arquivos Excel modernos `.xlsx` e arquivos legados `.xls` (Excel 97–2003) também são aceitos. A importação lê a primeira aba com cabeçalhos válidos e não modifica o arquivo original. O botão **Baixar modelo CSV** continua oferecendo o modelo completo, incluindo `horas`.
- **Dados acadêmicos sem redigitação:** as colunas `orientador`, `email_orientador` e `nome_trabalho` são lidas diretamente da planilha, quando presentes, e ficam disponíveis para o texto, a prévia e a geração. A aba **Upload** confirma as colunas detectadas, sem exibir um segundo formulário. Para corrigir um valor, edite a planilha original e importe-a novamente.
- **Frente e verso:** cada lado tem sua própria arte e seu próprio texto, fonte, tamanho, cor e posição.
- **Editor de texto com formatação:** barra de ferramentas com negrito, itálico, sublinhado, tachado, título, subtítulo, lista, alinhamento, tabela e desfazer/refazer. As variáveis são escritas como `{coluna}` (ex.: `{nome}`) e podem ser inseridas com um clique.
- **Pré-visualização em tempo real:** mostra o certificado de cada participante, com setas para navegar entre eles. O tamanho do texto é proporcional à largura da arte, então o certificado gerado sai igual à prévia, qualquer que seja a resolução da imagem.
- **Aparência:** tamanho da fonte, 10 fontes do Google Fonts (Roboto, Lato, Montserrat, Open Sans, Playfair Display, Merriweather, Dancing Script, Pacifico, Oswald e Raleway) e uma paleta de 12 cores.
- **Posição do texto:** ajustada por dois controles deslizantes (horizontal e vertical). A posição é guardada em proporção da arte, então vale para qualquer resolução.
- **Exportação:**
  - **ZIP (PNGs):** um PNG por certificado, na resolução original da arte. No modo frente e verso, cada participante tem `_frente.png` e `_verso.png`. Arquivos com nomes iguais ou que colidiriam após sanitização recebem sufixos como `_2`, `_3` para não sobrescrever certificados.
  - **PDF:** um arquivo por participante, com o nome da pessoa (ex.: `Ana_Silva.pdf`), nos modos *Somente Frente*, *Somente Verso* ou *Frente + Verso* (frente e verso da pessoa no mesmo arquivo). Com mais de um participante, os PDFs vêm juntos num ZIP.
- **Envio por e-mail:** cada participante recebe o próprio certificado em PDF no endereço da coluna escolhida, com assunto e corpo que aceitam variáveis. O PDF é comprimido automaticamente para caber no limite de 3 MB por anexo. As configurações de e-mail são usadas somente durante a sessão e **não são salvas no navegador**; ao abrir o aplicativo, quaisquer preferências antigas de e-mail (inclusive códigos de acesso) são apagadas. Se a coluna de destinatários configurada não existir no CSV atual, o envio fica bloqueado até a escolha explícita de outra coluna; o campo `email_orientador` **não** recebe certificados automaticamente. Antes de enviar, o app confere cada endereço: e-mail vazio ou digitado errado (sem @, com espaço, `gmial.com`, `hotmal.com`…) não é enviado. No fim, se algo falhar, uma janela separa quem não recebeu por motivo: **erro de digitação na planilha** (com sugestão de correção), **problema técnico** (internet, Gmail ou servidor; basta tentar de novo mais tarde), **conteúdo recusado** ou **envio não autorizado**, e o botão **Copiar lista** leva tudo para uma planilha.
- **Autenticação Google sob demanda:** nenhuma tentativa automática de login ou One Tap é feita na abertura. A integração só é preparada ao acessar a aba **E-mails**, e o login ocorre exclusivamente quando o usuário clicar no botão do Google.
- **Transparência no envio e LGPD:** a aba **E-mails** mostra uma explicação compacta da finalidade da conta institucional e do endereço de respostas, com detalhes expansíveis sobre o tratamento de dados. Não há cadastro de participantes nem armazenamento das planilhas e PDFs em banco de dados do CertiFeasy. Durante um envio, destinatário, texto e anexo passam pela função de envio e pelo Gmail, serviço que pode conservar as mensagens e registros da operação. Dados em memória são descartados ao encerrar a sessão. O aplicativo não persiste suas preferências de e-mail no navegador.
- **Upload por clique ou arrastando o arquivo** para a área de envio.

### Formatação do texto

A barra de ferramentas escreve uma marcação simples no texto, que você também pode digitar à mão:

| Marcação | Resultado |
| --- | --- |
| `**texto**` | **negrito** |
| `*texto*` | *itálico* |
| `__texto__` | sublinhado |
| `~~texto~~` | ~~tachado~~ |
| `# texto` / `## texto` no início da linha | título / subtítulo |
| `- texto` no início da linha | item de lista |
| `[esquerda]`, `[direita]` ou `[justificado]` no início da linha | alinhamento (o padrão é centralizado) |
| linhas no formato `\| a \| b \|` | tabela |

Use `\` antes de um desses caracteres para escrevê-lo literalmente. Os valores que vêm do CSV são sempre tratados como texto, então um nome com `*` ou `#` não altera a formatação.

---

## 🛠 Arquitetura e Tecnologias

- **Framework:** Flutter 3.47.6 (versão fixada no deploy), Dart 3.12+
- **Gerência de estado:** [flutter_bloc](https://pub.dev/packages/flutter_bloc)
- **Injeção de dependências e rotas:** [flutter_modular](https://pub.dev/packages/flutter_modular)
- **PDF:** [pdf](https://pub.dev/packages/pdf) e [printing](https://pub.dev/packages/printing)
- **CSV e ZIP:** [csv](https://pub.dev/packages/csv) e [archive](https://pub.dev/packages/archive)
- **Fontes:** [google_fonts](https://pub.dev/packages/google_fonts)
- **Envio de e-mail:** função serverless da Vercel em Node (`api/email.js`) com [nodemailer](https://nodemailer.com) e Gmail
- **Processamento:** no app instalado, a geração do ZIP e do PDF roda em um Isolate separado; no navegador, roda na própria página, com barra de progresso.
- **Design:** tema escuro com a tipografia *Plus Jakarta Sans*.

---

## 🚀 Como Rodar o Projeto

Instale o [Flutter](https://docs.flutter.dev/get-started/install) e, na pasta do projeto:

```bash
flutter pub get
flutter run -d chrome   # versão web, a mesma publicada na Vercel
flutter test            # testes automatizados
```

O envio de e-mails depende da função `api/email.js`, que roda no deploy da Vercel.

### Desktop (Linux)

Para rodar como app de desktop no Ubuntu/Debian, instale antes as ferramentas de compilação:

```bash
sudo apt update
sudo apt install -y clang ninja-build g++ pkg-config libgtk-3-dev
flutter run -d linux
```

### Deploy na Vercel

O `vercel.json` já instala o Flutter 3.47.6 e roda `flutter build web`, publicando a pasta `build/web` junto com a função `api/email.js`.

---

## ✉️ Envio de certificados por e-mail (Vercel)

O endpoint `/api/email` só envia e-mails para quem **entrar com uma conta Google @ifce.edu.br** na aba E-mails. O servidor confere o login no Google e aceita apenas contas do Google Workspace do domínio exato `ifce.edu.br` (contas de alunos, que usam outro domínio, e Gmail comum não passam). Não há lista de e-mails para manter.

Configure na Vercel (Settings → Environment Variables) e faça um **Redeploy** depois de mudar qualquer variável:

| Variável | Obrigatória | Descrição |
| --- | --- | --- |
| `GMAIL_USER` | Sim | Conta Gmail que envia os certificados |
| `GMAIL_APP_PASSWORD` | Sim | Senha de app dessa conta |
| `GOOGLE_CLIENT_ID` | Sim (para o login com Google) | ID do cliente OAuth do tipo "Aplicativo da Web" (termina em `.apps.googleusercontent.com`) |
| `EMAIL_ALLOWED_DOMAIN` | Não | Domínio liberado; padrão `ifce.edu.br` |
| `EMAIL_API_TOKEN` | Não | Código de acesso antigo. Só vale enquanto `GOOGLE_CLIENT_ID` não estiver configurado no app web, ou para apps desktop/mobile. Pode ser apagado depois que o login com Google estiver funcionando |
| `EMAIL_ALLOWED_ORIGINS` | Não | Origens permitidas, separadas por vírgula (ex.: `https://certifeasy.vercel.app`) |

Sem `GOOGLE_CLIENT_ID` nem `EMAIL_API_TOKEN`, o endpoint responde 503 e nenhum e-mail é enviado. Cada requisição aceita um destinatário e um PDF de até 3 MB; esse teto vem do limite de 4,5 MB por requisição da Vercel, já que o anexo vai em base64. O Gmail envia no máximo cerca de 500 e-mails por dia.

### Como criar o `GOOGLE_CLIENT_ID`

1. Abra o [Google Cloud Console](https://console.cloud.google.com/) com a sua conta e crie (ou escolha) um projeto.
2. Em **APIs e serviços → Tela de consentimento OAuth** (Google Auth Platform), configure o app. Se a conta for do Workspace do IFCE, escolha o público **Interno**.
3. Em **APIs e serviços → Credenciais → Criar credenciais → ID do cliente OAuth**, escolha **Aplicativo da Web** e, em **Origens JavaScript autorizadas**, adicione `https://certifeasy.vercel.app` (e `http://localhost` se for testar localmente). Não é preciso URI de redirecionamento.
4. Copie o **ID do cliente** para a variável `GOOGLE_CLIENT_ID` na Vercel e faça o Redeploy.

O login dura cerca de 1 hora. Se ele estiver perto de expirar, o app pede para sair e entrar de novo antes de começar um envio em lote.

--- | --- | --- |
| `GMAIL_USER` | Sim | Conta Gmail que envia os certificados |
| `GMAIL_APP_PASSWORD` | Sim | Senha de app dessa conta |
| `EMAIL_API_TOKEN` | Sim | Código de acesso digitado no app (use um valor longo e aleatório) |
| `EMAIL_ALLOWED_ORIGINS` | Não | Origens permitidas, separadas por vírgula (ex.: `https://certifeasy.vercel.app`) |

Sem `EMAIL_API_TOKEN`, o endpoint responde 503 e nenhum e-mail é enviado. Cada requisição aceita um destinatário e um PDF de até 3 MB; esse teto vem do limite de 4,5 MB por requisição da Vercel, já que o anexo vai em base64. O Gmail envia no máximo cerca de 500 e-mails por dia.

---

## 📝 Uso Básico

1. Na aba **Upload**, envie a arte da frente (e, se quiser, a do verso) e o arquivo CSV, TSV, XLS ou XLSX dos participantes. Se precisar, use **Baixar modelo CSV** (com a coluna `horas`). Planilhas acadêmicas podem usar os cabeçalhos `Nome`, `Orientador(a)`, `Título do trabalho`, `Evento`, `Data`, `E-mail` e `E-mail do orientador`, sem `Horas`; eles são convertidos automaticamente em `{nome}`, `{orientador}`, `{nome_trabalho}`, `{evento}`, `{data}`, `{email}` e `{email_orientador}`.
2. Ainda em **Upload**, confira as **colunas detectadas** e escolha o modo do PDF: *Somente Frente*, *Somente Verso* ou *Frente + Verso*. Se precisar corrigir orientador, título ou e-mail, ajuste a planilha e faça upload novamente — não é necessário preencher os dados duas vezes.
3. Na aba **Texto & Variáveis**, escreva o texto de cada lado usando as variáveis do CSV, como `{nome}`, `{horas}`, `{orientador}`, `{email_orientador}` e `{nome_trabalho}` (as três últimas aparecem quando as respectivas colunas estão presentes no arquivo importado). Ex.: `Certificamos que {nome} apresentou o trabalho {nome_trabalho}, sob orientação de {orientador}.`
4. Na aba **Aparência**, ajuste tamanho, fonte, cor e posição do texto, conferindo na pré-visualização.
5. Clique em **Gerar PDF** ou **Gerar ZIP (PNGs)** para baixar os certificados.
6. Para enviar por e-mail, vá à aba **E-mails**, preencha o e-mail para respostas, entre com a sua conta Google @ifce.edu.br, preencha o assunto e a mensagem, escolha a coluna com os endereços e clique em **Enviar Certificados**.

---

## 🤝 Contribuição
Sinta-se à vontade para abrir **Issues** e enviar **Pull Requests**. Todas as melhorias são bem-vindas!

---
*LICENÇA MIT*
*Desenvolvido com Flutter 💙*

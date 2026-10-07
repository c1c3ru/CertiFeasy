# CertiFeasy 🎓

O **CertiFeasy** é um gerador de certificados em lote feito em Flutter, pensado para eventos, cursos e workshops. Ele roda no navegador em **https://certifeasy.vercel.app** e também pode ser compilado como app de desktop ou celular.

Você envia a arte do certificado (frente e, se quiser, verso), carrega a lista de participantes em CSV, escreve o texto com as variáveis de cada pessoa e gera tudo de uma vez: em **PDF** para impressão, em **ZIP com PNGs** ou **por e-mail**, com o certificado de cada participante anexado.

---

## ✨ Funcionalidades

- **Geração em lote via CSV:** cada linha do CSV vira um certificado. O arquivo pode usar `;` ou `,` como separador e precisa ter as colunas `nome`, `evento`, `data`, `horas` e `email`. Outras colunas também podem ser usadas no texto. O botão **Baixar modelo CSV** traz um exemplo pronto.
- **Frente e verso:** cada lado tem sua própria arte e seu próprio texto, fonte, tamanho, cor e posição.
- **Editor de texto com formatação:** barra de ferramentas com negrito, itálico, sublinhado, tachado, título, subtítulo, lista, alinhamento, tabela e desfazer/refazer. As variáveis são escritas como `{coluna}` (ex.: `{nome}`) e podem ser inseridas com um clique.
- **Pré-visualização em tempo real:** mostra o certificado de cada participante, com setas para navegar entre eles. O tamanho do texto é proporcional à largura da arte, então o certificado gerado sai igual à prévia, qualquer que seja a resolução da imagem.
- **Aparência:** tamanho da fonte, 10 fontes do Google Fonts (Roboto, Lato, Montserrat, Open Sans, Playfair Display, Merriweather, Dancing Script, Pacifico, Oswald e Raleway) e uma paleta de 12 cores.
- **Posição do texto:** ajustada por dois controles deslizantes (horizontal e vertical). A posição é guardada em proporção da arte, então vale para qualquer resolução.
- **Exportação:**
  - **ZIP (PNGs):** um PNG por certificado, na resolução original da arte. No modo frente e verso, cada participante tem `_frente.png` e `_verso.png`.
  - **PDF:** nos modos *Somente Frente*, *Somente Verso* ou *Frente + Verso*. No modo frente e verso, as páginas saem intercaladas (frente 1, verso 1, frente 2…), prontas para impressão duplex.
- **Envio por e-mail:** cada participante recebe o próprio certificado em PDF no endereço da coluna escolhida, com assunto e corpo que aceitam variáveis. O PDF é comprimido automaticamente para caber no limite de 3 MB por anexo. As configurações de e-mail ficam salvas no navegador.
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

- **Framework:** Flutter 3.47.6 (versão fixada no deploy), Dart 3.9+
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

O endpoint `/api/email` só envia e-mails para quem informar o **código de acesso** na aba E-mails. Configure na Vercel (Settings → Environment Variables):

| Variável | Obrigatória | Descrição |
| --- | --- | --- |
| `GMAIL_USER` | Sim | Conta Gmail que envia os certificados |
| `GMAIL_APP_PASSWORD` | Sim | Senha de app dessa conta |
| `EMAIL_API_TOKEN` | Sim | Código de acesso digitado no app (use um valor longo e aleatório) |
| `EMAIL_ALLOWED_ORIGINS` | Não | Origens permitidas, separadas por vírgula (ex.: `https://certifeasy.vercel.app`) |

Sem `EMAIL_API_TOKEN`, o endpoint responde 503 e nenhum e-mail é enviado. Cada requisição aceita um destinatário e um PDF de até 3 MB; esse teto vem do limite de 4,5 MB por requisição da Vercel, já que o anexo vai em base64. O Gmail envia no máximo cerca de 500 e-mails por dia.

---

## 📝 Uso Básico

1. Na aba **Upload**, envie a arte da frente (e, se quiser, a do verso) e o arquivo CSV dos participantes. Se precisar, use **Baixar modelo CSV**.
2. Ainda em **Upload**, escolha o modo do PDF: *Somente Frente*, *Somente Verso* ou *Frente + Verso*.
3. Na aba **Texto & Variáveis**, escreva o texto de cada lado usando as variáveis do CSV, como `{nome}` e `{horas}`.
4. Na aba **Aparência**, ajuste tamanho, fonte, cor e posição do texto, conferindo na pré-visualização.
5. Clique em **Gerar PDF** ou **Gerar ZIP (PNGs)** para baixar os certificados.
6. Para enviar por e-mail, vá à aba **E-mails**, preencha o e-mail para respostas, o código de acesso, o assunto e a mensagem, escolha a coluna com os endereços e clique em **Enviar Certificados**.

---

## 🤝 Contribuição
Sinta-se à vontade para abrir **Issues** e enviar **Pull Requests**. Todas as melhorias são bem-vindas!

---
*LICENÇA MIT*
*Desenvolvido com Flutter 💙*

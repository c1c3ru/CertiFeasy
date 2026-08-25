# CertiFeasy 🎓

O **CertiFeasy** é um gerador de certificados em lote desenvolvido em Flutter, feito sob medida para simplificar a criação de certificados para eventos, cursos e workshops.

Através de uma interface moderna e intuitiva, você pode importar uma base de dados (CSV), fazer o upload da arte base do certificado (frente e verso), posicionar os textos dinamicamente e exportar todos os certificados de uma só vez — seja em **PDF** para impressão ou em um arquivo **ZIP (com PNGs)** para distribuição digital.

---

## ✨ Funcionalidades

- **Geração em Lote:** Importe um arquivo CSV (ex: Nome, Curso, Carga Horária) e gere dezenas de certificados automaticamente.
- **Templates Frente e Verso:** Suporte a inserção da arte frontal e do verso do certificado, ideal para inclusão de cronogramas ou chancelas.
- **Posicionamento Visual (Drag & Drop):** Posicione o texto livremente em cima da imagem do certificado de forma visual. O posicionamento utiliza coordenadas normalizadas para manter a precisão independentemente da resolução de exportação.
- **Formatação de Texto:** Personalize a aparência das variáveis com um seletor nativo de cor (Color Picker), escolha de fontes (Google Fonts) e tamanho de texto ajustável.
- **Exportação Flexível (Multi-Thread):**
  - **Arquivo ZIP (PNGs):** Exporta todas as artes separadas em alta qualidade.
  - **Documento PDF:** Exporte em múltiplos modos: *Somente Frente*, *Somente Verso*, ou *Frente + Verso* (pronto para enviar direto para a gráfica).
- **Processamento em Background (Isolates):** A geração dos lotes e do PDF acontece em uma thread separada, mantendo a UI 100% responsiva, sem travamentos.

---

## 🛠 Arquitetura e Tecnologias

- **Framework:** Flutter (versão 3.44+)
- **Gerência de Estado:** [flutter_bloc](https://pub.dev/packages/flutter_bloc)
- **Injeção de Dependências & Rotas:** [flutter_modular](https://pub.dev/packages/flutter_modular)
- **PDF e Impressão:** [pdf](https://pub.dev/packages/pdf) e [printing](https://pub.dev/packages/printing)
- **Manipulação CSV:** [csv](https://pub.dev/packages/csv)
- **Design System:** Baseado em tons escuros (Dark Mode) focados em concentração, combinados com a tipografia *Plus Jakarta Sans*.

---

## 🚀 Como Rodar o Projeto (Linux)

O aplicativo foi projetado com foco em rodar nativamente em ambientes Desktop (Linux/Windows/macOS). Para rodá-lo no Ubuntu/Debian, você precisará dos pacotes nativos de compilação C++ e do GTK3.

### 1. Instalar dependências nativas
Se você utiliza Linux, assegure-se de que possui as ferramentas de compilação instaladas. Abra seu terminal e rode:

```bash
sudo apt update
sudo apt install -y clang ninja-build g++ pkg-config libgtk-3-dev
```

### 2. Rodar o App
Navegue até a pasta do projeto e inicie a compilação:

```bash
cd certifeasy
flutter pub get
flutter run -d linux
```

---

## 📝 Uso Básico

1. Na aba **Upload de Arquivos**, insira sua arte (JPG ou PNG) de Frente (e opcionalmente de Verso).
2. Adicione seu arquivo `.csv` contendo a lista dos participantes.
3. Defina se o modo do PDF gerado será *Somente Frente*, *Somente Verso* ou *Frente + Verso*.
4. Avance para a aba **Texto e Variáveis** para definir as chaves do CSV no formato `{Coluna}` (ex: `{Nome}`).
5. Use a aba **Aparência do Texto** para arrastar os campos até o local correto e aplicar cor, fonte e tamanho desejados.
6. Clique no botão de exportação e escolha ZIP ou PDF.

---

## 🤝 Contribuição
Sinta-se à vontade para abrir **Issues** e enviar **Pull Requests**. Todas as melhorias são bem-vindas!

---
*LICENÇA MIT*
*Desenvolvido com Flutter 💙*

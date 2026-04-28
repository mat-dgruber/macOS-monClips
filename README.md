# monClips 📋

**monClips** é um gerenciador de área de transferência (clipboard manager) moderno, eficiente e multiplataforma, desenhado para rodar nativamente tanto no **macOS** quanto no **iOS**. 

O aplicativo monitora o que você copia no seu dispositivo, armazena um histórico persistente e permite fácil acesso aos seus recortes mais recentes, organizando sua produtividade e evitando a perda daquele texto ou link importante que você copiou há algumas horas.

---

## ✨ Principais Funcionalidades

- ⏱️ **Monitoramento Contínuo**: Salva automaticamente textos e links copiados para a área de transferência do sistema.
- 🗑️ **Limpeza Inteligente (TTL)**: Por padrão, itens copiados duram **24 horas**. O app possui um "garbage collector" que limpa automaticamente textos antigos para economizar espaço e manter o app rápido.
- 📌 **Fixação de Recortes (Pinning)**: Recortes importantes podem ser "fixados" (pinned). Itens fixados não são apagados pela regra de 24 horas e ficam sempre no topo da sua lista.
- 🔍 **Busca Dinâmica**: Filtre seus recortes salvos rapidamente usando a barra de pesquisa integrada em tempo real.
- 🔗 **Detecção Inteligente de Links**: URLs copiadas são identificadas visualmente. Com dois toques, o monClips abre o link diretamente no navegador padrão.
- ⌨️ **Integração Profunda no macOS**:
  - **Atalho Global**: Aperte `Ctrl + Option + V` de qualquer lugar no seu Mac para trazer o monClips para a frente de todas as janelas.

---

## 🛠️ Tecnologias e Arquitetura

Este projeto foi construído usando as mais recentes tecnologias do ecossistema Apple:

* **SwiftUI**: Para uma interface declarativa, fluida e reativa através de múltiplas plataformas.
* **SwiftData**: Substitui o Core Data, fornecendo persistência local rápida, moderna e segura para o histórico de recortes (usando a macro `@Model`).
* **AppKit & UIKit**: Integrações de baixo nível dependendo do sistema compilado, permitindo capturar o clipboard correto (NSPasteboard vs UIPasteboard) e manipular APIs do macOS (NSEvent para atalhos).

### Lógica de Negócios (Como funciona sob o capô)
1. **Polling**: O monClips não depende de "listeners" do sistema (que costumam ter restrições de segurança), e sim de um *polling* ativo. Um `Timer` verifica a área de transferência a cada 2 segundos.
2. **Prevenção de Duplicatas**: Antes de gravar no SwiftData, o app verifica se a string recém-copiada não é exatamente igual a uma já existente.
3. **Ordenação**: A tela principal renderiza uma `@Query` de `ClipItem`, processada por uma lógica computada que garante: primeiro os fixados, e então ordem cronológica descrescente (os mais novos primeiro).

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
* **Xcode 15.0** ou superior.
* **macOS 14.0+** (Sonoma) ou **iOS 17.0+** (necessário para suporte nativo ao framework `SwiftData`).

### Instalação
1. Clone o repositório:
   ```bash
   git clone https://github.com/mat-dgruber/macOS-monClips.git
   ```
2. Abra a pasta clonada e dê um duplo clique no arquivo `monClips.xcodeproj` para abrir no Xcode.
3. Selecione o target/simulador desejado (Mac ou dispositivo iOS) na barra superior.
4. Clique no botão de "Play" (Run) ou aperte `Cmd + R` para compilar e rodar o projeto.

---

## ⚠️ Configurações Especiais para o macOS

Para que o monClips funcione em todo o seu potencial no Mac (especialmente o **Atalho Global**), o aplicativo requer permissões de Acessibilidade do sistema operacional para escutar os eventos de teclado quando está em segundo plano.

**Passos para ativar:**
1. Rode o aplicativo pela primeira vez no seu Mac.
2. Vá em **Ajustes do Sistema** (System Settings).
3. Navegue até **Privacidade e Segurança** > **Acessibilidade**.
4. Encontre o `monClips` na lista e ligue a chave (switch) ao lado dele.
5. *(Talvez seja necessário reiniciar o monClips após conceder a permissão).*

---

## 🤝 Contribuição

Sinta-se livre para abrir _Issues_ relatando bugs ou sugerir melhorias. Se quiser contribuir diretamente com código, faça um Fork do projeto, crie sua branch de funcionalidade, e abra um Pull Request!

---

*Desenvolvido com Swift e 🩵*
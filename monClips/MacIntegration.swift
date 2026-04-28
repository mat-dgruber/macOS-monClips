import SwiftUI
#if os(macOS)
import AppKit
import ApplicationServices

class MacIntegration {
    static let shared = MacIntegration()
    private var globalMonitor: Any?

    // Configura o atalho global (Ctrl + Cmd + V)
    func setupGlobalHotkey(action: @escaping () -> Void) {
        // Solicita permissão de Acessibilidade (necessário para ler o teclado fora do app e simular teclas)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("⚠️ Permissão de Acessibilidade pendente. Autorize em Ajustes do Sistema > Privacidade e Segurança > Acessibilidade.")
        }

        // Escuta o teclado globalmente (quando o app NÃO está em foco)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Verifica se as teclas Control e Option estão pressionadas, e a tecla "V" (keyCode 9)
            if event.modifierFlags.contains(.control) &&
               event.modifierFlags.contains(.option) &&
               event.keyCode == 9 {

                DispatchQueue.main.async {
                    // Traz o nosso app para a frente de tudo
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        window.makeKeyAndOrderFront(nil)
                    }
                    action()
                }
            }
        }
    }

    // Executa o "Auto-Colar"
    func pasteToPreviousApp() {
        // 1. Ocultamos nosso app para o foco voltar imediatamente para o app que estava atrás (ex: Safari, Word)
        NSApp.hide(nil)

        // 2. Damos um delay de 150 milissegundos para dar tempo da janela sumir e o macOS focar no app de trás
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // 3. Criamos eventos de teclado de baixo nível (Hardware) simulando Cmd+V
            let source = CGEventSource(stateID: .hidSystemState)
            let keyV: CGKeyCode = 9 // Código da tecla V

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else {
                return
            }

            // Adiciona a flag do Command (Cmd)
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            // Dispara as teclas para o sistema operacional
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
#endif

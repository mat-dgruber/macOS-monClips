//
//  monClipsApp.swift
//  monClips
//
//  Created by Matheus Diniz  on 27/04/26.
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
    }
}
#endif

@main
struct monClipsApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClipItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                .frame(minWidth: 350, minHeight: 400)
                .onAppear {
                    print("Registering global hotkey...")
                    MacIntegration.shared.setupGlobalHotkey {
                        print("Hotkey triggered! Activating app...")
                        NSApp.activate(ignoringOtherApps: true)
                        for window in NSApp.windows {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }
        }
        .windowResizability(.contentSize)
        .modelContainer(sharedModelContainer)
        #else
        // No iOS, funciona normalmente
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}

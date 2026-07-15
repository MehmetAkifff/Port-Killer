//
//  Port_KillerApp.swift
//  Port Killer
//
//  Created by Mehmet Akif ERGANİ on 9.04.2026.
//

import AppKit
import SwiftUI

@main
struct Port_KillerApp: App {
    @NSApplicationDelegateAdaptor(PortKillerAppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(portManager: appController.portManager)
        } label: {
            Label("Port Killer", systemImage: "network")
        }
        .menuBarExtraStyle(.menu)

        WindowGroup(id: "settings") {
            SettingsView()
                .environmentObject(appController.portManager)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .defaultLaunchBehavior(.suppressed)
    }
}

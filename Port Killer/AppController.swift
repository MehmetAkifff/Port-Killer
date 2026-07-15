//
//  AppController.swift
//

import AppKit
import Combine
import Foundation

/// Owns the port manager and registers the global shortcut for the app lifetime.
@MainActor
final class AppController: ObservableObject {

    let portManager = PortManager()
    private let hotkey = GlobalShortcutMonitor()
    private var refreshTick: AnyCancellable?
    private var observers: [NSObjectProtocol] = []

    init() {
        ShortcutPreferences.installRegistrationDefaults()

        startHotkey()

        portManager.refreshEntries()
        refreshTick = Timer.publish(every: PortManager.refreshIntervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.portManager.refreshEntries()
                }
            }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .portKillerHotkeyBindingDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.startHotkey()
            }
        })
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.startHotkey()
            }
        })
    }

    private func startHotkey() {
        hotkey.stop()
        hotkey.start { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.portManager.executeShortcutKill()
            }
        }
    }
}

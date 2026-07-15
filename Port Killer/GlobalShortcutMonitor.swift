//
//  GlobalShortcutMonitor.swift
//

import AppKit
import ApplicationServices

/// Global shortcut using stored key code + modifiers. Uses **only** the global monitor when
/// Accessibility is enabled (avoids double-firing); otherwise falls back to a local monitor
/// while this app is focused.
final class GlobalShortcutMonitor {

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onFire: (() -> Void)?

    func start(onFire: @escaping () -> Void) {
        stop()
        self.onFire = onFire

        let fire: (NSEvent) -> Void = { event in
            guard ShortcutPreferences.eventMatchesShortcut(event) else { return }
            onFire()
        }

        if Self.isAccessibilityTrusted {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: fire)
        } else {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard ShortcutPreferences.eventMatchesShortcut(event) else { return event }
                onFire()
                return nil
            }
        }
    }

    func stop() {
        onFire = nil
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        globalMonitor = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
    }

    static func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }
}

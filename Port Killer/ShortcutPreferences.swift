//
//  ShortcutPreferences.swift
//

import AppKit
import Foundation

extension Notification.Name {
    /// Posted when the key combination changes; restart the event monitor.
    static let portKillerHotkeyBindingDidChange = Notification.Name("portKillerHotkeyBindingDidChange")
}

/// Default: ⌘⇧A (`kVK_ANSI_A` = 0).
private let defaultShortcutKeyCode: UInt16 = 0

enum ShortcutKillScope: String, CaseIterable, Identifiable {
    case allMonitoredPorts
    case builtInDevPortsOnly
    case selectedPortsOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allMonitoredPorts:
            return "All monitored ports"
        case .builtInDevPortsOnly:
            return "Built-in dev ports only"
        case .selectedPortsOnly:
            return "Selected ports only"
        }
    }

    var detail: String {
        switch self {
        case .allMonitoredPorts:
            return "Every port in your menu list (default + custom) that is in use."
        case .builtInDevPortsOnly:
            return "Only the built-in list: \(PortManager.builtInPorts.map(String.init).joined(separator: ", "))."
        case .selectedPortsOnly:
            return "Only ports you enable in the list below."
        }
    }
}

enum ShortcutPreferences {

    private static let keyCodeKey = "pk.shortcut.keyCode"
    private static let modifiersKey = "pk.shortcut.modifiersRaw"
    private static let scopeKey = "pk.shortcut.killScope"
    private static let selectedPortsKey = "pk.shortcut.selectedPorts"
    private static let displayLabelKey = "pk.shortcut.displayLabel"

    static let allowedModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    static func installRegistrationDefaults() {
        let mods = NSEvent.ModifierFlags([.command, .shift]).intersection(allowedModifiers)
        UserDefaults.standard.register(defaults: [
            keyCodeKey: Int(defaultShortcutKeyCode),
            modifiersKey: Int(mods.rawValue),
            scopeKey: ShortcutKillScope.allMonitoredPorts.rawValue,
            displayLabelKey: "A",
        ])
    }

    static var killScope: ShortcutKillScope {
        let raw = UserDefaults.standard.string(forKey: scopeKey) ?? ShortcutKillScope.allMonitoredPorts.rawValue
        return ShortcutKillScope(rawValue: raw) ?? .allMonitoredPorts
    }

    static func saveKillScope(_ scope: ShortcutKillScope) {
        UserDefaults.standard.set(scope.rawValue, forKey: scopeKey)
    }

    /// Ports the shortcut may kill when scope is `selectedPortsOnly`. Missing key defaults to built-ins; an explicit empty array is allowed.
    static func selectedShortcutTargetPorts() -> [Int] {
        guard let data = UserDefaults.standard.data(forKey: selectedPortsKey),
              let arr = try? JSONDecoder().decode([Int].self, from: data)
        else {
            return PortManager.builtInPorts
        }
        return arr.filter { (1...65_535).contains($0) }.sorted()
    }

    static func saveSelectedShortcutPorts(_ ports: [Int]) {
        let sorted = Array(Set(ports)).filter { (1...65_535).contains($0) }.sorted()
        if let data = try? JSONEncoder().encode(sorted) {
            UserDefaults.standard.set(data, forKey: selectedPortsKey)
        }
    }

    static func currentBinding() -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        // Note: `kVK_ANSI_A` is 0 — do not treat 0 as “unset”.
        let kc = UInt16(truncatingIfNeeded: UserDefaults.standard.integer(forKey: keyCodeKey))
        let raw = UInt(UserDefaults.standard.integer(forKey: modifiersKey))
        var mods = NSEvent.ModifierFlags(rawValue: raw).intersection(allowedModifiers)
        if mods.isEmpty {
            mods = [.command, .shift]
        }
        return (kc, mods)
    }

    static func saveBinding(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, displayLabel: String?) {
        let mods = modifiers.intersection(.deviceIndependentFlagsMask).intersection(allowedModifiers)
        guard mods.contains(.command) || mods.contains(.control) else { return }
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(mods.rawValue), forKey: modifiersKey)
        if let displayLabel {
            let t = displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty {
                UserDefaults.standard.removeObject(forKey: displayLabelKey)
            } else if t == " " {
                UserDefaults.standard.set("Space", forKey: displayLabelKey)
            } else if let c = t.uppercased().first {
                UserDefaults.standard.set(String(c), forKey: displayLabelKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: displayLabelKey)
        }
        NotificationCenter.default.post(name: .portKillerHotkeyBindingDidChange, object: nil)
    }

    static func eventMatchesShortcut(_ event: NSEvent) -> Bool {
        let (kc, requiredMods) = currentBinding()
        guard event.keyCode == kc else { return false }
        let actual = event.modifierFlags.intersection(.deviceIndependentFlagsMask).intersection(allowedModifiers)
        return actual == requiredMods
    }

    static func displayString() -> String {
        let (kc, mods) = currentBinding()
        let keyPart: String
        if let label = UserDefaults.standard.string(forKey: displayLabelKey), !label.isEmpty {
            keyPart = label
        } else {
            keyPart = keyCodeLabel(kc)
        }
        return formatShortcut(modifiers: mods, keyLabel: keyPart)
    }

    static func formatShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        formatShortcut(modifiers: modifiers, keyLabel: keyCodeLabel(keyCode))
    }

    private static func formatShortcut(modifiers: NSEvent.ModifierFlags, keyLabel: String) -> String {
        var s = ""
        let m = modifiers.intersection(allowedModifiers)
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option) { s += "⌥" }
        if m.contains(.shift) { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        s += keyLabel
        return s
    }

    private static func keyCodeLabel(_ code: UInt16) -> String {
        switch code {
        case 0x00: return "A"
        case 0x28: return "K"
        case 0x24: return "↩"
        case 0x31: return "Space"
        case 0x35: return "Esc"
        case 0x33: return "⌫"
        default:
            let c = Int(code)
            if (0x7A...0x83).contains(c) {
                return "F\(c - 0x7A + 1)"
            }
            return "(\(code))"
        }
    }
}

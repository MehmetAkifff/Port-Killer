//
//  PortManager.swift
//

import AppKit
import Combine
import Foundation

@MainActor
final class PortManager: ObservableObject {

    /// Shown in the menu (defaults + user ports).
    static let builtInPorts = [5173, 5174, 3000, 3001, 8000, 8080]

    /// Global shortcut kills only these predefined dev ports.
    static let predefinedDevPorts = builtInPorts

    private static let customPortsKey = "customPortNumbers"

    @Published private(set) var entries: [PortEntry] = []

    private let shell: ShellCommandService
    private var customPorts: [Int] = []

    /// Background polling interval (seconds); balances freshness vs `lsof` load.
    static let refreshIntervalSeconds: TimeInterval = 4

    init(shell: ShellCommandService? = nil) {
        self.shell = shell ?? ShellCommandService()
        loadCustomPorts()
        commitEntries(Self.allPortsList(defaults: Self.builtInPorts, custom: customPorts).map(PortEntry.inactive))
    }

    /// Active ports first, then ascending port number.
    static func sortedForDisplay(_ items: [PortEntry]) -> [PortEntry] {
        items.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }
            return a.port < b.port
        }
    }

    private func commitEntries(_ raw: [PortEntry]) {
        entries = Self.sortedForDisplay(raw)
    }

    private static func allPortsList(defaults: [Int], custom: [Int]) -> [Int] {
        Array(Set(defaults + custom)).sorted()
    }

    private func loadCustomPorts() {
        if let data = UserDefaults.standard.data(forKey: Self.customPortsKey),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            customPorts = decoded.filter { (1...65_535).contains($0) }
        } else {
            customPorts = []
        }
    }

    func customPortsForSettings() -> [Int] {
        customPorts.sorted()
    }

    func addCustomPort(_ port: Int) {
        guard (1...65_535).contains(port) else { return }
        guard !Self.builtInPorts.contains(port) else { return }
        guard !customPorts.contains(port) else { return }
        customPorts.append(port)
        persistCustomPorts()
        syncEntriesWithPortList()
        refreshEntries()
    }

    func removeCustomPort(_ port: Int) {
        customPorts.removeAll { $0 == port }
        persistCustomPorts()
        syncEntriesWithPortList()
        refreshEntries()
    }

    private func persistCustomPorts() {
        if let data = try? JSONEncoder().encode(customPorts.sorted()) {
            UserDefaults.standard.set(data, forKey: Self.customPortsKey)
        }
    }

    private func syncEntriesWithPortList() {
        let ports = Self.allPortsList(defaults: Self.builtInPorts, custom: customPorts)
        var map = Dictionary(uniqueKeysWithValues: entries.map { ($0.port, $0) })
        let merged = ports.map { p in
            map[p] ?? .inactive(p)
        }
        commitEntries(merged)
    }

    /// Resolves PIDs for a port; captures permission / parse issues in `scanNote`.
    nonisolated static func resolvePids(port: Int, shell: ShellCommandService) -> (pids: [Int], note: String?) {
        do {
            let result = try shell.pidsListening(on: port)
            let combined = result.stdout + result.stderr
            if result.terminationStatus != 0, combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ([], Self.hintForLsofFailure(stderr: result.stderr))
            }
            let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)
            let pids = lines.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let note: String?
            if !result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                note = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                note = nil
            }
            return (pids, note)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    nonisolated private static func hintForLsofFailure(stderr: String) -> String? {
        let s = stderr.lowercased()
        if s.contains("permission") || s.contains("not permitted") {
            return "This port may be owned by another user or require elevated permissions (sudo)."
        }
        return stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func refreshEntries() {
        let ports = entries.map(\.port)
        let shell = self.shell
        Task.detached(priority: .userInitiated) { [ports] in
            var updated: [PortEntry] = []
            for port in ports {
                let (pids, note) = PortManager.resolvePids(port: port, shell: shell)
                updated.append(PortEntry(port: port, pids: pids, scanNote: note, killNote: nil))
            }
            await MainActor.run {
                self.commitEntries(updated)
            }
        }
    }

    func killPort(_ port: Int) {
        guard let idx = entries.firstIndex(where: { $0.port == port }) else { return }
        let pids = entries[idx].pids
        guard !pids.isEmpty else { return }

        let shell = self.shell
        Task.detached {
            let outcome = PortManager.performKill(pids: pids, shell: shell)
            await MainActor.run {
                self.applyKillOutcome(outcome, port: port)
            }
        }
    }

    func killAllActive() {
        let targets = entries.filter(\.isActive)
        runKillTask(targets: targets)
    }

    /// Shortcut scope: only ports in `allowed` that are currently active.
    func killActivePorts(in allowed: Set<Int>) {
        let targets = entries.filter { $0.isActive && allowed.contains($0.port) }
        runKillTask(targets: targets)
    }

    private func runKillTask(targets: [PortEntry]) {
        guard !targets.isEmpty else {
            return
        }
        let shell = self.shell
        Task.detached {
            var messages: [String] = []
            for entry in targets {
                let outcome = PortManager.performKill(pids: entry.pids, shell: shell)
                if case .partialFailures(let errs) = outcome {
                    messages.append(contentsOf: errs)
                } else if case .scanOrKillFailed(let msg) = outcome {
                    messages.append("Port \(entry.port): \(msg)")
                }
            }
            await MainActor.run {
                if !messages.isEmpty {
                    self.presentErrorAlert(messages.joined(separator: "\n"))
                }
                self.refreshEntries()
            }
        }
    }

    /// Reads shortcut scope from `UserDefaults` and runs the matching kill strategy.
    func executeShortcutKill() {
        switch ShortcutPreferences.killScope {
        case .allMonitoredPorts:
            killAllActive()
        case .builtInDevPortsOnly:
            killAllPredefinedDevPorts()
        case .selectedPortsOnly:
            let allowed = Set(ShortcutPreferences.selectedShortcutTargetPorts())
            guard !allowed.isEmpty else { return }
            killActivePorts(in: allowed)
        }
    }

    /// Global shortcut: only predefined dev ports.
    func killAllPredefinedDevPorts() {
        let shell = self.shell
        Task.detached {
            var failures: [String] = []
            var portsTerminated = 0
            for port in Self.predefinedDevPorts {
                let (pids, scanNote) = PortManager.resolvePids(port: port, shell: shell)
                if pids.isEmpty {
                    if let scanNote, !scanNote.isEmpty {
                        failures.append(":\(port) — \(scanNote)")
                    }
                    continue
                }
                let outcome = PortManager.performKill(pids: pids, shell: shell)
                switch outcome {
                case .success:
                    portsTerminated += 1
                case .partialFailures(let errs):
                    failures.append(contentsOf: errs.map { ":\(port) — \($0)" })
                case .scanOrKillFailed(let msg):
                    failures.append(":\(port) — \(msg)")
                }
            }
            await MainActor.run {
                if !failures.isEmpty {
                    self.presentErrorAlert(failures.joined(separator: "\n"))
                }
                self.refreshEntries()
            }
        }
    }

    nonisolated private static func performKill(pids: [Int], shell: ShellCommandService) -> PortKillOutcome {
        do {
            let result = try shell.forceKill(pids: pids)
            let err = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if result.terminationStatus == 0 {
                return err.isEmpty ? .success : .partialFailures([err])
            }
            if err.isEmpty {
                return .scanOrKillFailed("kill exited with status \(result.terminationStatus).")
            }
            let lower = err.lowercased()
            if lower.contains("operation not permitted") || lower.contains("not permitted") {
                return .scanOrKillFailed("Could not kill process (permission denied). Try sudo or quit the app that owns the port.")
            }
            return .partialFailures([err])
        } catch {
            return .scanOrKillFailed(error.localizedDescription)
        }
    }

    private func applyKillOutcome(_ outcome: PortKillOutcome, port: Int) {
        switch outcome {
        case .success:
            break
        case .partialFailures(let errs):
            presentErrorAlert(errs.joined(separator: "\n"))
        case .scanOrKillFailed(let msg):
            presentErrorAlert(msg)
        }
        refreshEntries()
    }

    private func presentErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Port Killer"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

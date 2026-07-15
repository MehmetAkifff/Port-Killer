//
//  SettingsView.swift
//

import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var portManager: PortManager
    @State private var newPortText = ""
    @State private var hint: String?
    @State private var killScope: ShortcutKillScope = ShortcutPreferences.killScope
    @State private var selectedShortcutPorts: Set<Int> = []
    @State private var isRecordingShortcut = false
    @State private var shortcutDisplayRevision = 0
    @State private var launchAtLogin = false
    @State private var launchLoginMessage: String?

    private var monitoredPortNumbers: [Int] {
        Array(Set(portManager.entries.map(\.port))).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    monitoredSection
                    launchAtLoginSection
                    customPortsSection
                    shortcutSection
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Port Killer")
        }
        .frame(minWidth: 460, minHeight: 600)
        .onAppear {
            killScope = ShortcutPreferences.killScope
            selectedShortcutPorts = Set(ShortcutPreferences.selectedShortcutTargetPorts())
            syncLaunchAtLoginUI()
        }
        .onDisappear {
            isRecordingShortcut = false
        }
    }

    private var launchAtLoginSection: some View {
        SettingsPanel(
            title: "Open at login",
            caption: "Starts Port Killer when you sign in to this Mac. For a stable path, put the app in Applications (running from Xcode uses a temporary build folder)."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch Port Killer at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        Task { await applyLaunchAtLogin(newValue) }
                    }
                ))
                if let launchLoginMessage, !launchLoginMessage.isEmpty {
                    Text(launchLoginMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Open Login Items in System Settings…") {
                    Task {
                        if #available(macOS 13, *) {
                            try? await SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var monitoredSection: some View {
        SettingsPanel(
            title: "Monitored ports",
            caption: "In-use ports are listed first. Refreshes about every \(Int(PortManager.refreshIntervalSeconds)) seconds in the background."
        ) {
            if portManager.entries.isEmpty {
                Text("No ports configured.")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(portManager.entries.enumerated()), id: \.element.id) { index, entry in
                        monitoredRow(entry)
                        if index < portManager.entries.count - 1 {
                            Divider()
                                .padding(.leading, 22)
                        }
                    }
                }
            }
        }
    }

    private func monitoredRow(_ entry: PortEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PortStatusDot(active: entry.isActive)

            Text(verbatim: ":\(entry.port)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)

            Spacer(minLength: 8)

            Text(entry.isActive ? "In use" : "Free")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if entry.isActive {
                Button {
                    portManager.killPort(entry.port)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Kill process on this port")
            }
        }
        .padding(.vertical, 6)
    }

    private var customPortsSection: some View {
        SettingsPanel(
            title: "Custom ports",
            caption: "Added on top of the built-in dev ports. Built-ins: \(PortManager.builtInPorts.map(String.init).joined(separator: ", "))."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    TextField("Port number", text: $newPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 128)
                        .onSubmit { addPortFromField() }

                    Button {
                        addPortFromField()
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                if let hint {
                    Label(hint, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }

                if portManager.customPortsForSettings().isEmpty {
                    Text("No custom ports yet.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(portManager.customPortsForSettings().enumerated()), id: \.element) { index, port in
                            HStack {
                                Label {
                                    Text(verbatim: ":\(port)")
                                        .font(.system(.body, design: .monospaced))
                                } icon: {
                                    Image(systemName: "network")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    portManager.removeCustomPort(port)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove port")
                            }
                            .padding(.vertical, 6)
                            if index < portManager.customPortsForSettings().count - 1 {
                                Divider()
                                    .padding(.leading, 28)
                            }
                        }
                    }
                }
            }
        }
    }

    private var shortcutSection: some View {
        SettingsPanel(
            title: "Global shortcut",
            caption: "Choose a key combination (must include ⌘ or ⌃). Other apps may use the same shortcut."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Current")
                        .foregroundStyle(.secondary)
                    Text(ShortcutPreferences.displayString())
                        .id(shortcutDisplayRevision)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Spacer(minLength: 8)

                    Button {
                        isRecordingShortcut.toggle()
                    } label: {
                        Text(isRecordingShortcut ? "Press keys…" : "Change…")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                if isRecordingShortcut {
                    Text("Click here, then press the new shortcut. Include ⌘ or ⌃. Press Esc to cancel.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ShortcutCaptureRepresentable(isRecording: $isRecordingShortcut) { keyCode, modifiers, label in
                    ShortcutPreferences.saveBinding(keyCode: keyCode, modifiers: modifiers, displayLabel: label)
                    shortcutDisplayRevision += 1
                }
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("When triggered")
                        .font(.subheadline.weight(.semibold))
                    Picker("", selection: $killScope) {
                        ForEach(ShortcutKillScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: killScope) { _, newValue in
                        ShortcutPreferences.saveKillScope(newValue)
                    }

                    Text(killScope.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if killScope == .selectedPortsOnly {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ports to kill")
                            .font(.subheadline.weight(.semibold))
                        Text("Only checked ports are terminated when the shortcut runs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(monitoredPortNumbers, id: \.self) { port in
                            Toggle(isOn: Binding(
                                get: { selectedShortcutPorts.contains(port) },
                                set: { on in
                                    if on {
                                        selectedShortcutPorts.insert(port)
                                    } else {
                                        selectedShortcutPorts.remove(port)
                                    }
                                    ShortcutPreferences.saveSelectedShortcutPorts(Array(selectedShortcutPorts).sorted())
                                }
                            )) {
                                Text(verbatim: ":\(port)")
                                    .font(.system(.body, design: .monospaced))
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }

                Divider()

                if !GlobalShortcutMonitor.isAccessibilityTrusted {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Turn on Accessibility for Port Killer so the shortcut works while other apps are focused. Without it, the shortcut only works when this app is active.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button("Request access…") {
                                GlobalShortcutMonitor.promptForAccessibilityIfNeeded()
                            }
                            .buttonStyle(.bordered)

                            Button("Open System Settings…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Label("Accessibility enabled — global shortcut works from any app.", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }

    private func syncLaunchAtLoginUI() {
        guard #available(macOS 13, *) else {
            launchAtLogin = false
            launchLoginMessage = "Requires macOS 13 or later."
            return
        }
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true
            launchLoginMessage = nil
        case .requiresApproval:
            launchAtLogin = true
            launchLoginMessage = "Approve Port Killer under System Settings → General → Login Items & Extensions."
        case .notRegistered, .notFound:
            launchAtLogin = false
            launchLoginMessage = nil
        @unknown default:
            launchAtLogin = false
            launchLoginMessage = nil
        }
    }

    @MainActor
    private func applyLaunchAtLogin(_ enable: Bool) async {
        guard #available(macOS 13, *) else { return }
        launchLoginMessage = nil
        do {
            if enable {
                try await SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
            syncLaunchAtLoginUI()
        } catch {
            launchLoginMessage = error.localizedDescription
            syncLaunchAtLoginUI()
        }
    }

    private func addPortFromField() {
        hint = nil
        let trimmed = newPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1...65_535).contains(value) else {
            hint = "Enter a valid port between 1 and 65535."
            return
        }
        if PortManager.builtInPorts.contains(value) {
            hint = "That port is already in the default list."
            return
        }
        portManager.addCustomPort(value)
        newPortText = ""
    }
}

// MARK: - Panel chrome

private struct SettingsPanel<PanelBody: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let content: () -> PanelBody

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

//
//  MenuBarContentView.swift
//

import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var portManager: PortManager

    var body: some View {
        Group {
            Button {
                portManager.killAllActive()
            } label: {
                Label("Kill All Active", systemImage: "trash.fill")
            }

            Divider()

            ForEach(portManager.entries) { entry in
                portRow(entry)
            }

            Divider()

            Button {
                openWindow(id: "settings")
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Port Killer", systemImage: "power")
            }
        }
        .onAppear {
            portManager.refreshEntries()
        }
    }

    @ViewBuilder
    private func portRow(_ entry: PortEntry) -> some View {
        if entry.isActive {
            Button {
                portManager.killPort(entry.port)
            } label: {
                HStack(spacing: 8) {
                    PortStatusDot(active: true)
                    Text(verbatim: ":\(entry.port) — Active")
                    Spacer(minLength: 12)
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.secondary)
                    Text("Kill")
                }
            }
        } else {
            Button {
            } label: {
                HStack(spacing: 8) {
                    PortStatusDot(active: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: ":\(entry.port) — Inactive")
                        if let note = entry.scanNote, !note.isEmpty {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
            }
            .disabled(true)
            .buttonStyle(.plain)
        }
    }
}

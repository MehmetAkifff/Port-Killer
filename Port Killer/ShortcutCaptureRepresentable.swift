//
//  ShortcutCaptureRepresentable.swift
//

import AppKit
import SwiftUI

/// Captures the next key combination while `isRecording` is true (Settings window must be key).
struct ShortcutCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCaptured: (UInt16, NSEvent.ModifierFlags, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.isHidden = true
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(recording: isRecording)
    }

    final class Coordinator: NSObject {
        var parent: ShortcutCaptureRepresentable
        private var monitor: Any?

        init(parent: ShortcutCaptureRepresentable) {
            self.parent = parent
        }

        func sync(recording: Bool) {
            if recording {
                start()
            } else {
                stop()
            }
        }

        private func start() {
            stop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 53 {
                    DispatchQueue.main.async {
                        self.parent.isRecording = false
                    }
                    return nil
                }
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .intersection(ShortcutPreferences.allowedModifiers)
                guard mods.contains(.command) || mods.contains(.control) else {
                    return event
                }
                let label = event.charactersIgnoringModifiers
                DispatchQueue.main.async {
                    self.parent.onCaptured(event.keyCode, mods, label)
                    self.parent.isRecording = false
                }
                return nil
            }
        }

        private func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            stop()
        }
    }
}

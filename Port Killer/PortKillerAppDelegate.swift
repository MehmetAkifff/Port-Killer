//
//  PortKillerAppDelegate.swift
//

import AppKit

/// Ensures a menu-bar–only app registers as an accessory and can show its `MenuBarExtra` when run from Xcode.
final class PortKillerAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }
}

//
//  PortModels.swift
//  Port Killer
//

import Foundation

struct PortEntry: Identifiable, Equatable, Sendable {
    let port: Int
    var pids: [Int]
    var scanNote: String?
    var killNote: String?

    var id: Int { port }

    var isActive: Bool { !pids.isEmpty }

    static func inactive(_ port: Int) -> PortEntry {
        PortEntry(port: port, pids: [], scanNote: nil, killNote: nil)
    }
}

enum PortKillOutcome: Equatable {
    case success
    case partialFailures([String])
    case scanOrKillFailed(String)
}

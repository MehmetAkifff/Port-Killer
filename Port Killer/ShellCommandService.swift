//
//  ShellCommandService.swift
//  Port Killer
//

import Foundation

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

/// Runs `/usr/sbin/lsof`, `/bin/kill`, etc. via `Process` (no shell interpolation).
final class ShellCommandService: @unchecked Sendable {

    nonisolated init() {}

    func run(executable: String, arguments: [String]) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ShellResult(stdout: stdout, stderr: stderr, terminationStatus: process.terminationStatus)
    }

    /// Resolves listener PIDs for a port. Tries TCP LISTEN first (IPv4/IPv6, e.g. Python `http.server` on `::`),
    /// then broader `-i :PORT` so older `lsof` / edge cases still match.
    func pidsListening(on port: Int) throws -> ShellResult {
        let strategies: [[String]] = [
            ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"],
            ["-nP", "-i", ":\(port)", "-t"],
            ["-i", ":\(port)", "-t"],
        ]

        var merged = Set<Int>()
        var stderrAccum = ""
        var lastStatus: Int32 = 1

        for args in strategies {
            let r = try run(executable: "/usr/sbin/lsof", arguments: args)
            lastStatus = r.terminationStatus
            stderrAccum += r.stderr
            for line in r.stdout.split(whereSeparator: \.isNewline) {
                let s = String(line).trimmingCharacters(in: .whitespaces)
                if let pid = Int(s) {
                    merged.insert(pid)
                }
            }
            if !merged.isEmpty { break }
        }

        let sorted = merged.sorted().map(String.init).joined(separator: "\n")
        let stdout = sorted.isEmpty ? "" : sorted + "\n"
        return ShellResult(
            stdout: stdout,
            stderr: stderrAccum,
            terminationStatus: merged.isEmpty ? lastStatus : 0
        )
    }

    /// `kill -9` with one or more PIDs.
    func forceKill(pids: [Int]) throws -> ShellResult {
        guard !pids.isEmpty else {
            return ShellResult(stdout: "", stderr: "", terminationStatus: 0)
        }
        let args = ["-9"] + pids.map(String.init)
        return try run(executable: "/bin/kill", arguments: args)
    }
}

//
//  VersionInfo.swift
//  Flux
//
//  Minimal git commit verification - no emojis, text-only status
//

import Foundation
import SwiftUI

struct VersionInfo {
    /// The git commit hash embedded at build time
    static var embeddedCommit: String {
        Bundle.main.infoDictionary?["GitCommit"] as? String ?? "unknown"
    }
    
    /// Short hash (first 7 chars) for display
    static var shortCommit: String {
        String(embeddedCommit.prefix(7))
    }
    
    /// Check if running app matches the latest commit in the repo
    static func verifyAgainstRepo() -> (isMatch: Bool, repoCommit: String?) {
        let repoPath = "/Users/jcbbge/flux"
        
        guard FileManager.default.fileExists(atPath: repoPath) else {
            return (false, nil)
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath, "rev-parse", "--short", "HEAD"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let repoCommit = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !repoCommit.isEmpty else {
                return (false, nil)
            }
            
            let isMatch = embeddedCommit.hasPrefix(repoCommit) || repoCommit.hasPrefix(embeddedCommit)
            return (isMatch, repoCommit)
            
        } catch {
            return (false, nil)
        }
    }
    
    /// Status indicator text - no emojis, minimal style
    static var statusIndicator: String {
        let result = verifyAgainstRepo()
        if result.repoCommit == nil {
            return "[?]"
        }
        return result.isMatch ? "[✓]" : "[X]"
    }
}

// MARK: - Sidebar Header Integration

struct VersionInfoBar: View {
    @Environment(\.colorScheme) var colorScheme
    
    var textColor: Color {
        colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text("build:")
                .font(.system(size: 10))
                .foregroundColor(textColor)
            
            Text(VersionInfo.shortCommit)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(textColor)
            
            Text(VersionInfo.statusIndicator)
                .font(.system(size: 10))
                .foregroundColor(statusColor)
            
            Spacer()
        }
    }
    
    var statusColor: Color {
        let result = VersionInfo.verifyAgainstRepo()
        if result.repoCommit == nil {
            return .orange
        }
        return result.isMatch ? Color.gray.opacity(0.6) : .red
    }
}

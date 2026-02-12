//
//  VersionInfo.swift
//  Flux
//
//  Minimal git commit verification. Indicator first: [-] hash or [✓] hash
//

import Foundation
import SwiftUI

struct VersionInfo {
    static var embeddedCommit: String {
        Bundle.main.infoDictionary?["GitCommit"] as? String ?? "unknown"
    }
    
    static var shortCommit: String {
        String(embeddedCommit.prefix(7))
    }
    
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
    
    static var statusIndicator: String {
        let result = verifyAgainstRepo()
        if result.repoCommit == nil {
            return "[?]"
        }
        return result.isMatch ? "[✓]" : "[-]"
    }
}

// MARK: - Sidebar Integration

struct VersionInfoBar: View {
    @Environment(\.colorScheme) var colorScheme
    
    var textColor: Color {
        colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(VersionInfo.statusIndicator)
                .font(.system(size: 10))
                .foregroundColor(textColor)
            
            Text(VersionInfo.shortCommit)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(textColor)
            
            Spacer()
        }
    }
}

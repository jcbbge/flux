//
//  VersionInfo.swift
//  Flux
//
//  Created by Claude on 2/12/26.
//  Embeds and displays git commit hash with verification.
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
    /// Returns: (isMatch: Bool, repoCommit: String?, error: String?)
    static func verifyAgainstRepo() -> (isMatch: Bool, repoCommit: String?, error: String?) {
        let repoPath = "/Users/jcbbge/flux"
        
        // Check if repo exists
        guard FileManager.default.fileExists(atPath: repoPath) else {
            return (false, nil, "Repo not found")
        }
        
        // Get HEAD commit from repo
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
                return (false, nil, "Failed to read repo commit")
            }
            
            let isMatch = embeddedCommit.hasPrefix(repoCommit) || repoCommit.hasPrefix(embeddedCommit)
            return (isMatch, repoCommit, nil)
            
        } catch {
            return (false, nil, "Git error: \(error.localizedDescription)")
        }
    }
    
    /// Formatted status message for UI
    static var statusText: String {
        let result = verifyAgainstRepo()
        
        if let error = result.error {
            return "Commit: \(shortCommit) (⚠️ \(error))"
        }
        
        if result.isMatch {
            return "Commit: \(shortCommit) ✅"
        } else {
            return "Commit: \(shortCommit) ❌ (repo: \(result.repoCommit ?? "unknown"))"
        }
    }
    
    /// Color indicator for status
    static var statusColor: Color {
        let result = verifyAgainstRepo()
        
        if result.error != nil {
            return .orange
        }
        
        return result.isMatch ? .green : .red
    }
}

// MARK: - SwiftUI View Extension

struct VersionInfoView: View {
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            isExpanded.toggle()
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(VersionInfo.statusColor)
                    .frame(width: 8, height: 8)
                
                Text(VersionInfo.shortCommit)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(colorScheme == .light ? .gray : .gray.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .help(VersionInfo.statusText)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Build Info")
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(VersionInfo.statusColor)
                        .frame(width: 10, height: 10)
                }
                
                Divider()
                
                Group {
                    HStack {
                        Text("Embedded:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(VersionInfo.embeddedCommit)
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    let result = VersionInfo.verifyAgainstRepo()
                    
                    if let repoCommit = result.repoCommit {
                        HStack {
                            Text("Repo HEAD:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(repoCommit)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    
                    if let error = result.error {
                        HStack {
                            Text("Error:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else if result.isMatch {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Build matches repo")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Build differs from repo")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .frame(width: 280)
        }
    }
}

// MARK: - Preview
#Preview {
    VersionInfoView()
        .padding()
}

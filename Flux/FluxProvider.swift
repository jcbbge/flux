//
//  FluxProvider.swift
//  Flux
//
//  Created by opencode on 2/10/26.
//  Protocol and File-backed implementation for FluxEntry operations.
//

import Foundation

protocol FluxProvider {
    func writeFluxEntry(_ entry: FluxEntry, project: String? = nil) async throws -> URL
    func scanFluxEntries(scope: FluxScope, project: String? = nil) async -> [FluxEntry]
    func searchFlux(query: String, scope: FluxScope, project: String? = nil) async -> [FluxEntry]
    func loadDaily() async -> FluxEntry?
    func generateFilename(for type: FluxType, project: String? = nil) -> String
}

class FileFluxProvider: FluxProvider {
    private let workspaceURL = URL(fileURLWithPath: "/Users/jcbbge/flux/workspace")
    private let userProjectsURL = URL(fileURLWithPath: "/Users/jcbbge")  // Root for globbing projects
    
    init() {
        createDirsIfNeeded()
    }
    
    private func createDirsIfNeeded() {
        let dirs = ["entries", "logs", "metrics", "projects"]
        for dir in dirs {
            let url = workspaceURL.appendingPathComponent(dir)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func writeFluxEntry(_ entry: FluxEntry, project: String? = nil) async throws -> URL {
        let filename = generateFilename(for: .journal, project: project)  // Default type; adjust if needed
        let targetDir: URL
        if let project = project {
            targetDir = workspaceURL.appendingPathComponent("projects").appendingPathComponent(project)
        } else {
            targetDir = workspaceURL.appendingPathComponent("entries")
        }
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let fileURL = targetDir.appendingPathComponent(filename)
        let content = entry.embedMeta(entry.fluxMeta ?? FluxMeta(fluxType: "journal"))
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    func scanFluxEntries(scope: FluxScope, project: String? = nil) async -> [FluxEntry] {
        var entries: [FluxEntry] = []
        let targetDirs: [URL]
        if let project = project {
            let projectPath = URL(fileURLWithPath: "/Users/jcbbge/\(project)/workspace")
            targetDirs = [projectPath]
        } else {
            targetDirs = [workspaceURL]
        }
        
        for dir in targetDirs {
            let mdFiles = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "md" }
            for fileURL in mdFiles ?? [] {
                if let entry = FluxEntry.parse(from: fileURL) {
                    entries.append(entry)
                }
            }
        }
        
        // Sort by date descending (parse from filename)
        return entries.sorted { entry1, entry2 in
            // Extract timestamp from filename
            let date1 = extractDate(from: entry1.filename)
            let date2 = extractDate(from: entry2.filename)
            return date1 > date2
        }
    }
    
    private func extractDate(from filename: String) -> Date {
        // Direct string extraction: timestamp is first 19 chars (yyyy-MM-dd-HH-mm-ss)
        let prefix = filename.prefix(19)
        let dateString = String(prefix)
        if prefix.count == 19 && dateString.contains("-") {
            return DateFormatterCache.shared.date(from: dateString, format: "yyyy-MM-dd-HH-mm-ss") ?? Date()
        }
        return Date()
    }
    
    func searchFlux(query: String, scope: FluxScope, project: String? = nil) async -> [FluxEntry] {
        let allEntries = await scanFluxEntries(scope: .all, project: project)
        return allEntries.filter { entry in
            query.lowercased().split(separator: " ").allSatisfy { term in
                entry.content.lowercased().contains(term) || entry.fluxMeta?.tags.contains(where: { $0.lowercased().contains(term) }) ?? false
            }
        }
    }
    
    func loadDaily() async -> FluxEntry? {
        let today = DateFormatterCache.shared.string(from: Date(), format: "yyyy-MM-dd")
        let entries = await scanFluxEntries(scope: .entries, project: nil)
        return entries.first { entry in
            entry.filename.hasPrefix("\(today)-")
        }
    }
    
    func generateFilename(for type: FluxType, project: String? = nil) -> String {
        let timestamp = DateFormatterCache.shared.string(from: Date(), format: "yyyy-MM-dd-HH-mm-ss")
        if let project = project {
            return "\(timestamp)-\(project).md"
        }
        return "\(timestamp).md"
    }
}

extension DateFormatter {
    static func matchToDate(string: String, range: Range<String.Index>) -> String? {
        let fullDateStr = string[range]
        return String(fullDateStr)
    }
}
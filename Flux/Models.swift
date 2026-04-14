//
//  Models.swift
//  Flux
//
//  Created by opencode on 2/10/26.
//  Defines FluxEntry and FluxMeta for MD parsing/enrichment.
//

import Foundation
import SwiftUI

struct FluxMeta: Codable, Equatable {
    let fluxTitle: String?
    let fluxType: String
    let category: String?
    let summary: String?
    let tags: [String]
    let links: [UUID]
    let insights: [String]
    let embedding: [Float]?
    
    init(fluxTitle: String? = nil, fluxType: String, category: String? = nil, summary: String? = nil, tags: [String] = [], links: [UUID] = [], insights: [String] = [], embedding: [Float]? = nil) {
        self.fluxTitle = fluxTitle
        self.fluxType = fluxType
        self.category = category
        self.summary = summary
        self.tags = tags
        self.links = links
        self.insights = insights
        self.embedding = embedding
    }
}

extension FluxMeta: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(fluxType)
        hasher.combine(tags.sorted())
        hasher.combine(links.sorted { $0.uuidString < $1.uuidString })
        // Ignore optional fields for hash
    }
}

struct FluxEntry: Identifiable, Equatable {
    let id: UUID
    let date: String  // Display, e.g., "Feb 10"
    let filename: String  // e.g., "2026-02-10-12-00-00.md"
    let content: String  // Full text with frontmatter
    let fluxMeta: FluxMeta?
    
    var title: String {
        fluxMeta?.fluxTitle ?? content.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? filename
    }
    
    static func parse(from path: URL) -> FluxEntry? {
        let filename = path.lastPathComponent

        guard path.pathExtension.lowercased() == "md" else {
            print("[FluxEntry.parse] Skipping non-markdown file: \(filename)")
            return nil
        }

        do {
            let content = try String(contentsOf: path, encoding: .utf8)
            let parsedDate = parseDate(from: filename, fileURL: path)
            let displayDate = DateFormatterCache.shared.string(from: parsedDate, format: "MMM d")
            let meta = parseFrontmatter(from: content, filename: filename)

            return FluxEntry(
                id: UUID(),
                date: displayDate,
                filename: filename,
                content: content,
                fluxMeta: meta
            )
        } catch {
            print("[FluxEntry.parse] Failed to read \(filename): \(error)")
            return nil
        }
    }

    private static func parseDate(from filename: String, fileURL: URL) -> Date {
        let basename = fileURL.deletingPathExtension().lastPathComponent

        if basename.count >= 10 {
            let dayPrefix = String(basename.prefix(10))
            if let date = DateFormatterCache.shared.date(from: dayPrefix, format: "yyyy-MM-dd") {
                return date
            }
        }

        if basename.count >= 19 {
            let timestampPrefix = String(basename.prefix(19))
            if let date = DateFormatterCache.shared.date(from: timestampPrefix, format: "yyyy-MM-dd-HH-mm-ss") {
                return date
            }
        }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fallbackDate = attributes[.creationDate] as? Date ?? attributes[.modificationDate] as? Date {
            print("[FluxEntry.parse] Falling back to file timestamp for \(filename)")
            return fallbackDate
        }

        print("[FluxEntry.parse] Falling back to current date for \(filename)")
        return Date()
    }

    static func parseFrontmatter(from content: String, filename: String = "<unknown>") -> FluxMeta {
        let defaultMeta = FluxMeta(fluxType: FluxType.journal.rawValue)

        guard content.hasPrefix("---\n") else {
            print("[FluxEntry.parseFrontmatter] No frontmatter in \(filename); using defaults")
            return defaultMeta
        }

        let rest = content.dropFirst(4)
        guard let closeRange = rest.range(of: "\n---") else {
            print("[FluxEntry.parseFrontmatter] Unterminated frontmatter in \(filename); using defaults")
            return defaultMeta
        }

        let yamlBlock = String(rest[..<closeRange.lowerBound])
        var meta = [String: Any]()

        yamlBlock.split(separator: "\n", omittingEmptySubsequences: false).forEach { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }

            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                print("[FluxEntry.parseFrontmatter] Skipping malformed line in \(filename): \(trimmed)")
                return
            }

            let key = String(trimmed[..<colonIndex])
            let valueStart = trimmed.index(after: colonIndex)
            let value = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)

            if value.hasPrefix("[") && value.hasSuffix("]") {
                let inner = value.dropFirst().dropLast()
                let list = inner
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if key == "links" {
                    meta[key] = list.compactMap { UUID(uuidString: $0) }
                } else {
                    meta[key] = list
                }
            } else if key == "links" {
                let links = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .compactMap { UUID(uuidString: $0) }
                meta[key] = links
            } else {
                meta[key] = value
            }
        }

        let fluxType = (meta["fluxType"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if fluxType == nil || fluxType?.isEmpty == true {
            print("[FluxEntry.parseFrontmatter] Missing fluxType in \(filename); defaulting to \(FluxType.journal.rawValue)")
        }

        let resolvedFluxType: String
        if let fluxType, !fluxType.isEmpty {
            resolvedFluxType = fluxType
        } else {
            resolvedFluxType = FluxType.journal.rawValue
        }
        let fluxTitle = meta["fluxTitle"] as? String
        let category = meta["category"] as? String
        let summary = meta["summary"] as? String
        let tags = meta["tags"] as? [String] ?? []
        let links = meta["links"] as? [UUID] ?? []
        let insights = meta["insights"] as? [String] ?? []

        return FluxMeta(
            fluxTitle: fluxTitle,
            fluxType: resolvedFluxType,
            category: category,
            summary: summary,
            tags: tags,
            links: links,
            insights: insights
        )
    }

    static func generateFilename(for type: String, project: String? = nil) -> String {
        let timestamp = DateFormatterCache.shared.string(from: Date(), format: "yyyy-MM-dd-HH-mm-ss")
        if let project = project {
            return "\(timestamp)-\(project).md"
        }
        return "\(timestamp).md"
    }
    
    func embedMeta(_ meta: FluxMeta) -> String {
        let yaml = """
        ---
        fluxTitle: \(meta.fluxTitle ?? "")
        fluxType: \(meta.fluxType)
        category: \(meta.category ?? "")
        summary: \(meta.summary ?? "")
        tags: \(meta.tags)
        links: \(meta.links.map { $0.uuidString })
        insights: \(meta.insights)
        ---
        
        """
        return yaml + content
    }
    
    static func == (lhs: FluxEntry, rhs: FluxEntry) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.fluxMeta == rhs.fluxMeta
    }
}

enum FluxType: String, CaseIterable, Codable {
    case journal = "journal"
    case task = "task"
    case idea = "idea"
    case reminder = "reminder"
    case report = "report"
    case projectDump = "projectDump"
    case note = "note"
    case research = "research"
    case metrics = "metrics"
    case prd = "prd"
}

enum FluxScope: String {
    case all = "all"
    case entries = "entries"
    case tasks = "tasks"
    case ideas = "ideas"
    case projects = "projects"
}

// MARK: - Shared Data Store
@MainActor
class FluxDataStore: ObservableObject {
    static let shared = FluxDataStore()
    
    @Published var entries: [HumanEntry] = []
    @Published var entryDictionary: [UUID: HumanEntry] = [:]
    @Published var projects: [Project] = []
    @Published var todos: [TodoItem] = []
    
    private let fileManager = FileManager.default
    private var fileMonitor: Timer?
    
    private init() {
        loadExistingEntries()
        startFileMonitoring()
    }
    
    private func getDocumentsDirectory() -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent("flux", isDirectory: true)
            .appendingPathComponent("Entries", isDirectory: true)
    }
    
    private func startFileMonitoring() {
        // Poll for file changes every 2 seconds
        fileMonitor = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkForChanges()
            }
        }
    }
    
    private func checkForChanges() {
        let documentsDirectory = getDocumentsDirectory()
        
        guard let files = try? fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) else { return }
        let mdFiles = files.filter { $0.pathExtension == "md" }
        
        // Check if file count changed
        if mdFiles.count != entries.count {
            print("File count changed, reloading entries...")
            loadExistingEntries()
            return
        }
    }
    
    func loadExistingEntries() {
        let documentsDirectory = getDocumentsDirectory()
        print("[FluxDataStore] Loading entries from: \(documentsDirectory.path)")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            print("[FluxDataStore] Found \(mdFiles.count) .md files")
            
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date, content: String)? in
                let filename = fileURL.lastPathComponent
                
                // Parse date from filename (new format: YYYY-MM-DD-XXXXXXXX.md)
                let dateString = String(filename.prefix(10)) // YYYY-MM-DD
                let displayDate: String
                let sortDate: Date
                
                if let parsedDate = DateFormatterCache.shared.date(from: dateString, format: "yyyy-MM-dd") {
                    sortDate = parsedDate
                    displayDate = DateFormatterCache.shared.string(from: parsedDate, format: "MMM d")
                } else {
                    // Fallback: use file creation date
                    if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let creationDate = attrs[.creationDate] as? Date {
                        sortDate = creationDate
                        displayDate = DateFormatterCache.shared.string(from: creationDate, format: "MMM d")
                    } else {
                        sortDate = Date()
                        displayDate = "Unknown"
                    }
                }
                
                // Extract UUID from filename (last 8 chars before .md)
                let idString = String(filename.dropLast(3).suffix(8))
                let id = UUID(uuidString: idString.uppercased()) ?? UUID()
                
                // Read preview
                let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                let (_, bodyContent) = parseFrontmatter(from: content)
                let previewText = bodyContent.prefix(100).replacingOccurrences(of: "\n", with: " ")
                
                let entry = HumanEntry(
                    id: id,
                    date: displayDate,
                    filename: filename,
                    previewText: String(previewText),
                    entryType: .text,
                    videoFilename: nil
                )
                
                return (entry, sortDate, content)
            }
            
            // Sort by date descending
            let sortedEntries = entriesWithDates.sorted { $0.date > $1.date }.map { $0.entry }
            
            self.entries = sortedEntries
            self.entryDictionary = Dictionary(uniqueKeysWithValues: sortedEntries.map { ($0.id, $0) })
            
            print("[FluxDataStore] Loaded \(self.entries.count) entries")
            
        } catch {
            print("[FluxDataStore] Error loading entries: \(error)")
        }
    }
    
    func refresh() {
        loadExistingEntries()
    }
    
    private nonisolated func parseFrontmatter(from content: String) -> (metadata: [String: String], body: String) {
        guard content.hasPrefix("---") else {
            return ([:], content)
        }
        
        // Find the end of frontmatter
        let startIndex = content.index(content.startIndex, offsetBy: 3)
        guard let endRange = content[startIndex...].range(of: "---") else {
            return ([:], content)
        }
        
        let frontmatterEnd = content.index(startIndex, offsetBy: endRange.lowerBound.utf16Offset(in: content[startIndex...]))
        let frontmatter = String(content[startIndex..<frontmatterEnd]).trimmingCharacters(in: .newlines)
        let body = String(content[content.index(frontmatterEnd, offsetBy: 3)...]).trimmingCharacters(in: .newlines)
        
        // Parse simple key: value pairs
        var metadata: [String: String] = [:]
        for line in frontmatter.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }
        
        return (metadata, body)
    }
}

// MARK: - Equatable for UUID array
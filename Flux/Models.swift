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
        do {
            let content = try String(contentsOf: path, encoding: .utf8)
            let filename = path.lastPathComponent
            // Direct extraction: timestamp is first 19 chars (yyyy-MM-dd-HH-mm-ss)
            let prefix = filename.prefix(19)
            guard prefix.count == 19 && filename.contains("-") else { return nil }
            let dateString = String(prefix)
            guard let date = DateFormatterCache.shared.date(from: dateString, format: "yyyy-MM-dd-HH-mm-ss") else { return nil }
            let displayDate = DateFormatterCache.shared.string(from: date, format: "MMM d")
            let uuid = UUID()
            
            // Parse YAML frontmatter
            let meta = parseFrontmatter(from: content)
            
            return FluxEntry(id: uuid, date: displayDate, filename: filename, content: content, fluxMeta: meta)
        } catch {
            print("Parse error for \(path): \(error)")
            return nil
        }
    }
    
    static func parseFrontmatter(from content: String) -> FluxMeta? {
        // Check for frontmatter delimiters
        guard content.hasPrefix("---\n") else { return nil }
        
        // Find the closing ---
        let rest = content.dropFirst(4) // Skip "---\n"
        guard let closeRange = rest.range(of: "\n---") else { return nil }
        let yamlBlock = String(rest[..<closeRange.lowerBound])
        
        // Simple YAML parse (key: value)
        var meta = [String: Any]()
        yamlBlock.split(separator: "\n", omittingEmptySubsequences: false).forEach { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return } // Skip empty/comment lines
            
            // Find first colon
            guard let colonIndex = trimmed.firstIndex(of: ":") else { return }
            let key = String(trimmed[..<colonIndex])
            let valueStart = trimmed.index(after: colonIndex)
            let value = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)
            
            // Parse value (basic: array or string)
            if value.hasPrefix("[") && value.hasSuffix("]") {
                let inner = value.dropFirst().dropLast()
                let tags = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                meta[key] = tags
            } else if key == "links" {
                let links = value.split(separator: ",").compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }
                meta[key] = links
            } else {
                meta[key] = value
            }
        }
        // Build FluxMeta from parsed
        guard let fluxType = meta["fluxType"] as? String else { return nil }
        let fluxTitle = meta["fluxTitle"] as? String
        let category = meta["category"] as? String
        let summary = meta["summary"] as? String
        let tags = meta["tags"] as? [String] ?? []
        let links = meta["links"] as? [UUID] ?? []
        let insights = meta["insights"] as? [String] ?? []
        // Embedding skipped for basic parse
        return FluxMeta(fluxTitle: fluxTitle, fluxType: fluxType, category: category, summary: summary, tags: tags, links: links, insights: insights)
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

// MARK: - Equatable for UUID array
extension UUID: Hashable {}  // Already conforms, but explicit for clarity
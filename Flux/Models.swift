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
            let timestampMatch = filename.range(of: "^(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})", options: .regularExpression)
            guard let match = timestampMatch else { return nil }
            let dateString = String(filename[match])
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
        guard let range = content.range(of: "---\\n(.*?)(?=\\n---\\n|\\z)", options: .regularExpression, range: content.startIndex..<content.endIndex) else {
            return nil
        }
        let yamlBlock = String(content[range])
        // Simple YAML parse (key: value) - extend with Yams SPM if needed
        var meta = [String: Any]()
        yamlBlock.components(separatedBy: .newlines).forEach { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonRange = trimmed.range(of: "(.*?):\\s*(.*)", options: .regularExpression) {
                let key = String(trimmed[colonRange.lowerBound..<trimmed[trimmed.index(colonRange.lowerBound, offsetBy: trimmed.distance(from: colonRange.lowerBound, to: colonRange.upperBound)) - 1]])
                let value = String(trimmed[trimmed.index(colonRange.upperBound, offsetBy: 1)..<trimmed.endIndex])
                // Parse value (basic: array or string)
                if value.hasPrefix("[") && value.hasSuffix("]") {
                    let tags = value.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                    meta[key] = tags
                } else if key == "links" {
                    let links = value.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)).compactMap { UUID(uuidString: $0) } }
                    meta[key] = links
                } else {
                    meta[key] = value
                }
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
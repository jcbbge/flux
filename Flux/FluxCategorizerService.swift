//
//  FluxCategorizerService.swift
//  Flux
//
//  Created by opencode on 2/10/26.
//  Uses Docker Ollama for enrichment/propagation/search.
//

import Foundation

class FluxCategorizerService {
    private let ollamaURL = URL(string: "http://localhost:7102/api/chat")!
    private let embeddingURL = URL(string: "http://localhost:7102/api/embeddings")!
    private let model = "qwen2.5:0.5b"
    private let workspaceMDPath = "/Users/jcbbge/spacely/workspace/WORKSPACE.md"
    
    private var workspaceConventions: String {
        (try? String(contentsOfFile: workspaceMDPath)) ?? ""
    }
    
    func enrichFlux(_ entry: FluxEntry) async -> FluxMeta? {
        let prompt = """
        Per WORKSPACE.md conventions: Enrich this flux entry as high-level JSON only.
        Content: \(entry.content)
        Output: { "fluxTitle": "Human-readable title (1-2 words from content)", "fluxType": "journal" (infer if missing), "category": "e.g., Reflection", "summary": "1-2 sentence roll-up", "tags": ["ui", "dev"], "links": [], "insights": ["Link to similar?", "Stagnation flag?"] }
        No deep analysis; keep simple.
        """
        
        return await callCategorizer(with: prompt, type: .enrich)
    }
    
    func propagateFluxLinks(_ entry: FluxEntry, scope: FluxScope = .all) async -> [UUID] {
        let context = "Scope: \(scope.rawValue). Existing links: \(entry.fluxMeta?.links ?? [])"
        let prompt = """
        Per WORKSPACE.md: Suggest propagation/backlinks for this flux (UUIDs only in array).
        Entry: \(entry.filename)
        Context: \(context)
        Output: JSON { "links": ["uuid-task-abc123"] } (2-3 suggestions from scope; no new ID creation).
        """
        
        if let result = await callCategorizer(with: prompt, type: .propagate) {
            if let linksArray = result["links"] as? [String] {
                return linksArray.compactMap { UUID(uuidString: $0) }
            }
        }
        return []
    }
    
    func searchFluxSimilar(_ query: String, threshold: Float = 0.7) async -> [FluxEntry] {
        // Embed query
        let embedding = await generateEmbedding(for: query)
        // For full impl, query stored embeddings; stub with keyword match for now
        let allEntries = await FileFluxProvider().scanFluxEntries(scope: .all, project: nil)
        return allEntries.filter { entry in
            // Simple cosine stub; extend with vector match
            query.lowercased().commonWords(with: entry.content.lowercased()).count > 2
        }
    }
    
    func suggestFluxInsights(_ entry: FluxEntry) async -> [String] {
        let prompt = """
        Per WORKSPACE.md: High-level insights for this flux (2-3 lines, no deep analysis).
        Entry: \(entry.content)
        Output: JSON { "insights": ["Stagnation? Link to project?"] }
        """
        
        if let result = await callCategorizer(with: prompt, type: .insights) {
            return result["insights"] as? [String] ?? []
        }
        return []
    }
    
    private func callCategorizer(with prompt: String, type: EnrichmentType) async -> [String: Any]? {
        var request = URLRequest(url: ollamaURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": "Follow WORKSPACE.md conventions. Output valid JSON only for \(type.rawValue)."],
            ["role": "user", "content": prompt]
        ]
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "format": "json",
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let message = json?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return try JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as? [String: Any]
                }
            }
        } catch {
            print("Categorizer error: \(error)")
        }
        return nil
    }
    
    private func generateEmbedding(for text: String) async -> [Float]? {
        var request = URLRequest(url: embeddingURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "nomic-embed-text",
            "prompt": text,
            "encode_plus": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let embed = json?["embedding"] as? [Float] {
                return embed
            }
        } catch {
            print("Embedding error: \(error)")
        }
        return nil
    }
}

enum EnrichmentType: String {
    case enrich = "enrich"
    case propagate = "propagate"
    case insights = "insights"
}

// MARK: - Extension for common words (stub for similarity)
extension String {
    func commonWords(with other: String) -> Set<String> {
        let selfWords = Set(self.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let otherWords = Set(other.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        return selfWords.intersection(otherWords)
    }
}
//
//  FluxCategorizerService.swift
//  Flux
//
//  Created by opencode on 2/10/26.
//  Uses Docker Ollama for enrichment/propagation/search.
//

import Foundation

class FluxCategorizerService {
    private let generateURL = URL(string: "http://localhost:7102/api/generate")!
    private let embeddingURL = URL(string: "http://localhost:7102/api/embeddings")!
    private let model = "qwen2.5:0.5b"
    private let workspaceMDPath = "/Users/jcbbge/spacely/workspace/WORKSPACE.md"
    
    private var workspaceConventions: String {
        (try? String(contentsOfFile: workspaceMDPath)) ?? ""
    }
    
    func enrichFlux(_ entry: FluxEntry) async -> FluxMeta? {
        let prompt = """
        {"title": "", "type": "journal", "cat": "", "sum": "", "tags": [], "links": [], "insights": []}
        \(entry.content.prefix(200))
        """
        guard let result = await callCategorizer(with: prompt, type: .enrich) else { return nil }
        return FluxMeta(
            fluxTitle: result["title"] as? String,
            fluxType: result["type"] as? String ?? "journal",
            category: result["cat"] as? String ?? result["category"] as? String,
            summary: result["sum"] as? String ?? result["summary"] as? String,
            tags: result["tags"] as? [String] ?? [],
            links: (result["links"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? [],
            insights: result["insights"] as? [String] ?? []
        )
    }
    
    func propagateFluxLinks(_ entry: FluxEntry, scope: FluxScope = .all) async -> [UUID] {
        let prompt = """
        JSON: {"links": ["uuid1", "uuid2"]}
        Suggest 2-3 existing UUIDs to link to: \(entry.filename)
        """
        
        if let result = await callCategorizer(with: prompt, type: .propagate) {
            if let linksArray = result["links"] as? [String] {
                return linksArray.compactMap { UUID(uuidString: $0) }
            }
        }
        return []
    }
    
    func searchFluxSimilar(_ query: String, threshold: Float = 0.7) async -> [FluxEntry] {
        // Embed query (future: use for vector search)
        _ = await generateEmbedding(for: query)
        // For full impl, query stored embeddings; stub with keyword match for now
        let allEntries = await FileFluxProvider().scanFluxEntries(scope: .all, project: nil)
        return allEntries.filter { entry in
            // Simple cosine stub; extend with vector match
            query.lowercased().commonWords(with: entry.content.lowercased()).count > 2
        }
    }
    
    func suggestFluxInsights(_ entry: FluxEntry) async -> [String] {
        let prompt = """
        JSON: {"insights": ["insight1", "insight2"]}
        1-line insights for: \(entry.content.prefix(100))
        """
        
        if let result = await callCategorizer(with: prompt, type: .insights) {
            return result["insights"] as? [String] ?? []
        }
        return []
    }
    
    func callCategorizer(with prompt: String, type: EnrichmentType) async -> [String: Any]? {
        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": "JSON only. No text.\n\(prompt)",
            "stream": false,
            "temperature": 0.2,
            "top_p": 0.8,
            "repeat_penalty": 1.05,
            "max_tokens": 200
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let resp = json?["response"] as? String {
                    return try JSONSerialization.jsonObject(with: resp.data(using: .utf8)!) as? [String: Any]
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
    case report = "report"
}

// MARK: - Extension for common words (stub for similarity)
extension String {
    func commonWords(with other: String) -> Set<String> {
        let selfWords = Set(self.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let otherWords = Set(other.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        return selfWords.intersection(otherWords)
    }
}
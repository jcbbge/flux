//
//  LLMService.swift
//  Flux
//
//  Created by opencode on 2/10/26.
//  Adds Ollama integration for note enrichment.
//

import Foundation

class LLMService: ObservableObject {
    private let ollamaURL = URL(string: "http://localhost:7102/api/chat")!
    private let model = "qwen2.5:0.5b"
    
    func enrichNote(with text: String) async -> [String: Any]? {
        let prompt = """
        Analyze this journal entry. Categorize it, provide a summary, tags, and insights.
        Output only valid JSON: { "category": "string", "summary": "string", "tags": ["string", ...], "insights": ["string", ...] }
        Entry: \(text)
        """
        
        var request = URLRequest(url: ollamaURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": false,
            "format": "json",
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let message = response?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return try JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as? [String: Any]
            }
        } catch {
            print("LLM enrichment error: \(error)")
        }
        return nil
    }
}
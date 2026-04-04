import Foundation
import SwiftUI

struct AIProvider {
    let name: String
    let baseURL: URL
    let chatModel: String
    let embedModel: String

    static var local: AIProvider {
        AIProvider(
            name: "Ollama (local)",
            baseURL: URL(string: "http://localhost:8001")!,
            chatModel: "qwen2.5:0.5b",
            embedModel: "nomic-embed-text"
        )
    }
}

enum AIServiceStatus: Equatable {
    case unknown
    case active
    case degraded(String)
    case offline(String)

    var isHealthy: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var reason: String? {
        switch self {
        case .unknown, .active:
            return nil
        case .degraded(let reason), .offline(let reason):
            return reason
        }
    }
}

actor AIService: ObservableObject {
    static let shared = AIService()

    @MainActor @Published var status: AIServiceStatus = .unknown

    private var provider: AIProvider
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
        self.provider = .local
    }

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
    }

    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let activeProvider = try resolvedProvider()
        let endpoint = activeProvider.baseURL.appendingPathComponent("api/chat")

        let payload = OllamaChatRequest(
            model: activeProvider.chatModel,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            stream: false
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if isConnectionRefused(error) {
                await setStatus(.offline("Ollama not running — start with: ollama serve"))
            } else {
                await setStatus(.offline("Network unavailable"))
            }
            throw AIServiceError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await setStatus(.degraded("Response parse error"))
            throw AIServiceError.malformedJSON("Missing HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            await setStatus(.degraded("Ollama error (\(httpResponse.statusCode))"))
            throw AIServiceError.httpStatus(httpResponse.statusCode, body)
        }

        do {
            let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            guard let content = decoded.message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                await setStatus(.degraded("Response parse error"))
                throw AIServiceError.emptyResponse
            }

            await setStatus(.active)
            return content
        } catch {
            await setStatus(.degraded("Response parse error"))
            throw AIServiceError.malformedJSON(String(data: data, encoding: .utf8) ?? "<non-utf8>")
        }
    }

    func embed(_ input: String) async throws -> [Float] {
        let activeProvider = try resolvedProvider()
        let endpoint = activeProvider.baseURL.appendingPathComponent("api/embed")

        let payload = OllamaEmbedRequest(model: activeProvider.embedModel, input: input)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if isConnectionRefused(error) {
                await setStatus(.offline("Ollama not running — start with: ollama serve"))
            } else {
                await setStatus(.offline("Network unavailable"))
            }
            throw AIServiceError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await setStatus(.degraded("Response parse error"))
            throw AIServiceError.malformedJSON("Missing HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            await setStatus(.degraded("Ollama error (\(httpResponse.statusCode))"))
            throw AIServiceError.httpStatus(httpResponse.statusCode, body)
        }

        do {
            let decoded = try JSONDecoder().decode(OllamaEmbedResponse.self, from: data)
            guard let vector = decoded.embeddings.first, !vector.isEmpty else {
                await setStatus(.degraded("Response parse error"))
                throw AIServiceError.emptyResponse
            }

            await setStatus(.active)
            return vector
        } catch {
            await setStatus(.degraded("Response parse error"))
            throw AIServiceError.malformedJSON(String(data: data, encoding: .utf8) ?? "<non-utf8>")
        }
    }

    func enrichEntry(_ entry: FluxEntry) async throws -> FluxMeta {
        let prompt = "Return only JSON with keys fluxTitle, fluxType, category, summary, tags, insights. Keep concise."
        let user = "Text:\n\(entry.content)\n\nJSON schema: {\"fluxTitle\":\"\",\"fluxType\":\"journal\",\"category\":\"\",\"summary\":\"\",\"tags\":[],\"insights\":[]}"

        let raw = try await chat(systemPrompt: prompt, userPrompt: user)
        let json = extractJSONObject(from: raw)

        do {
            let decoded = try JSONDecoder().decode(EnrichmentResponse.self, from: Data(json.utf8))
            return FluxMeta(
                fluxTitle: decoded.fluxTitle,
                fluxType: decoded.fluxType.isEmpty ? FluxType.journal.rawValue : decoded.fluxType,
                category: decoded.category,
                summary: decoded.summary,
                tags: decoded.tags,
                links: [],
                insights: decoded.insights,
                embedding: nil
            )
        } catch {
            await setStatus(.degraded("Response parse error"))
            throw AIServiceError.malformedJSON(raw)
        }
    }

    func summarizeEntries(_ entries: [FluxEntry]) async throws -> String {
        let prompt = "Summarize the provided Flux entries in a short paragraph."
        let combined = entries
            .prefix(20)
            .enumerated()
            .map { index, entry in
                "[\(index + 1)] \(entry.title)\n\(entry.content)"
            }
            .joined(separator: "\n\n")

        return try await chat(systemPrompt: prompt, userPrompt: combined)
    }

    func suggestRelated(_ entry: FluxEntry, from candidates: [FluxEntry]) async throws -> [UUID] {
        let prompt = "Return only JSON {\"ids\": [\"uuid\"]}. Pick related candidate IDs only."
        let candidateLines = candidates.map { "\($0.id.uuidString): \($0.title)" }.joined(separator: "\n")
        let user = "Entry:\n\(entry.content)\n\nCandidates:\n\(candidateLines)"

        let raw = try await chat(systemPrompt: prompt, userPrompt: user)
        let json = extractJSONObject(from: raw)

        do {
            let decoded = try JSONDecoder().decode(RelatedIDsResponse.self, from: Data(json.utf8))
            return decoded.ids.compactMap { UUID(uuidString: $0) }
        } catch {
            await setStatus(.degraded("Response parse error"))
            throw AIServiceError.malformedJSON(raw)
        }
    }

    private func resolvedProvider() throws -> AIProvider {
        guard !provider.baseURL.absoluteString.isEmpty else {
            throw AIServiceError.invalidURL
        }
        return provider
    }

    @MainActor
    private func setStatus(_ status: AIServiceStatus) {
        self.status = status
    }

    private func isConnectionRefused(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .cannotConnectToHost, .cannotFindHost:
            return true
        default:
            return false
        }
    }

    private func extractJSONObject(from text: String) -> String {
        if let fencedRange = text.range(of: "```json") {
            let afterFence = text[fencedRange.upperBound...]
            if let closeFence = afterFence.range(of: "```") {
                let candidate = afterFence[..<closeFence.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.first == "{" && candidate.last == "}" {
                    return String(candidate)
                }
            }
        }

        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text
    }
}

enum AIServiceError: LocalizedError {
    case invalidURL
    case transport(Error)
    case httpStatus(Int, String)
    case emptyResponse
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "AI provider URL is invalid."
        case .transport(let error):
            return "Transport error: \(error.localizedDescription)"
        case .httpStatus(let code, let body):
            return "Provider returned HTTP \(code): \(body)"
        case .emptyResponse:
            return "Provider returned an empty response."
        case .malformedJSON(let raw):
            return "Malformed JSON: \(raw)"
        }
    }
}

private struct OllamaChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct OllamaChatResponse: Codable {
    let message: ChatMessage?
}

private struct OllamaEmbedRequest: Codable {
    let model: String
    let input: String
}

private struct OllamaEmbedResponse: Codable {
    let embeddings: [[Float]]
}

private struct EnrichmentResponse: Codable {
    let fluxTitle: String?
    let fluxType: String
    let category: String?
    let summary: String?
    let tags: [String]
    let insights: [String]
}

private struct RelatedIDsResponse: Codable {
    let ids: [String]
}

import Foundation
import SwiftUI

// AIProvider — swappable config
struct AIProvider {
    let name: String
    let endpoint: URL
    let model: String
    var apiKey: String

    static var perplexity: AIProvider {
        AIProvider(
            name: "Perplexity",
            endpoint: URL(string: "https://api.perplexity.ai/v1/chat/completions")!,
            model: "sonar",
            apiKey: ""
        )
    }
}

// AIServiceStatus
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

        var defaultProvider = AIProvider.perplexity
        if let loadedKey = try? Self.loadAPIKey() {
            defaultProvider.apiKey = loadedKey
        }
        self.provider = defaultProvider
    }

    // Key loading: env -> UserDefaults -> throws
    private static func loadAPIKey() throws -> String {
        if let envKey = ProcessInfo.processInfo.environment["PERPLEXITY_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envKey.isEmpty {
            return envKey
        }

        if let defaultsKey = UserDefaults.standard.string(forKey: "aiProviderKey")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !defaultsKey.isEmpty {
            return defaultsKey
        }

        throw AIServiceError.missingAPIKey
    }

    // Update provider at runtime (for future settings UI)
    func setProvider(_ provider: AIProvider) {
        self.provider = provider
    }

    // Core chat call — OpenAI-compatible
    // Updates status on every call (success or failure)
    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let requestPayload: ChatRequest

        do {
            let activeProvider = try resolvedProvider()
            requestPayload = ChatRequest(
                model: activeProvider.model,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: userPrompt)
                ]
            )

            var request = URLRequest(url: activeProvider.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(activeProvider.apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30
            request.httpBody = try JSONEncoder().encode(requestPayload)

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                await setStatus(.offline("Network unavailable"))
                throw AIServiceError.transport(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                await setStatus(.degraded("Response parse error"))
                throw AIServiceError.malformedJSON("Missing HTTP response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                switch httpResponse.statusCode {
                case 401, 403:
                    await setStatus(.offline("Invalid API key"))
                case 429:
                    await setStatus(.offline("Token limit reached — check your Perplexity quota"))
                case 500...599:
                    await setStatus(.degraded("Provider error (\(httpResponse.statusCode))"))
                default:
                    await setStatus(.offline("Request failed (\(httpResponse.statusCode))"))
                }
                throw AIServiceError.httpStatus(httpResponse.statusCode, body)
            }

            do {
                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
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
        } catch let error as AIServiceError {
            if case .missingAPIKey = error {
                await setStatus(.offline("Missing API key"))
            }
            throw error
        } catch {
            await setStatus(.offline("Network unavailable"))
            throw AIServiceError.transport(error)
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
        var activeProvider = provider

        if activeProvider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeProvider.apiKey = try Self.loadAPIKey()
            provider = activeProvider
        }

        guard !activeProvider.endpoint.absoluteString.isEmpty else {
            throw AIServiceError.invalidURL
        }

        return activeProvider
    }

    @MainActor
    private func setStatus(_ status: AIServiceStatus) {
        self.status = status
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
    case missingAPIKey
    case invalidURL
    case transport(Error)
    case httpStatus(Int, String)
    case emptyResponse
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key. Set PPLX_API_KEY or UserDefaults key aiProviderKey."
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

private struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: ChatMessage
    }
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

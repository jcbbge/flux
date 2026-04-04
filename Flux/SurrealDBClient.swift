import Foundation
import SwiftUI

actor SurrealDBClient: ObservableObject {
    static let shared = SurrealDBClient()

    private let baseURL = URL(string: "http://localhost:8002")!
    private let namespace = "dev"
    private let database = "flux"
    private let username = "root"
    private let password = "root"
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session

        Task {
            await ensureSchema()
        }
    }

    private func sql(_ query: String) async throws -> [[String: Any]] {
        let endpoint = baseURL.appendingPathComponent("sql")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(namespace, forHTTPHeaderField: "NS")
        request.setValue(database, forHTTPHeaderField: "DB")

        let credentials = "\(username):\(password)"
        let encodedCredentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query], options: [])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SurrealDBClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw SurrealDBClientError.httpStatus(httpResponse.statusCode, body)
        }

        let raw = try JSONSerialization.jsonObject(with: data, options: [])

        if let statements = raw as? [[String: Any]] {
            return statements
        }

        if let object = raw as? [String: Any],
           let statements = object["result"] as? [[String: Any]] {
            return statements
        }

        throw SurrealDBClientError.unexpectedPayload
    }

    func upsertNote(path: String, contentHash: String, meta: FluxMeta, embedding: [Float]?) async throws {
        let recordID = sqlRecordID(path)
        let escapedPath = sqlString(path)
        let escapedHash = sqlString(contentHash)
        let titleSQL = sqlOptionalString(meta.fluxTitle)
        let summarySQL = sqlOptionalString(meta.summary)
        let tagsSQL = sqlStringArray(meta.tags)
        let insightsSQL = sqlStringArray(meta.insights)
        let embeddingSQL = sqlEmbedding(embedding)

        let query = """
        UPSERT flux_note:`\(recordID)` CONTENT {
            path: '\(escapedPath)',
            content_hash: '\(escapedHash)',
            title: \(titleSQL),
            summary: \(summarySQL),
            tags: \(tagsSQL),
            insights: \(insightsSQL),
            embedding: \(embeddingSQL),
            updated_at: time::now()
        };
        """

        _ = try await sql(query)
    }

    func fetchSimilar(to embedding: [Float], limit: Int) async throws -> [String] {
        _ = embedding
        _ = limit
        return []
    }

    func ensureSchema() async {
        let query = """
        DEFINE NAMESPACE IF NOT EXISTS dev;
        DEFINE DATABASE IF NOT EXISTS flux;
        USE NS dev DB flux;

        DEFINE TABLE IF NOT EXISTS flux_note SCHEMAFULL;
        DEFINE FIELD IF NOT EXISTS path ON flux_note TYPE string;
        DEFINE FIELD IF NOT EXISTS content_hash ON flux_note TYPE string;
        DEFINE FIELD IF NOT EXISTS title ON flux_note TYPE option<string>;
        DEFINE FIELD IF NOT EXISTS summary ON flux_note TYPE option<string>;
        DEFINE FIELD IF NOT EXISTS tags ON flux_note TYPE array;
        DEFINE FIELD IF NOT EXISTS insights ON flux_note TYPE array;
        DEFINE FIELD IF NOT EXISTS embedding ON flux_note TYPE option<array>;
        DEFINE FIELD IF NOT EXISTS updated_at ON flux_note TYPE datetime;
        """

        do {
            _ = try await sql(query)
        } catch {
            print("[SurrealDBClient] Failed to ensure schema: \(error)")
        }
    }

    private func sqlString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    private func sqlRecordID(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "")
    }

    private func sqlOptionalString(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "NONE" }
        return "'\(sqlString(value))'"
    }

    private func sqlStringArray(_ values: [String]) -> String {
        let escaped = values.map { "'\(sqlString($0))'" }.joined(separator: ", ")
        return "[\(escaped)]"
    }

    private func sqlEmbedding(_ values: [Float]?) -> String {
        guard let values else { return "NONE" }
        return "[\(values.map { String($0) }.joined(separator: ", "))]"
    }
}

enum SurrealDBClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String)
    case unexpectedPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid HTTP response from SurrealDB"
        case .httpStatus(let code, let body):
            return "SurrealDB request failed with status \(code): \(body)"
        case .unexpectedPayload:
            return "Unexpected SurrealDB payload"
        }
    }
}

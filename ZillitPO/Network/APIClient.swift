import Foundation

// MARK: - Protocols (matching Zillit main app pattern)

protocol POURLRequestProtocol {
    var urlRequest: URLRequest? { get }
}

// `PODataTaskProtocol` was the original ZillitPO name for the
// `urlDataTask`-providing protocol. It has been replaced by
// `FCCodableDataTask` (defined in `Zillit Utils/NetworkSpecific.swift`),
// which is the parent project's name for the same shape. CodableTask
// extensions now conform to `FCCodableDataTask` directly.

// MARK: - HTTP Method

enum HTTPMethodType: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Client (iOS 13 compatible — no async/await)

class APIClient {
    static let shared = APIClient()
    var baseURL = "https://accounthub-dev.zillit.com"
    var projectId = ""
    var userId = ""
    var isAccountant = false

    let session = URLSession.shared

    private func headers() -> [String: String] {
        ["Content-Type": "application/json", "x-project-id": projectId,
         "x-user-id": userId, "x-is-accountant": String(isAccountant)]
    }

    // MARK: - Build URLRequest (used by PORequest enum)

    func buildRequest(_ method: HTTPMethodType, _ path: String, body: Any? = nil) -> URLRequest? {
        let urlString = path.hasPrefix("http") ? path : "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        for (k, v) in headers() { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body, let data = try? JSONSerialization.data(withJSONObject: body) {
            req.httpBody = data
        }
        return req
    }

    // MARK: - Build Multipart Request (for file uploads)

    func buildMultipartRequest(_ path: String, fileData: Data, fileName: String, mimeType: String, fieldName: String = "file") -> URLRequest? {
        let urlString = path.hasPrefix("http") ? path : "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else { return nil }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(userId, forHTTPHeaderField: "x-user-id")
        req.setValue(String(isAccountant), forHTTPHeaderField: "x-is-accountant")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        return req
    }

    // MARK: - Codable Result Task (typed response — matches Zillit main app pattern)

    func codableResultTask<T: Codable>(with request: URLRequest, completion: @escaping (Result<ZLGenericResponse<T>?, Error>) -> Void) -> URLSessionDataTask {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? ""
        debugPrint("[\(method)] \(urlString)")

        return session.dataTask(with: request) { data, response, error in
            if let error = error {
                debugPrint("  ❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data = data, let http = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            if http.statusCode == 204 {
                debugPrint("  ✅ \(http.statusCode) (no content)")
                completion(.success(nil))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                debugPrint("  ❌ \(http.statusCode): \(msg.prefix(200))")
                completion(.failure(APIError.serverError(http.statusCode, msg)))
                return
            }
            debugPrint("  ✅ \(http.statusCode) (\(data.count) bytes)")

            // Use tryDecode to match original decode behavior exactly
            let decoded = tryDecode(T.self, from: data)
            if decoded == nil {
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                // Suppress the noisy warning when the server explicitly returned
                // `{"data":null}` or `{"data":[]}` — that's a valid "empty" response,
                // not a schema mismatch.
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                let isEmptyEnvelope = trimmed == "{\"data\":null}"
                    || trimmed == "{\"data\": null}"
                    || trimmed == "{\"data\":[]}"
                    || trimmed == "{\"data\": []}"
                if !isEmptyEnvelope {
                    debugPrint("  ⚠️ Decode failed for \(T.self). Raw: \(raw.prefix(500))")
                }
            }
            completion(.success(ZLGenericResponse<T>(data: decoded)))
        }
    }

    // MARK: - Data Result Task (raw Data response — for mutations, PDF, etc.)

    func dataResultTask(with request: URLRequest, completion: @escaping (Result<Data?, Error>) -> Void) -> URLSessionDataTask {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? ""
        debugPrint("[\(method)] \(urlString)")

        return session.dataTask(with: request) { data, response, error in
            if let error = error {
                debugPrint("  ❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data = data, let http = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            if http.statusCode == 204 {
                debugPrint("  ✅ \(http.statusCode) (no content)")
                completion(.success(Data()))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                debugPrint("  ❌ \(http.statusCode): \(msg.prefix(200))")
                completion(.failure(APIError.serverError(http.statusCode, msg)))
                return
            }
            debugPrint("  ✅ \(http.statusCode) (\(data.count) bytes)")
            completion(.success(data))
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL, invalidResponse, serverError(Int, String), decodingError(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .serverError(let c, let m):
            let friendly = APIError.humanizeServerBody(m, statusCode: c)
            return friendly.isEmpty ? "Request failed (\(c))" : friendly
        case .decodingError(let m): return "Decode: \(m)"
        }
    }

    /// Convert a raw server response body into a short user-facing message.
    /// Servers may reply with JSON (`{"error": "…"}` or `{"message": "…"}`),
    /// an HTML error page (Express default: `<pre>Error: …<br>…stack…</pre>`),
    /// or plain text. We try in order:
    ///   1. JSON → pick `error` / `message` / `detail` field
    ///   2. HTML `<pre>…</pre>` → take the first line (before `<br>` or newline)
    ///   3. Strip remaining tags / decode basic entities
    ///   4. Fall back to an HTTP status summary
    /// Output is trimmed and truncated to ~200 chars.
    static func humanizeServerBody(_ body: String, statusCode: Int) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 1. JSON first — the API's canonical error shape.
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["error", "message", "detail", "msg"] {
                if let s = obj[key] as? String, !s.isEmpty { return truncate(s) }
            }
        }

        // 2. Express-style HTML error: the useful line lives inside <pre>.
        var candidate = trimmed
        if let preRange = candidate.range(of: "<pre>"),
           let endRange = candidate.range(of: "</pre>", range: preRange.upperBound..<candidate.endIndex) {
            candidate = String(candidate[preRange.upperBound..<endRange.lowerBound])
            // Stack traces in Express pages start after a literal "<br>" or
            // newline — keep only the first line.
            if let br = candidate.range(of: "<br>") { candidate = String(candidate[..<br.lowerBound]) }
            if let nl = candidate.firstIndex(of: "\n") { candidate = String(candidate[..<nl]) }
        }

        // 3. Strip any remaining tags and decode a few common HTML entities.
        candidate = candidate
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // "Error: <message>" — drop the redundant prefix.
        if candidate.lowercased().hasPrefix("error: ") {
            candidate = String(candidate.dropFirst("error: ".count))
        }

        return truncate(candidate)
    }

    private static func truncate(_ s: String, maxLen: Int = 200) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLen else { return trimmed }
        return trimmed.prefix(maxLen) + "…"
    }
}

// `ZLGenericResponse<T>` is now a typealias for `ZLGenericResponse<T>`,
// defined in `Zillit Utils/RegistrationModel.swift`.

// MARK: - Decode helper

func tryDecode<T: Codable>(_ type: T.Type, from data: Data) -> T? {
    let decoder = JSONDecoder()
    // First attempt: envelope `{ "data": T }`
    var envelopeErr: Error?
    do {
        let w = try decoder.decode(ZLGenericResponse<T>.self, from: data)
        if let r = w.data { return r }
    } catch {
        envelopeErr = error
    }
    // Second attempt: top-level T
    do {
        return try decoder.decode(T.self, from: data)
    } catch {
        logDecodingError(envelopeErr ?? error, for: T.self)
        return nil
    }
}

/// Prints a human-readable breakdown of a `DecodingError` so the
/// warning actually tells us which key/index failed instead of just
/// "decode failed".
fileprivate func logDecodingError(_ error: Error, for type: Any.Type) {
    guard let de = error as? DecodingError else {
        debugPrint("  🔎 \(type) decode error: \(error)")
        return
    }
    func pathString(_ context: DecodingError.Context) -> String {
        context.codingPath.map { key in
            if let i = key.intValue { return "[\(i)]" }
            return key.stringValue
        }.joined(separator: ".")
    }
    switch de {
    case .keyNotFound(let key, let ctx):
        debugPrint("  🔎 \(type) keyNotFound: '\(key.stringValue)' at \(pathString(ctx))")
    case .typeMismatch(let expected, let ctx):
        debugPrint("  🔎 \(type) typeMismatch: expected \(expected) at \(pathString(ctx)) — \(ctx.debugDescription)")
    case .valueNotFound(let expected, let ctx):
        debugPrint("  🔎 \(type) valueNotFound: expected \(expected) at \(pathString(ctx)) — \(ctx.debugDescription)")
    case .dataCorrupted(let ctx):
        debugPrint("  🔎 \(type) dataCorrupted at \(pathString(ctx)) — \(ctx.debugDescription)")
    @unknown default:
        debugPrint("  🔎 \(type) decode error: \(de)")
    }
}


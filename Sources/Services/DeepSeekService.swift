import Foundation

// MARK: - DeepSeek API Service (OpenAI-compatible chat completions)

enum DeepSeekService {

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
        var stream: Bool? = nil
        var thinking: Thinking? = nil

        struct Message: Encodable {
            let role: String
            let content: String
        }
        struct Thinking: Encodable {
            let type: String
        }
    }

    /// DeepSeek's V4 models reason by default, which adds ~1s of "thinking"
    /// before any visible text — wasteful for mechanical cleanup. Disable it
    /// for DeepSeek endpoints only (other OpenAI-compatible providers ignore /
    /// may reject the field, so we don't send it to them).
    private static func thinkingConfig(disable: Bool, endpoint: String) -> ChatRequest.Thinking? {
        guard disable, endpoint.lowercased().contains("deepseek") else { return nil }
        return ChatRequest.Thinking(type: "disabled")
    }

    // Streaming SSE chunk: { choices: [ { delta: { content: "…" } } ] }
    struct StreamChunk: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let delta: Delta
            struct Delta: Decodable {
                let content: String?
            }
        }
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message

            struct Message: Decodable {
                let content: String
            }
        }
    }

    // MARK: - Core chat call

    static func chat(
        system: String,
        user: String,
        apiKey: String,
        model: String,
        endpoint: String,
        temperature: Double = 0,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 12,
        disableThinking: Bool = false
    ) async throws -> String {

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        let request = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: temperature,
            max_tokens: maxTokens,
            thinking: thinkingConfig(disable: disableThinking, endpoint: endpoint)
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "PunkType.DeepSeek",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "API error \(httpResponse.statusCode): \(errorBody)"]
            )
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw NSError(
                domain: "PunkType.DeepSeek",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No response content"]
            )
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Streaming variant — yields token deltas as they arrive (lower latency).
    static func streamCleanup(
        text: String,
        apiKey: String,
        model: String,
        prompt: String,
        endpoint: String,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 30,
        disableThinking: Bool = true
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

                    let body = ChatRequest(
                        model: model,
                        messages: [
                            .init(role: "system", content: prompt),
                            .init(role: "user", content: text),
                        ],
                        temperature: 0,
                        max_tokens: maxTokens,
                        stream: true,
                        thinking: thinkingConfig(disable: disableThinking, endpoint: endpoint)
                    )

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try JSONEncoder().encode(body)
                    request.timeoutInterval = timeout

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        throw NSError(
                            domain: "PunkType.DeepSeek",
                            code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "API error \(http.statusCode)"]
                        )
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                              let delta = chunk.choices.first?.delta.content,
                              !delta.isEmpty else { continue }
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Send raw transcription text for cleanup / formatting
    static func cleanup(
        text: String,
        apiKey: String,
        model: String,
        prompt: String,
        endpoint: String,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 12,
        disableThinking: Bool = true
    ) async throws -> String {
        try await chat(
            system: prompt,
            user: text,
            apiKey: apiKey,
            model: model,
            endpoint: endpoint,
            maxTokens: maxTokens,
            timeout: timeout,
            disableThinking: disableThinking
        )
    }

    /// Run a spoken command against the selected text (command mode)
    static func command(
        instruction: String,
        selectedText: String,
        apiKey: String,
        model: String,
        prompt: String,
        endpoint: String
    ) async throws -> String {
        let user = """
        【选中文字】
        \(selectedText)

        【指令】
        \(instruction)
        """
        return try await chat(
            system: prompt,
            user: user,
            apiKey: apiKey,
            model: model,
            endpoint: endpoint,
            maxTokens: 2048,
            timeout: 30
        )
    }

    // MARK: - Dictionary term extraction (async post-processing)

    private static let extractPrompt = """
    从下面的文本里提取值得收入个人词典的词条：专业术语、人名、产品名、公司名、缩写。
    要求：
    - 每行输出一个词条，不要编号、不要解释
    - 只提取文本里真实出现的词，最多 5 个
    - 常见词、普通名词不要提取
    - 如果没有值得提取的词条，只输出 NONE
    """

    /// Extract glossary-worthy terms from an output text. Returns [] when none.
    static func extractTerms(
        from text: String,
        apiKey: String,
        model: String,
        endpoint: String
    ) async throws -> [String] {
        let raw = try await chat(
            system: extractPrompt,
            user: text,
            apiKey: apiKey,
            model: model,
            endpoint: endpoint,
            maxTokens: 128,
            timeout: 20
        )
        if raw.uppercased().contains("NONE") { return [] }
        return raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 30 }
    }
}

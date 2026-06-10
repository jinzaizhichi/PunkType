import Foundation

// MARK: - DeepSeek API Service (OpenAI-compatible chat completions)

enum DeepSeekService {

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int

        struct Message: Encodable {
            let role: String
            let content: String
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
        timeout: TimeInterval = 12
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
            max_tokens: maxTokens
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

    /// Send raw transcription text for cleanup / formatting
    static func cleanup(
        text: String,
        apiKey: String,
        model: String,
        prompt: String,
        endpoint: String,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 12
    ) async throws -> String {
        try await chat(
            system: prompt,
            user: text,
            apiKey: apiKey,
            model: model,
            endpoint: endpoint,
            maxTokens: maxTokens,
            timeout: timeout
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

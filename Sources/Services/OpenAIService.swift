import Foundation

// MARK: - OpenAI Service (Whisper cloud transcription)

enum OpenAIService {

    struct TranscriptionResponse: Decodable {
        let text: String
    }

    /// Upload a WAV recording for transcription (gpt-4o-mini-transcribe / whisper-1)
    static func transcribe(
        audioURL: URL,
        apiKey: String,
        model: String = "gpt-4o-mini-transcribe",
        endpoint: String = "https://api.openai.com/v1/audio/transcriptions"
    ) async throws -> String {

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        let audioData = try Data(contentsOf: audioURL)
        let boundary = "PunkType-\(UUID().uuidString)"

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("model", model)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "PunkType.OpenAI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Transcription error \(httpResponse.statusCode): \(errorBody)"]
            )
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

//
//  TranslationService.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import Foundation

enum TranslationEngine: String, CaseIterable {
    case google = "Google"
    case bing = "Bing"
    case youdao = "有道"
    case baidu = "百度"
    case caiyun = "彩云"
    case niutrans = "小牛"
    
    var displayName: String { rawValue }
}

class TranslationService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        config.httpMaximumConnectionsPerHost = 5
        return URLSession(configuration: config)
    }()
    
    private static var cache: [String: String] = [:]
    
    private let languageCodeMap: [String: (google: String, bing: String, youdao: String, baidu: String)] = [
        "English": ("en", "en", "en", "en"),
        "中文": ("zh-CN", "zh-Hans", "zh-CHS", "zh"),
        "日本語": ("ja", "ja", "ja", "jp"),
        "한국어": ("ko", "ko", "ko", "kor"),
        "Español": ("es", "es", "es", "spa"),
        "Français": ("fr", "fr", "fr", "fra"),
        "Deutsch": ("de", "de", "de", "de")
    ]

    func translate(text: String, targetLanguage: String, engine: TranslationEngine = .google) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            throw TranslationError.emptyText
        }
        
        guard let codes = languageCodeMap[targetLanguage] else {
            throw TranslationError.invalidLanguage
        }
        
        let cacheKey = "\(trimmedText)_\(targetLanguage)_\(engine.rawValue)"
        if let cached = Self.cache[cacheKey] {
            return cached
        }
        
        let result: String
        switch engine {
        case .google:
            result = try await translateWithGoogle(trimmedText, targetCode: codes.google)
        case .bing:
            result = try await translateWithBing(trimmedText, targetCode: codes.bing)
        case .youdao:
            result = try await translateWithYoudao(trimmedText, targetCode: codes.youdao)
        case .baidu:
            result = try await translateWithBaidu(trimmedText, targetCode: codes.baidu)
        case .caiyun:
            result = try await translateWithCaiyun(trimmedText, targetCode: codes.google)
        case .niutrans:
            result = try await translateWithNiutrans(trimmedText, targetCode: codes.google)
        }
        
        Self.cache[cacheKey] = result
        return result
    }
    
    // MARK: - Google Translate
    private func translateWithGoogle(_ text: String, targetCode: String) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: targetCode),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let url = components.url else { throw TranslationError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await Self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TranslationError.networkError
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let outerArray = json.first as? [Any] else {
            throw TranslationError.translationFailed
        }
        
        var result = ""
        for item in outerArray {
            if let arr = item as? [Any], let part = arr.first as? String {
                result += part
            }
        }
        guard !result.isEmpty else { throw TranslationError.translationFailed }
        return result
    }

    // MARK: - Bing Translate
    private func translateWithBing(_ text: String, targetCode: String) async throws -> String {
        // 使用 Bing 网页版翻译
        var components = URLComponents(string: "https://api.cognitive.microsofttranslator.com/translate")!
        components.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: targetCode)
        ]
        
        guard let url = components.url else { throw TranslationError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [["Text": text]])
        
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return try await translateWithGoogle(text, targetCode: targetCode)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let translations = json.first?["translations"] as? [[String: Any]],
               let translatedText = translations.first?["text"] as? String {
                return translatedText
            }
        } catch {}
        return try await translateWithGoogle(text, targetCode: targetCode)
    }
    
    // MARK: - 有道翻译
    private func translateWithYoudao(_ text: String, targetCode: String) async throws -> String {
        var components = URLComponents(string: "https://fanyi.youdao.com/translate")!
        components.queryItems = [
            URLQueryItem(name: "doctype", value: "json"),
            URLQueryItem(name: "type", value: "AUTO2\(targetCode.uppercased())"),
            URLQueryItem(name: "i", value: text)
        ]
        
        guard let url = components.url else { throw TranslationError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return try await translateWithGoogle(text, targetCode: targetCode)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let translateResult = json["translateResult"] as? [[[String: Any]]] {
                var result = ""
                for paragraph in translateResult {
                    for sentence in paragraph {
                        if let tgt = sentence["tgt"] as? String {
                            result += tgt
                        }
                    }
                }
                if !result.isEmpty { return result }
            }
        } catch {}
        return try await translateWithGoogle(text, targetCode: targetCode)
    }

    // MARK: - 百度翻译
    private func translateWithBaidu(_ text: String, targetCode: String) async throws -> String {
        var components = URLComponents(string: "https://fanyi.baidu.com/sug")!
        
        guard let url = components.url else { throw TranslationError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "kw=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text)".data(using: .utf8)
        
        // 百度 sug 接口只适合单词，长句回退到 Google
        if text.count > 20 {
            return try await translateWithGoogle(text, targetCode: targetCode)
        }
        
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return try await translateWithGoogle(text, targetCode: targetCode)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]],
               let first = dataArray.first,
               let result = first["v"] as? String {
                return result
            }
        } catch {}
        return try await translateWithGoogle(text, targetCode: targetCode)
    }
    
    // MARK: - 彩云小译
    private func translateWithCaiyun(_ text: String, targetCode: String) async throws -> String {
        let url = URL(string: "https://api.interpreter.caiyunai.com/v1/translator")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("token 3975l6lr5pcbvidl6jl2", forHTTPHeaderField: "X-Authorization") // 公开测试 token
        
        let target = targetCode == "zh-CN" ? "zh" : targetCode
        let body: [String: Any] = [
            "source": [text],
            "trans_type": "auto2\(target)",
            "detect": true
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return try await translateWithGoogle(text, targetCode: targetCode)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let target = json["target"] as? [String],
               let result = target.first {
                return result
            }
        } catch {}
        return try await translateWithGoogle(text, targetCode: targetCode)
    }

    // MARK: - 小牛翻译
    private func translateWithNiutrans(_ text: String, targetCode: String) async throws -> String {
        var components = URLComponents(string: "https://niutrans.com/trans")!
        components.queryItems = [
            URLQueryItem(name: "from", value: "auto"),
            URLQueryItem(name: "to", value: targetCode),
            URLQueryItem(name: "src_text", value: text)
        ]
        
        guard let url = components.url else { throw TranslationError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return try await translateWithGoogle(text, targetCode: targetCode)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["tgt_text"] as? String, !result.isEmpty {
                return result
            }
        } catch {}
        return try await translateWithGoogle(text, targetCode: targetCode)
    }
}

enum TranslationError: LocalizedError {
    case emptyText
    case invalidLanguage
    case invalidURL
    case networkError
    case translationFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyText: return "请输入要翻译的文本"
        case .invalidLanguage: return "不支持的语言"
        case .invalidURL: return "无效的URL"
        case .networkError: return "网络连接失败"
        case .translationFailed: return "翻译失败"
        }
    }
}

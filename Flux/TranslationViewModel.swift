//
//  TranslationViewModel.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import Foundation
import Combine

class TranslationViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showCopySuccess = false
    @Published var targetLanguage = "English"
    
    private let translationService = TranslationService()
    private var cancellables = Set<AnyCancellable>()
    private var translateTask: Task<Void, Never>?
    
    init() {
        // 监听输入文本和目标语言变化，防抖 0.5 秒后自动翻译
        Publishers.CombineLatest($inputText, $targetLanguage)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .sink { [weak self] text, language in
                self?.autoTranslate(text: text, language: language)
            }
            .store(in: &cancellables)
    }
    
    private func autoTranslate(text: String, language: String) {
        // 取消之前的翻译任务
        translateTask?.cancel()
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            outputText = ""
            errorMessage = ""
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        translateTask = Task { @MainActor in
            do {
                let result = try await translationService.translate(
                    text: trimmed,
                    targetLanguage: language
                )
                if !Task.isCancelled {
                    self.outputText = result
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
}

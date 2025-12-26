//
//  ContentView.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @StateObject private var selectionMonitor = SelectionMonitor()
    @StateObject private var popupController = PopupWindowController()
    
    @AppStorage("targetLanguage") private var targetLanguage = "中文"
    @AppStorage("isMonitoringEnabled") private var isMonitoringEnabled = true
    
    let languages = ["English", "中文", "日本語", "한국어", "Español", "Français", "Deutsch"]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("Flux 划词翻译")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                // 状态指示
                Circle()
                    .fill(isMonitoringEnabled ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(isMonitoringEnabled ? "监听中" : "已暂停")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Divider()
            
            // 目标语言设置
            VStack(alignment: .leading, spacing: 12) {
                Text("翻译目标语言")
                    .font(.headline)
                
                Picker("Language", selection: $targetLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            
            // 开关
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $isMonitoringEnabled) {
                    HStack {
                        Image(systemName: "text.cursor")
                        Text("启用划词翻译")
                    }
                }
                .toggleStyle(.switch)
                
                Text("选中任意文字后自动翻译并在旁边显示结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Divider()
            
            // 使用说明
            VStack(alignment: .leading, spacing: 8) {
                Label("使用说明", systemImage: "info.circle")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 在任意应用中选中文字即可自动翻译")
                    Text("• 翻译结果会在选中位置旁边弹出")
                    Text("• 点击其他地方关闭翻译弹窗")
                    Text("• 需要授予辅助功能权限")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 权限提示按钮
            Button(action: openAccessibilitySettings) {
                HStack {
                    Image(systemName: "lock.shield")
                    Text("打开辅助功能设置")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(minWidth: 350, minHeight: 400)
        .onAppear {
            if isMonitoringEnabled {
                selectionMonitor.startMonitoring()
            }
        }
        .onDisappear {
            selectionMonitor.stopMonitoring()
        }
        .onChange(of: isMonitoringEnabled) { _, newValue in
            if newValue {
                selectionMonitor.startMonitoring()
            } else {
                selectionMonitor.stopMonitoring()
                popupController.hide()
            }
        }
        .onChange(of: selectionMonitor.shouldShowPopup) { _, shouldShow in
            if shouldShow && isMonitoringEnabled {
                popupController.show(
                    at: selectionMonitor.selectionPosition,
                    text: selectionMonitor.selectedText,
                    targetLanguage: targetLanguage
                )
                selectionMonitor.hidePopup()
            }
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    ContentView()
}

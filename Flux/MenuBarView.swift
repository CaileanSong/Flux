//
//  MenuBarView.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @AppStorage("targetLanguage") private var targetLanguage = "中文"
    @AppStorage("isMonitoringEnabled") private var isMonitoringEnabled = true
    @AppStorage("translationEngine") private var translationEngine = TranslationEngine.google.rawValue
    @State private var hotkeyConfig = HotkeyManager.shared.config
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    init() {
        if UserDefaults.standard.object(forKey: "isMonitoringEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "isMonitoringEnabled")
        }
    }
    
    let languages = ["English", "中文", "日本語", "한국어", "Español", "Français", "Deutsch"]
    
    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "translate")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Flux")
                    .font(.headline)
                Spacer()
                
                Circle()
                    .fill(isMonitoringEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            Divider()
            
            // 目标语言
            VStack(alignment: .leading, spacing: 6) {
                Text("翻译为")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $targetLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            // 翻译引擎
            VStack(alignment: .leading, spacing: 6) {
                Text("翻译引擎")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $translationEngine) {
                    ForEach(TranslationEngine.allCases, id: \.rawValue) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            // 快捷键设置
            VStack(alignment: .leading, spacing: 6) {
                Text("翻译快捷键")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HotkeyRecorderView(config: $hotkeyConfig)
                    .onChange(of: hotkeyConfig.keyCode) { _, _ in
                        HotkeyManager.shared.config = hotkeyConfig
                    }
            }
            
            // 开关
            Toggle(isOn: $isMonitoringEnabled) {
                Label("划词翻译", systemImage: "text.cursor")
            }
            .toggleStyle(.switch)
            .tint(.blue)
            .onChange(of: isMonitoringEnabled) { _, newValue in
                NotificationCenter.default.post(
                    name: NSNotification.Name("MonitoringChanged"),
                    object: nil,
                    userInfo: ["enabled": newValue]
                )
            }
            
            // 开机自启动
            Toggle(isOn: $launchAtLogin) {
                Label("开机启动", systemImage: "power")
            }
            .toggleStyle(.switch)
            .tint(.blue)
            .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to update launch at login: \(error)")
                }
            }
            
            Divider()
            
            // 辅助功能权限
            Button(action: openAccessibilitySettings) {
                Label("辅助功能权限", systemImage: "lock.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            // 退出
            Button(action: { NSApp.terminate(nil) }) {
                Label("退出 Flux", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .frame(width: 280)
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    MenuBarView()
}

# Flux

一款轻量级 macOS 划词翻译工具，专为阅读英文文档设计。

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 特性

- 🚀 **轻量原生** - 纯 SwiftUI 开发，内存占用 ~20MB
- ✨ **划词即译** - 选中文字自动翻译，无需额外操作
- 🎯 **专注阅读** - 翻译结果就在选中位置旁边弹出
- 🔒 **隐私友好** - 不收集任何数据，翻译请求直连翻译引擎
- 💰 **完全免费** - 无广告、无订阅、无使用限制

## 截图

<!-- 添加截图 -->

## 安装

### 手动安装

1. 下载 [最新版本](../../releases)
2. 解压后将 `Flux.app` 拖入 `/Applications` 文件夹
3. 首次打开时右键选择"打开"（绕过 Gatekeeper）
4. 在系统设置中授予辅助功能权限

### 从源码构建

```bash
git clone https://github.com/CaileanSong/Flux.git
cd Flux
open Flux.xcodeproj
```

在 Xcode 中 Build (⌘B)，然后在 Products 文件夹找到 Flux.app。

## 使用

1. 启动后 Flux 会常驻菜单栏
2. 在任意应用中选中英文文字，翻译结果自动弹出
3. 点击菜单栏图标可设置目标语言、翻译引擎、快捷键等
4. 对于 VS Code 等 Electron 应用，使用快捷键 `⌘⇧T` 触发翻译

## 支持的翻译引擎

- Google 翻译（默认）
- Bing 翻译
- 有道翻译
- 百度翻译
- 彩云小译
- 小牛翻译

所有引擎均为免费接口，无需 API Key。

## 系统要求

- macOS 14.0+
- 需要辅助功能权限

## 许可证

MIT License

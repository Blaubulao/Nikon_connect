# Nikon Connect iOS

一个面向尼康（Nikon）相机（如 Z5）第一阶段 MVP 的 **iOS 原生应用**，用于在手动连接相机 Wi-Fi 热点后，进行快速的照片浏览与下载。本项目通过 Swift 原生实现标准 PTP/IP 协议及双通道 TCP 通信，提供比官方 SnapBridge 更轻量、稳定的照片下载体验。

---

## 🌟 主要功能

*   **双通道 PTP/IP 握手**: Swift 原生实现的命令通道（Command）与事件通道（Event）握手，保持与相机的稳定长连接。
*   **会话层自动化控制**: 支持获取设备信息、读取存储介质、分批分页遍历相机对象（照片/视频）句柄并拉取元数据。
*   **异步缩略图加载与缓存**: 内置高性能缩略图服务，实现流畅的网格浏览。
*   **沙盒下载与系统相册同步**: 支持安全保存至 iOS 沙盒目录，并可配置自动或手动导出至 iOS 系统相册（Photos Library）。
*   **Nikon 专属 UI 主题**: 融入尼康经典黑黄配色、微光动效状态角标、玻璃模糊分栏器，以及开发者专属的高对比度终端日志（Terminal Log）查看器。
*   **多种传输模式**:
    *   **演示模式 (Demo)**: 使用本地内置样例数据进行跑通与展示。
    *   **尼康实验模式 (Experimental)**: 使用相机默认 Wi-Fi 热点 IP `192.168.1.1:15740` 进行真实物理连接。

---

## 📂 项目结构

```text
├── App/                       # App 入口、模型及全局 Tab
├── Domain/                    # 业务领域实体模型与错误定义
├── Features/                  # SwiftUI 业务界面
│   ├── ConnectionSetup/       # 相机连接与状态控制
│   ├── PhotoBrowser/          # 相册网格浏览与大图查看器
│   ├── Downloads/             # 本地已下载及相册导出历史
│   └── Settings/              # 偏好设置及全局日志
├── Infrastructure/            # 系统底层封装
├── Services/                  # PTP/IP 编解码、TCP套接字及存储核心服务
├── Resources/                 # 资源资产及 Info.plist
├── Tests/                     # 单元测试模块
├── scripts/                   # 辅助脚本
└── project.yml                # XcodeGen 项目描述配置文件
```

---

## 🛠️ 构建与运行

### 环境要求
*   **macOS** (支持 Apple Silicon 架构)
*   **Xcode 16.0+**
*   **XcodeGen** (用于生成 `.xcodeproj` 描述文件，版本建议 `2.45.0+`)

### 1. 生成项目工程
在主工程根目录执行以下命令生成 `.xcodeproj` 文件：
```bash
./scripts/generate_project.sh
```

### 2. 运行与验证
*   **打开项目**:
    ```bash
    open NikonConnectIOS.xcodeproj
    ```
*   **本地类型检查**:
    ```bash
    ./scripts/typecheck_macos.sh
    ```
*   **运行测试**:
    ```bash
    # 可在 Xcode 界面上直接运行 Test，或通过命令行测试
    DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
      xcodebuild -project NikonConnectIOS.xcodeproj \
      -scheme NikonConnectIOS \
      -destination 'platform=iOS Simulator,name=iPhone 16' \
      test
    ```

---

## 📡 物理连接与测试步骤

1.  **连接 Wi-Fi**:
    *   在尼康相机上开启 Wi-Fi 功能（手动开启 Wi-Fi 连接）。
    *   在 iPhone 的 **系统设置 > Wi-Fi** 中找到相机热点并建立连接。
2.  **启动连接**:
    *   打开 **Nikon Connect** App。
    *   在“相机”页面将模式选择为 **尼康实验模式**。
    *   点击 **连接相机** 按钮，等待双通道握手完成（状态转为绿色的“已连接”）。
3.  **浏览与下载**:
    *   切换到“照片”页面，App 会自动发起句柄遍历。
    *   点击照片查看大图，你可以多选照片并点击底部的 **开始下载** 保存至 App 存储或同步至系统相册。

---

## 🛠️ 辅助脚本说明

*   `generate_project.sh`: 快速生成 Xcode 描述工程文件，避免团队开发中频繁产生 pbxproj 冲突。
*   `typecheck_macos.sh`: 本地利用 macOS SDK 对 Swift 文件进行类型检查与并发状态自检。
*   `monitor_nikon_camera_wifi.sh`: 用于被动监听本机 Wi-Fi 网口，可检查相机网络状态及路由状态，带 `--ping` 可测试至 `192.168.1.1` 的响应延迟。

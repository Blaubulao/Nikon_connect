import Foundation

enum CameraTransportMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case demo
    case experimentalNikon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demo:
            return "演示模式"
        case .experimentalNikon:
            return "尼康实验模式"
        }
    }

    var detail: String {
        switch self {
        case .demo:
            return "用内置样例数据跑通连接、列表和下载流程。"
        case .experimentalNikon:
            return "使用尼康相机Wi‑Fi地址192.168.1.1:15740连接相机。"
        }
    }

    var defaultHost: String? {
        switch self {
        case .demo:
            return nil
        case .experimentalNikon:
            return "192.168.1.1"
        }
    }

    // Based on the CIPA PTP/IP specification default TCP port.
    var defaultPort: Int { 15740 }
}

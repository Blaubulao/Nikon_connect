import Foundation

struct CameraTransportFactory {
    func makeTransport(for mode: CameraTransportMode) -> any CameraTransport {
        switch mode {
        case .demo:
            return MockNikonTransport()
        case .experimentalNikon:
            return ExperimentalNikonTransport()
        }
    }
}

protocol CameraTransportFactoryProtocol {
    func makeTransport(for mode: CameraTransportMode) -> any CameraTransport
}

extension CameraTransportFactory: CameraTransportFactoryProtocol {}

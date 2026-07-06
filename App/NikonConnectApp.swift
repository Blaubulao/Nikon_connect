import SwiftUI

@main
struct NikonConnectApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView(model: model)
                .task {
                    await model.bootstrapIfNeeded()
                }
        }
    }
}

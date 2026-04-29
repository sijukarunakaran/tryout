import Foundation
import Splice

@DependencyClient
struct OrderClient: Sendable {
    var placeOrder: @Sendable () async throws -> String

    init(
        placeOrder: @escaping @Sendable () async throws -> String
    ) {
        self.placeOrder = placeOrder
    }
}

extension OrderClient {
    @DependencySource
    private static let live = OrderClient {
        try await Task.sleep(for: .milliseconds(800))
        return String(UUID().uuidString.prefix(8)).uppercased()
    }
}

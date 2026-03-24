//
//  Shared.swift
//  Core
//
//  Created by Siju Karunakaran(UST,IN) on 14/05/25.
//

// Shared.swift

import Foundation

/// A simple shared-value wrapper.
/// `Value` must be `Sendable`.
@propertyWrapper
public final class Shared<Value: Sendable>: @unchecked Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public convenience init(shared: Shared<Value>) {
        self.init(wrappedValue: shared.wrappedValue)
    }

    public var projectedValue: Shared<Value> { self }
}

extension Shared: Equatable where Value: Equatable {
    public static func == (
        lhs: Shared<Value>,
        rhs: Shared<Value>
    ) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

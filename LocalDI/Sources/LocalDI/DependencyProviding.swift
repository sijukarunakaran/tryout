//
//  DependencyProviding.swift
//  LocalDI
//
//  Created by Siju Karunakaran(UST,IN) on 28/04/26.
//


public protocol DependencyProviding: Sendable {
    associatedtype Dependency: DependencyKey where Dependency.Value == Self
}

public extension DependencyProviding {
    /// Bridge called by the macro-generated key's `testValue`.
    /// Override by applying `@DependencyTestSource` to a `static let testLive` in an extension.
    static var __dependencyTestSource: Self? { nil }
}

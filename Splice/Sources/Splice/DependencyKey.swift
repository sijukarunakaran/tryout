//
//  DependencyKey.swift
//  LocalDI
//
//  Created by Siju Karunakaran(UST,IN) on 28/04/26.
//


public protocol DependencyKey {
    associatedtype Value: Sendable
    static var liveValue: Value { get }
    static var testValue: Value? { get }
}

public extension DependencyKey {
    static var testValue: Value? { nil }
}
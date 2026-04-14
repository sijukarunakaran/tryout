public protocol FeatureDomain {
    associatedtype State: Sendable & Equatable
    associatedtype Action: Sendable

    static var reducer: Reducer<State, Action> { get }
}

import Foundation

public struct CasePath<Root, Value>: Sendable {
    public let extract: @Sendable (Root) -> Value?
    public let embed: @Sendable (Value) -> Root

    public init(
        extract: @Sendable @escaping (Root) -> Value?,
        embed: @Sendable @escaping (Value) -> Root
    ) {
        self.extract = extract
        self.embed = embed
    }
}

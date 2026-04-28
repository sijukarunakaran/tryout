//
//  Effect.swift
//  Core
//
//  Created by Siju Karunakaran(UST,IN) on 14/05/25.
//

// Effect.swift

import Foundation

/// A side-effect that can emit actions back into the store.
///
/// - `Action` must be `Sendable`
/// - `Failure` must be `Error & Sendable`
public struct Effect<Action: Sendable>: Sendable {
    /// Runs the effect and returns all `Task`s it spawned.
    /// Callers (e.g. `Store`) collect and cancel these tasks when appropriate.
    public let run: @Sendable (
        @escaping @Sendable (Action) -> Void
    ) -> [Task<Void, Never>]

    public let isEmpty: Bool

    public init(
        run: @Sendable @escaping (@escaping @Sendable (Action) -> Void) -> [Task<Void, Never>]
    ) {
        self.init(run: run, isEmpty: false)
    }

    fileprivate init(
        run: @Sendable @escaping (@escaping @Sendable (Action) -> Void) -> [Task<Void, Never>],
        isEmpty: Bool
    ) {
        self.run = run
        self.isEmpty = isEmpty
    }

    /// Fire off an async task as an effect.
    public static func task(
        _ block: @Sendable @escaping () async -> Action
    ) -> Effect {
        Effect { callback in
            [Task {
                let result = await block()
                await MainActor.run { callback(result) }
            }]
        }
    }

    public static func task(
        _ block: @Sendable @escaping () async -> Action?
    ) -> Effect {
        Effect { callback in
            [Task {
                let result = await block()
                await MainActor.run { if let result { callback(result) } }
            }]
        }
    }

    public static func fireAndForget(
        _ block: @Sendable @escaping () async -> Void
    ) -> Effect {
        Effect { _ in
            [Task { await block() }]
        }
    }

    public static func task(
        _ block: @Sendable @escaping () async -> [Action]
    ) -> Effect {
        Effect { callback in
            [Task {
                let results = await block()
                await MainActor.run { results.forEach { callback($0) } }
            }]
        }
    }

    /// No effect.
    public static var none: Effect { .init(run: { _ in [] }, isEmpty: true) }

    /// Map the output action.
    public func map<B: Sendable>(
        _ transform: @Sendable @escaping (Action) -> B
    ) -> Effect<B> {
        .init { callback in
            self.run { result in callback(transform(result)) }
        }
    }

    /// Merge multiple effects.
    public static func merge(
        _ effects: Effect...
    ) -> Effect {
        .init { callback in effects.flatMap { $0.run(callback) } }
    }

    /// Merge multiple effects.
    public static func merge(
        _ effects: [Effect]
    ) -> Effect {
        .init { callback in effects.flatMap { $0.run(callback) } }
    }
}

extension Effect: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) { self = .none }
}

private actor _EffectTasks {
    static let shared = _EffectTasks()
    private var tasks: [AnyHashable: Task<Void, Never>] = [:]

    func start<Action: Sendable>(
        id: some Hashable & Sendable,
        cancelInFlight: Bool,
        operation: @Sendable @escaping () async -> Action?,
        callback: @escaping @Sendable (Action) -> Void
    ) {
        let key = AnyHashable(id)
        if cancelInFlight, let t = tasks[key] { t.cancel() }
        self.tasks[key] = Task {
            let result = await operation()
            guard !Task.isCancelled, let action = result else {
                self.tasks.removeValue(forKey: key)
                return
            }
            await MainActor.run { callback(action) }
            self.tasks.removeValue(forKey: key)
        }
    }

    func startLongRun<Action: Sendable>(
        id: some Hashable & Sendable,
        cancelInFlight: Bool,
        operation: @Sendable @escaping (_ send: @escaping @Sendable (Action) -> Void) async -> Void,
        callback: @escaping @Sendable (Action) -> Void
    ) {
        let key = AnyHashable(id)
        if cancelInFlight, let t = tasks[key] { t.cancel() }

        self.tasks[key] = Task {
            await operation { action in
                guard !Task.isCancelled else { return }
                Task { @MainActor in callback(action) }
            }
            self.tasks.removeValue(forKey: key)
        }
    }

    func cancel(id: some Hashable & Sendable) {
        let key = AnyHashable(id)
        self.tasks[key]?.cancel()
    }
}

extension Effect {
    public static func cancellableTask(
        id: some Hashable & Sendable,
        cancelInFlight: Bool = false,
        _ block: @Sendable @escaping () async -> Action?
    ) -> Effect {
        Effect { callback in
            [Task {
                await _EffectTasks.shared.start(
                    id: id,
                    cancelInFlight: cancelInFlight,
                    operation: block,
                    callback: callback
                )
            }]
        }
    }

    public static func cancel(id: some Hashable & Sendable) -> Effect {
        Effect { _ in
            [Task { await _EffectTasks.shared.cancel(id: id) }]
        }
    }
}

extension Effect {
    /// A cancellable long-running effect that can emit multiple actions via `send`.
    public static func longRunning(
        id: some Hashable & Sendable,
        cancelInFlight: Bool = false,
        operation: @Sendable @escaping (_ send: @escaping @Sendable (Action) -> Void) async -> Void
    ) -> Effect {
        Effect { callback in
            [Task {
                await _EffectTasks.shared.startLongRun(
                    id: id,
                    cancelInFlight: cancelInFlight,
                    operation: operation,
                    callback: callback
                )
            }]
        }
    }
}

import Foundation
import SwiftUI
import Combine

/// Store of `Actomaton` optimized for SwiftUI's 2-way binding.
@MainActor
open class Store<Action, State>: ObservableObject
{
    private let actomaton: Actomaton<BindableAction, State>

    /// Actor that manages animation-transaction to be safely run after state is mutated asynchronously.
    private let transactor: Transactor

    @Published
    public private(set) var state: State

//    private var transaction: Transaction?

    private var cancellables: [AnyCancellable] = []

    /// Initializer without `environment`.
    public convenience init(
        state initialState: State,
        reducer: Reducer<Action, State, ()>
    )
    {
        self.init(state: initialState, reducer: reducer, environment: ())
    }

    /// Initializer with `environment`.
    public init<Environment>(
        state initialState: State,
        reducer: Reducer<Action, State, Environment>,
        environment: Environment
    )
    {
        self.state = initialState

        self.actomaton = Actomaton(
            state: initialState,
            reducer: lift(reducer: Reducer { action, state, environment in
                reducer.run(action, &state, environment)
            }),
            environment: environment
        )

        let transactor = Transactor()
        self.transactor = transactor

        Task {
            let statePublisher = await self.actomaton.$state

            statePublisher
                .flatMap { state in
                    Future { promise in
                        Task(priority: .high) {
                            let transaction = await transactor.transaction
                            promise(.success((state, transaction)))
                        }
                    }
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state, transaction in
                    withTransaction(transaction ?? Transaction()) { [weak self] in
                        self?.state = state
                    }
                }
                .store(in: &self.cancellables)
        }
    }

    /// Lightweight `Store` proxy without duplicating internal state.
    public var proxy: Proxy
    {
        Proxy(state: self.stateBinding, send: self.send)
    }

}

// MARK: - Private

// NOTE:
// These are marked as `private` since passing `Store.Proxy` instead of `Store`
// to SwiftUI's `View`s is preferred.
// To call these methods, use `proxy` instead.
extension Store
{
    private nonisolated func send(_ action: Action, transaction: Transaction? = nil, priority: TaskPriority? = nil, tracksFeedbacks: Bool) -> Task<(), Never>
    {
        Task(priority: priority) { [weak self] in
            await self?.transactor.runTransaction(transaction) {
                await self?.actomaton.send(.action(action), priority: priority, tracksFeedbacks: tracksFeedbacks)
            }
        }
    }

    private var stateBinding: Binding<State>
    {
        return Binding<State>(
            get: {
                self.state
            },
            set: { newValue, transaction in
                Task { [weak self] in
                    await self?.transactor.runTransaction(transaction) {
                        await self?.actomaton.send(.state(newValue))
                    }
                }
            }
        )
    }
}

extension Store {
    /// `action` as indirect messaging, or `state` that can directly replace `actomaton.state` via SwiftUI 2-way binding.
    fileprivate enum BindableAction
    {
        case action(Action)
        case state(State)
    }
}

/// Lifts from `Reducer`'s `Action` to `Store.BindableAction`.
private func lift<Action, State, Environment>(
    reducer: Reducer<Action, State, Environment>
) -> Reducer<Store<Action, State>.BindableAction, State, Environment>
{
    .init { action, state, environment in
        switch action {
        case let .action(innerAction):
            let effect = reducer.run(innerAction, &state, environment)
            return effect.map(Store<Action, State>.BindableAction.action)

        case let .state(newState):
            state = newState
            return .empty
        }
    }
}

/// Actor that manages animation-transaction to be safely run after state is mutated asynchronously.
private actor Transactor
{
    var transaction: Transaction?

    func runTransaction(_ transaction: Transaction?, handle: () async -> Void) async
    {
        self.transaction = transaction
        await handle()
        self.transaction = nil
    }
}

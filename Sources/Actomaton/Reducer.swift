/// A composable, `State`-transforming function wrapper that is triggered by `Action`.
public struct Reducer<Action, State, Environment>
{
    public let run: (Action, inout State, Environment) -> Effect<Action>

    public init(_ run: @escaping (Action, inout State, Environment) -> Effect<Action>)
    {
        self.run = run
    }

    // MARK: - Monoid

    public static var empty: Reducer
    {
        .init { _, _, _ in .empty }
    }

    public static func + (l: Reducer, r: Reducer) -> Reducer
    {
        .init { action, state, environment in
            l.run(action, &state, environment) + r.run(action, &state, environment)
        }
    }

    public static func combine(_ reducers: [Reducer]) -> Reducer
    {
        reducers.reduce(into: .empty, { $0 = $0 + $1 })
    }

    public static func combine(_ reducers: Reducer...) -> Reducer
    {
        self.combine(reducers)
    }

    // MARK: - Contravariant Functor

    /// Transforms `Action` using `CasePath`.
    public func contramap<GlobalAction>(
        action toLocalAction: CasePath<GlobalAction, Action>
    ) -> Reducer<GlobalAction, State, Environment>
    {
        .init { action, state, environment in
            guard let localAction = toLocalAction.extract(from: action) else { return .empty }

            return self
                .run(
                    localAction,
                    &state,
                    environment
                )
                .map(toLocalAction.embed)
        }
    }

    /// Transforms `State` using `WritableKeyPath`.
    public func contramap<GlobalState>(
        state toLocalState: WritableKeyPath<GlobalState, State>
    ) -> Reducer<Action, GlobalState, Environment>
    {
        .init { action, state, environment in
            self.run(
                action,
                &state[keyPath: toLocalState],
                environment
            )
        }
    }

    /// Transforms `State` using `CasePath`.
    public func contramap<GlobalState>(
        state toLocalState: CasePath<GlobalState, State>
    ) -> Reducer<Action, GlobalState, Environment>
    {
        .init { action, state, environment in
            guard var localState = toLocalState.extract(from: state) else { return .empty }

            let effect = self.run(
                action,
                &localState,
                environment
            )
            state = toLocalState.embed(localState)
            return effect
        }
    }

    /// Transforms `Environment`.
    public func contramap<GlobalEnvironment>(
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<Action, State, GlobalEnvironment>
    {
        .init { action, state, environment in
            self.run(
                action,
                &state,
                toLocalEnvironment(environment)
            )
        }
    }
}

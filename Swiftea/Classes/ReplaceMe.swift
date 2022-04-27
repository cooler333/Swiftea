import Foundation
import Combine

public enum Next<State, Command> {
    case empty
    case next(State)
    case dispatch([Command])
    case nextAndDispatch(State, [Command])
}

public final class Updater<State, Event, Command> {
    private let update: (State, Event) -> Next<State, Command>

    public init(
        update: @escaping (State, Event) -> Next<State, Command>
    ) {
        self.update = update
    }

    public func dispatch(
        state: State,
        event: Event
    ) -> Next<State, Command> {
        update(state, event)
    }
}

public final class Store<UIState, State, UIEvent, Event, Command> {

    public let updatePublisher = PassthroughSubject<UIState, Never>()

    private var state: State

    private let updater: Updater<State, Event, Command>
    private let uiEventMapper: (UIEvent) -> Event
    private let stateMapper: (State) -> UIState
    private let commandHandler: (Command) -> AnyPublisher<Event, Never>

    private var store: Set<AnyCancellable> = []
    private var eventQueue = DispatchQueue(label: "eventQueue", qos: .userInteractive)

    public init(
        state: State,
        updater: Updater<State, Event, Command>,
        uiEventMapper: @escaping (UIEvent) -> Event,
        stateMapper: @escaping (State) -> UIState,
        commandHandler: @escaping (Command) -> AnyPublisher<Event, Never>
    ) {
        self.state = state
        self.updater = updater
        self.uiEventMapper = uiEventMapper
        self.stateMapper = stateMapper
        self.commandHandler = commandHandler
    }

    public func dispatch(uiEvent: UIEvent) {
        let event = uiEventMapper(uiEvent)
        let next = updater.dispatch(state: state, event: event)
        eventQueue.async {
            self.checkNext(next)
        }
    }


    // MARK: Private

    private func checkNext(_ next: Next<State, Command>) {
        switch next {
        case .empty:
            break

        case let .next(state):
            dispatchNext(state: state)

        case let .dispatch(commands):
            dispatchCommands(commands: commands)

        case let .nextAndDispatch(state, commands):
            dispatchNext(state: state)
            dispatchCommands(commands: commands)
        }
    }

    private func dispatchNext(state: State) {
        self.state = state
        let uiState = stateMapper(state)

        if Thread.isMainThread {
            updatePublisher.send(uiState)
        } else {
            DispatchQueue.main.async {
                self.updatePublisher.send(uiState)
            }
        }
    }

    private func dispatchCommands(commands: [Command]) {
        commands.forEach { command in
            commandHandler(command).sink(
                receiveValue: { event in
                    let next = self.updater.dispatch(state: self.state, event: event)
                    self.eventQueue.async {
                        self.checkNext(next)
                    }
                }
            ).store(in: &store)
        }
    }
}

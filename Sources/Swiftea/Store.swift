//
//  Store.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public final class Store<State, Event, Command: Equatable, Environment> {
    public let statePublisher = PassthroughSubject<State, Never>()

    private let internalStatePublisher: CurrentValueSubject<State, Never>
    private let internalEventPublisher = PassthroughSubject<Event, Never>()
    private let internalCommandPublisher = PassthroughSubject<(Command, [Command]), Never>()

    private var store: Set<AnyCancellable> = []
    private let eventDispatchQueue = DispatchQueue(label: "eventQueue", qos: .userInteractive)
    private var eventQueue: [Event] = []
    private var isProcessing = false

    public init(
        state: State,
        reducer: Reducer<State, Event, Command>,
        commandHandler: CommandHandler<Command, Event, Environment>
    ) {
        internalStatePublisher = CurrentValueSubject<State, Never>(state)

        internalStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { state in
                self.statePublisher.send(state)
            }
            .store(in: &store)

        internalEventPublisher
            .map { event -> Next<State, Command> in
                reducer.dispatch(state: self.internalStatePublisher.value, event: event)
            }
            .sink { next in
                switch next {
                case .empty:
                    break

                case let .next(state):
                    self.internalStatePublisher.send(state)

                case let .dispatch(commands):
                    commands.forEach { command in
                        self.internalCommandPublisher.send((command, []))
                    }

                case let .nextAndDispatch(state, commands):
                    self.internalStatePublisher.send(state)
                    commands.forEach { command in
                        self.internalCommandPublisher.send((command, []))
                    }

                case let .dispatchCancellable(commands, cancellablecommands):
                    commands.forEach { command in
                        self.internalCommandPublisher.send((command, cancellablecommands))
                    }

                case let .nextAndDispatchCancellable(state, commands, cancellablecommands):
                    self.internalStatePublisher.send(state)
                    commands.forEach { command in
                        self.internalCommandPublisher.send((command, cancellablecommands))
                    }
                }
            }
            .store(in: &store)

        internalCommandPublisher
            .compactMap { (command, cancellablecommands) -> AnyPublisher<Event, Never> in
                commandHandler.dispatch(
                    command: command,
                    cancellableCommands: cancellablecommands,
                    commandPublisher: self.internalCommandPublisher.map { $0.0 }.eraseToAnyPublisher()
                )
            }
            .flatMap { $0 }
            .sink { event in
                self.internalEventPublisher.send(event)
            }
            .store(in: &store)
    }

    public func dispatch(event: Event) {
        internalEventPublisher.send(event)
    }
}

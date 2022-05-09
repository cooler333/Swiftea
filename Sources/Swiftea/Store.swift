//
//  Store.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public final class Store<State: Equatable, Event, Command: Equatable, Environment> {
    public let statePublisher = PassthroughSubject<State, Never>()

    private let internalStatePublisher: CurrentValueSubject<State, Never>
    private let internalEventPublisher = PassthroughSubject<Event, Never>()
    private let internalCommandPublisher = PassthroughSubject<(Command, [Command]), Never>()

    private var store: Set<AnyCancellable> = []

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

                case let .dispatchCancellable(commands, cancellableCommands):
                    commands.forEach { command in
                        self.internalCommandPublisher.send((command, cancellableCommands))
                    }

                case let .nextAndDispatchCancellable(state, commands, cancellableCommands):
                    self.internalStatePublisher.send(state)
                    commands.forEach { command in
                        self.internalCommandPublisher.send((command, cancellableCommands))
                    }
                }
            }
            .store(in: &store)

        internalCommandPublisher
            .compactMap { command, cancellableCommands -> AnyPublisher<Event, Never> in
                commandHandler.dispatch(
                    command: command,
                    cancellableCommands: cancellableCommands,
                    unhandledCommandsPublisher: self.internalCommandPublisher
                        .map { $0.0 }
                        .eraseToAnyPublisher()
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

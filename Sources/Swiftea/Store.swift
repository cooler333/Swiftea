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
    private let internalCommandPublisher: PassthroughSubject<(command: Command, cancellableCommands: [Command]), Never>
    private let internalEventPublisher: PassthroughSubject<Event, Never>

    private let internalQueue = DispatchQueue(label: "internalQueue")

    private var cancellable: Set<AnyCancellable> = []
    private var cancellableStorage: [(cancellable: AnyCancellable, cancellableCommands: [Command])] = []

    public init(
        state: State,
        reducer: Reducer<State, Event, Command>,
        commandHandler: CommandHandler<Command, Event, Environment>
    ) {
        if !Thread.isMainThread {
            assertionFailure("Not main thread")
        }

        internalStatePublisher = CurrentValueSubject<State, Never>(state)
        internalCommandPublisher = PassthroughSubject<(command: Command, cancellableCommands: [Command]), Never>()
        internalEventPublisher = PassthroughSubject<Event, Never>()

        internalStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.statePublisher.send(state)
            }
            .store(in: &cancellable)

        internalCommandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] commandAndCancellableCommands in
                guard let self = self else { return }
                self.handle(
                    command: commandAndCancellableCommands.command,
                    cancellableCommands: commandAndCancellableCommands.cancellableCommands,
                    commandHandler: commandHandler
                )
            }.store(in: &cancellable)

        internalEventPublisher
            .receive(on: DispatchQueue.main)
            .map { [unowned self] event -> Next<State, Command> in
                let state = self.internalStatePublisher.value
                return reducer.dispatch(state: state, event: event)
            }.sink { [weak self] next in
                guard let self = self else { return }
                self.handle(next: next)
            }.store(in: &cancellable)
    }

    public func dispatch(event: Event) {
        if !Thread.isMainThread {
            assertionFailure("Not main thread")
        }

        internalEventPublisher.send(event)
    }

    private func handle(
        command: Command,
        cancellableCommands: [Command],
        commandHandler: CommandHandler<Command, Event, Environment>
    ) {
        if !Thread.isMainThread {
            assertionFailure("Not main thread")
        }

        internalQueue.sync { [weak self] in
            guard let self = self else { return }
            cancellableStorage
                .filter { _, cancellableCommands in
                    cancellableCommands.contains(command)
                }
                .map { $0.cancellable }
                .forEach { $0.cancel() }

            let cancellable = commandHandler.dispatch(command: command)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    guard let self = self else { return }
                    self.dispatch(event: event)
                }
            cancellable.store(in: &self.cancellable)

            cancellableStorage.append((cancellable, cancellableCommands))
        }
    }

    private func handle(next: Next<State, Command>) {
        if !Thread.isMainThread {
            assertionFailure("Not main thread")
        }

        switch next {
        case .empty:
            break

        case let .next(state):
            internalStatePublisher.send(state)

        case let .dispatch(commands):
            commands.forEach { command in
                internalQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.internalCommandPublisher.send((command, []))
                }
            }

        case let .nextAndDispatch(state, commands):
            internalStatePublisher.send(state)
            commands.forEach { command in
                internalQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.internalCommandPublisher.send((command, []))
                }
            }

        case let .dispatchCancellable(commands, cancellableCommands):
            commands.forEach { command in
                internalQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.internalCommandPublisher.send((command, cancellableCommands))
                }
            }

        case let .nextAndDispatchCancellable(state, commands, cancellableCommands):
            internalStatePublisher.send(state)
            commands.forEach { command in
                internalQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.internalCommandPublisher.send((command, cancellableCommands))
                }
            }
        }
    }
}

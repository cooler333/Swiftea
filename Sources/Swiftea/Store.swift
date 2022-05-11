//
//  Store.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public final class Store<State: Equatable, Event, Command: Equatable & Hashable, Environment> {
    public let statePublisher = PassthroughSubject<State, Never>()

    private let internalStatePublisher: CurrentValueSubject<State, Never>
    private var commandQueue: [(command: Command, cancellableCommands: [Command])] = []

    private let internalQueue = DispatchQueue(label: "internalQueue")

    private let reducer: Reducer<State, Event, Command>
    private let commandHandler: CommandHandler<Command, Event, Environment>

    private var store: Set<AnyCancellable> = []
    private var cancellableStorage: [Command: [AnyCancellable]] = [:]

    public init(
        state: State,
        reducer: Reducer<State, Event, Command>,
        commandHandler: CommandHandler<Command, Event, Environment>
    ) {
        self.reducer = reducer
        self.commandHandler = commandHandler

        internalStatePublisher = CurrentValueSubject<State, Never>(state)

        internalStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.statePublisher.send(state)
            }
            .store(in: &store)
    }

    public func dispatch(event: Event) {
        if !Thread.isMainThread {
            assertionFailure("Not main thread")
        }

        let state = internalStatePublisher.value
        let next = reducer.dispatch(state: state, event: event)
        handle(next: next)
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
                internalQueue.async {
                    self.commandQueue.append((command, []))
                }
            }

        case let .nextAndDispatch(state, commands):
            internalStatePublisher.send(state)
            commands.forEach { command in
                internalQueue.async {
                    self.commandQueue.append((command, []))
                }
            }

        case let .dispatchCancellable(commands, cancellableCommands):
            commands.forEach { command in
                internalQueue.async {
                    self.commandQueue.append((command, cancellableCommands))
                }
            }

        case let .nextAndDispatchCancellable(state, commands, cancellableCommands):
            internalStatePublisher.send(state)
            commands.forEach { command in
                internalQueue.async {
                    self.commandQueue.append((command, cancellableCommands))
                }
            }
        }

        handleCommands()
    }

    private func handleCommands() {
        if !Thread.isMainThread {
            assertionFailure("Not main thread")
        }

        internalQueue.sync {
            if let commandItem = self.commandQueue.first {
                self.commandQueue.remove(at: 0)

                if let cancellables = self.cancellableStorage[commandItem.command] {
                    for cancellable in cancellables {
                        cancellable.cancel()
                    }
                }
                self.cancellableStorage[commandItem.command] = nil

                let cancellable = self.commandHandler.dispatch(command: commandItem.command)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] event in
                        guard let self = self else { return }
                        self.dispatch(event: event)
                    }
                cancellable.store(in: &self.store)

                for cancellableCommand in commandItem.cancellableCommands {
                    if commandItem.command == cancellableCommand { continue }
                    if self.cancellableStorage[cancellableCommand] != nil {
                        self.cancellableStorage[cancellableCommand]!.append(cancellable)
                    } else {
                        self.cancellableStorage[cancellableCommand] = [cancellable]
                    }
                }

                DispatchQueue.main.async {
                    self.handleCommands()
                }
            }
        }
    }
}

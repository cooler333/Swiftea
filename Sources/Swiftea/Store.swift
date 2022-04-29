//
//  Store.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Foundation
import Combine

public final class Store<State, Event, Command, Environment> {
    public let statePublisher = PassthroughSubject<State, Never>()

    private var state: State

    private let reducer: Reducer<State, Event, Command>
    private let commandHandler: CommandHandler<State, Command, Event, Environment>

    private var store: Set<AnyCancellable> = []
    private var eventQueue = DispatchQueue(label: "eventQueue", qos: .userInteractive)

    public init(
        state: State,
        reducer: Reducer<State, Event, Command>,
        commandHandler: CommandHandler<State, Command, Event, Environment>
    ) {
        self.state = state
        self.reducer = reducer
        self.commandHandler = commandHandler
    }

    public func dispatch(event: Event) {
        let next = reducer.dispatch(state: state, event: event)
        dispatch(next)
    }


    // MARK: Private

    private func dispatch(_ next: Next<State, Command>) {
        eventQueue.async { [weak self] in
            guard let self = self else { return }

            switch next {
            case .empty:
                break

            case let .next(state):
                self.dispatchNext(state: state)

            case let .dispatch(commands):
                self.dispatchCommands(commands: commands)

            case let .nextAndDispatch(state, commands):
                self.dispatchNext(state: state)
                self.dispatchCommands(commands: commands)
            }
        }
    }

    private func dispatchNext(state: State) {
        self.state = state

        if Thread.isMainThread {
            statePublisher.send(state)
        } else {
            DispatchQueue.main.async {
                self.statePublisher.send(state)
            }
        }
    }

    private func dispatchCommands(commands: [Command]) {
        commands.forEach { command in
            commandHandler.dispatch(
                command: command,
                state: state
            )
            .sink(
                receiveValue: { event in
                    let next = self.reducer.dispatch(state: self.state, event: event)
                    self.eventQueue.async {
                        self.dispatch(next)
                    }
                }
            )
            .store(in: &store)
        }
    }
}

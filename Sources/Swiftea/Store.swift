//
//  Store.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public final class Store<State, Event, Command, Environment> {
    public let statePublisher = PassthroughSubject<State, Never>()

    private var state: State

    private let reducer: Reducer<State, Event, Command>
    private let commandHandler: CommandHandler<State, Command, Event, Environment>

    private var store: Set<AnyCancellable> = []
    private let eventDispatchQueue = DispatchQueue(label: "eventQueue", qos: .userInteractive)
    private var eventQueue: [Event] = []
    private var isProcessing = false

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
        eventDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isProcessing {
                self.eventQueue.append(event)
            } else {
                self.isProcessing = true
                let next = self.reducer.dispatch(state: self.state, event: event)
                self.dispatch(next)
                self.isProcessing = false
                if let event = self.eventQueue.first {
                    self.eventQueue.removeFirst()
                    self.dispatch(event: event)
                }
            }
        }
    }

    // MARK: Private

    private func dispatch(_ next: Next<State, Command>) {
        switch next {
        case .empty:
            break

        case let .next(state):
            dispatchNext(state: state)

        case let .dispatch(commands):
            dispatchCommands(state: state, commands: commands)

        case let .nextAndDispatch(state, commands):
            dispatchNext(state: state)
            dispatchCommands(state: state, commands: commands)
        }
    }

    private func dispatchNext(state: State) {
        self.state = state

        if Thread.isMainThread {
            statePublisher.send(state)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.statePublisher.send(state)
            }
        }
    }

    private func dispatchCommands(state: State, commands: [Command]) {
        commands.forEach { command in
            let eventStream = commandHandler.dispatch(
                command: command,
                state: state
            )

            if let eventStream = eventStream {
                eventStream.sink(receiveValue: { [weak self] event in
                        guard let self = self else { return }
                        self.dispatch(event: event)
                    }
                )
                .store(in: &store)
            }
        }
    }
}

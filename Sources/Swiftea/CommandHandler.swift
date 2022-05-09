//
//  CommandHandler.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public struct CommandHandler<Command: Equatable, Event, Environment> {
    private let reduce: (Command, Environment) -> AnyPublisher<Event, Never>
    private let environment: Environment

    public init(
        reduce: @escaping (Command, Environment) -> AnyPublisher<Event, Never>,
        environment: Environment
    ) {
        self.reduce = reduce
        self.environment = environment
    }

    func dispatch(
        command: Command,
        cancellableCommands: [Command],
        unhandledCommandsPublisher: AnyPublisher<Command, Never>
    ) -> AnyPublisher<Event, Never> {
        let cancellablePublisher = unhandledCommandsPublisher.filter { unhandledCommand in
            cancellableCommands.contains(unhandledCommand)
        }.eraseToAnyPublisher()
        return reduce(command, environment)
            .receive(on: DispatchQueue.main)
            .prefix(untilOutputFrom: cancellablePublisher)
            .eraseToAnyPublisher()
    }
}

//
//  CommandHandler.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public struct CommandHandler<State, Command, Event, Environment> {
    private let reduce: (State, Command, Environment) -> AnyPublisher<Event, Never>?
    private let environment: Environment

    public init(
        reduce: @escaping (State, Command, Environment) -> AnyPublisher<Event, Never>?,
        environment: Environment
    ) {
        self.reduce = reduce
        self.environment = environment
    }

    func dispatch(
        command: Command,
        state: State
    ) -> AnyPublisher<Event, Never>? {
        return reduce(state, command, environment)
    }
}

//
//  Reducer.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Foundation

public struct Reducer<State, Event, Command> {
    private let reduce: (State, Event) -> Next<State, Command>

    public init(
        reduce: @escaping (State, Event) -> Next<State, Command>
    ) {
        self.reduce = reduce
    }

    public func dispatch(
        state: State,
        event: Event
    ) -> Next<State, Command> {
        reduce(state, event)
    }
}

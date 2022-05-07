//
//  ViewStore.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Combine
import Foundation

public final class ViewStore<UIState, UIEvent> {
    public let statePublisher = PassthroughSubject<UIState, Never>()

    private let eventPublisher = PassthroughSubject<UIEvent, Never>()
    private var cancellable: Set<AnyCancellable> = []

    public init<State, Event, Command, Environment>(
        store: Store<State, Event, Command, Environment>,
        eventMapper: @escaping (UIEvent) -> Event,
        stateMapper: @escaping (State) -> UIState
    ) {
        store.statePublisher.map { value in
            stateMapper(value)
        }.sink { [weak self] state in
            guard let self = self else { return }
            self.statePublisher.send(state)
        }.store(in: &cancellable)

        eventPublisher.map { event in
            eventMapper(event)
        }.sink { event in
            store.dispatch(event: event)
        }.store(in: &cancellable)
    }

    public func dispatch(_ event: UIEvent) {
        eventPublisher.send(event)
    }
}

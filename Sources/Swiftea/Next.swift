//
//  Next.swift
//  Swiftea
//
//  Created by Dmitrii Coolerov on 28.04.2022.
//

import Foundation

public enum Next<State, Command> {
    case empty
    case next(State)
    case dispatch([Command])
    case nextAndDispatch(State, [Command])
}

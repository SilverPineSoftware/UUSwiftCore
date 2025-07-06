//
//  UUTypeAliases.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 7/5/25.
//

import Foundation

public typealias UUErrorBlock<T> = ((Error?) -> Void)
public typealias UUObjectErrorBlock<T> = ((T?, Error?) -> Void)
public typealias UUListErrorBlock<T> = (([T]?, Error?) -> Void)

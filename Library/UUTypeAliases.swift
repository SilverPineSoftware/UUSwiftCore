//
//  UUTypeAliases.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 7/5/25.
//

import Foundation

public typealias UUVoidBlock = (() -> Void)
public typealias UUErrorBlock = ((Error?) -> Void)
public typealias UUObjectBlock<T> = ((T) -> Void)
public typealias UUListBlock<T> = (([T]) -> Void)
public typealias UUObjectErrorBlock<T> = ((T?, Error?) -> Void)
public typealias UUListErrorBlock<T> = (([T]?, Error?) -> Void)

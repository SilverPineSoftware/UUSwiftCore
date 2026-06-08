//
//  UUURL.swift
//  UUSwiftCore
//
//  Created by Jonathan Hays on 10/1/21.
//

import Foundation

extension URL {
	public var uuQueryParameters: [String: String] {

		guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
			  let queryItems = components.queryItems else { return [:] }

		return queryItems.reduce(into: [String: String]())
		{ (result, item) in
			result[item.name] = item.value
		}
	}
}

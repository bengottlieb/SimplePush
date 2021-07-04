//
//  SimplePush.Payload.swift
//  
//
//  Created by Ben Gottlieb on 7/4/21.
//

import Foundation

extension SimplePush {
	public struct Payload {
		let dictionary: [String: Any]
		
		public init(_ raw: [String: Any]) {
			dictionary = raw
		}

		public init(alert: String? = nil, sound: String? = nil, badge: Int? = nil, background: Bool = false, content: [String: Any]? = nil) {
			var dict: [String: Any] = content ?? [:]
			if let alert = alert { dict["alert"] = alert }
			if let sound = sound { dict["sound"] = sound }
			if let badge = badge { dict["badge"] = badge }
			if background { dict["content-available"] = 1 }
			dictionary = dict
		}
		
		var data: Data? {
			let actual = ["aps": dictionary]
			return try? JSONSerialization.data(withJSONObject: actual, options: [])
		}
		
		public static let defaultAlert = Payload(["alert": "This is a test notification. You passed."])
		public static let defaultSound = Payload(["sound": "default"])
	}
}

//
//  Utilities.swift
//  
//
//  Created by Ben Gottlieb on 7/4/21.
//

import Foundation

extension Data {
	var hexString: String {
		 self.map { String(format: "%02hhX", $0) }.joined()
	}
}

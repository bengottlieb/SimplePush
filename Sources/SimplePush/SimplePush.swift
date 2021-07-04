//
//  PushSender.swift
//
//  Created by Ben Gottlieb on 7/4/21.
//

import Foundation
import Security

public class PushSender: NSObject {
	public static let instance = PushSender()
	
	var secIdentity: SecIdentity?
	var secTrust: SecTrust?
	var session = URLSession.shared
	
	enum Error: Swift.Error, LocalizedError { case serverReported(String), status(Int) }
	
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
	
	override init() {
		super.init()
		
		let config = URLSessionConfiguration.default
		session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}
	
	public func send(payload: Payload = .defaultSound, usingSandbox sandbox: Bool = false, priority: Int = 1, to token: Data, completion: ((Swift.Error?) -> Void)? = nil) {
		let raw = "https://api\(sandbox ? ".development" : "").push.apple.com/3/device/\(token.hexString)"
		let url = URL(string: raw)!
		var request = URLRequest(url: url)
		
		request.httpMethod = "POST"
		request.httpBody = payload.data
		
		request.addValue("\(priority)", forHTTPHeaderField: "apns-priority")
		request.addValue("alert", forHTTPHeaderField: "apns-push-type")
		request.addValue("com.standalone.remoteChecklist", forHTTPHeaderField: "apns-topic")

		let task = session.dataTask(with: request) { data, response, error in
			if let result = data, !data.isEmpty, let string = String(data: result, encoding: .utf8) {
				completion?(Error.serverReported(string))
			} else if let code = (response as? HTTPURLResponse)?.statusCode, code != 200 {
				completion?(Error.status(code))
			} else {
				completion?(nil)
			}
			
		}
		task.resume()
	}
	
	@discardableResult public func setup() -> Bool {
		do {
			let data = try Data(contentsOf: .bundled(named: "apns_cert.p12")!)
			var outputArray: CFArray?
			let info = [kSecImportExportPassphrase as NSString: "1"]
			
			let result = SecPKCS12Import(data as NSData, info as CFDictionary, &outputArray)
			
			if let dicts = outputArray as? [[String: AnyObject]], !dicts.isEmpty {
				func f<T>(_ key:CFString) -> T? {
					for d in dicts {
						if let v = d[key as String] as? T {
							return v
						}
					}
					return nil
				}
				
				secIdentity = f(kSecImportItemIdentity)
				secTrust = f(kSecImportItemTrust)
			}
			if result != 0 { print("Failed to import p12: \(result)")}
			return result == 0
		} catch {
			print("Error setting up push: \(error)")
			return false
		}
	}
}

extension PushSender: URLSessionDelegate {
	public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		if let identity = secIdentity {
			var cert: SecCertificate?
			SecIdentityCopyCertificate(identity, &cert)
			
			let cred = URLCredential(identity: identity, certificates: [cert!], persistence: .forSession)
			completionHandler(.useCredential, cred)
		} else {
			completionHandler(.useCredential, challenge.proposedCredential)
		}
	}
}

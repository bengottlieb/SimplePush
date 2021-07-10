//
//  SimplePush.swift
//
//  Created by Ben Gottlieb on 7/4/21.
//

import Foundation
import Security

public class SimplePush: NSObject {
	public static let instance = SimplePush()
	
	var secIdentity: SecIdentity?
	var secTrust: SecTrust?
	var session = URLSession.shared
	
	enum Error: Swift.Error, LocalizedError { case serverReported(String), status(Int) }
	
	override init() {
		super.init()
		
		let config = URLSessionConfiguration.default
		session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}
	
	public static var defaultTopic: String { Bundle.main.bundleIdentifier! }
	
	@discardableResult public func setup(withP12Data p12Data: Data) -> Bool {
		var outputArray: CFArray?
		let info = [kSecImportExportPassphrase as NSString: "1"]
		
		let result = SecPKCS12Import(p12Data as NSData, info as CFDictionary, &outputArray)
		
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
	}
	
	public func send(payload: Payload = .defaultAlert, usingSandbox sandbox: Bool = false, priority: Int = 1, to token: Data, topic: String = SimplePush.defaultTopic, completion: ((Swift.Error?) -> Void)? = nil) {
		let raw = "https://api\(sandbox ? ".development" : "").push.apple.com/3/device/\(token.hexString)"
		let url = URL(string: raw)!
		var request = URLRequest(url: url)
		
		#if targetEnvironment(simulator)
			if !sandbox {
				print("Trying to send a production APNS from the simulator")
			}
		#endif
		
		request.httpMethod = "POST"
		request.httpBody = payload.data
		
		request.addValue("\(priority)", forHTTPHeaderField: "apns-priority")
		request.addValue("alert", forHTTPHeaderField: "apns-push-type")
		request.addValue(topic, forHTTPHeaderField: "apns-topic")

		let task = session.dataTask(with: request) { data, response, error in
			if let result = data, !result.isEmpty, let string = String(data: result, encoding: .utf8) {
				completion?(Error.serverReported(string))
			} else if let code = (response as? HTTPURLResponse)?.statusCode, code != 200 {
				completion?(Error.status(code))
			} else {
				completion?(nil)
			}
			
		}
		task.resume()
	}
}

extension SimplePush: URLSessionDelegate {
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

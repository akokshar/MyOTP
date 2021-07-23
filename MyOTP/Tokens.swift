//
//  Tokens.swift
//  MyOTP
//
//  Created by Alexander Koksharov on 08.02.2021.
//

import Foundation
import AVFoundation
import SwiftUI
import CryptoKit
import Security
import LocalAuthentication

enum TokenError: Error {
    case LoadQRCodeError(String)
    case TOTPError(String)
    case KeychainError(String)
}

enum Algorithm: String, CaseIterable, Identifiable {
    case SHA1
    case SHA256
    case SHA512

    var id: String { self.rawValue }
}

struct TokenData: Codable {
    let id: UUID
    var issuer: String = ""
    var account: String = ""
    var secret: String = ""
    var alg: String = Algorithm.SHA1.rawValue
    var startTime: Int = 0
    var period: Int = 30
    var digits: Int = 6
    var refresh: Int = 0 // used to trigger ui refresh

    enum CodingKeys: String, CodingKey {
        case id
        case issuer
        case account
        case secret
        case alg
        case startTime
        case period
        case digits
    }

    var algorithm: Algorithm {
        guard let a = Algorithm(rawValue: alg) else {
            print("Account '\(account)' from '\(issuer)': unknown algorithm. Defaulting to SHA1.")
            return Algorithm.SHA1
        }
        return a
    }
}

class Token: Identifiable, ObservableObject {

    @Published var tokenData: TokenData
//    @Published var state: String = ""
    let persisted: Bool

    var id: UUID {
        return tokenData.id
    }

    init?(serializedData data: Data) {
        guard let tokenData = try? JSONDecoder().decode(TokenData.self, from: data) else {
            return nil
        }
        self.tokenData = tokenData
        persisted = true
//        state = tokenData.account
    }

    func serialize() -> Data? {
        return try? JSONEncoder().encode(tokenData)
    }

    init(_ name: String, _ account: String) {
        self.tokenData = TokenData(
            id: UUID(),
            issuer: name,
            account: account
        )
        persisted = false
//        state = "New token"
    }

    func loadFromQRCode(_ image: NSImage?) throws {
        guard let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TokenError.LoadQRCodeError("Cant read image")
        }

        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh]) else {
            throw TokenError.LoadQRCodeError("CIDetector initialization failed")
        }

        let ciImage = CIImage(cgImage: cgImage)
        let features = detector.features(in: ciImage)
        var otpAuthUrlStr = ""
        for feature in features as! [CIQRCodeFeature] {
            if let f = feature.messageString {
                otpAuthUrlStr += f
            }
        }

        guard let otpAuthUrl = URLComponents(string: otpAuthUrlStr) else {
            throw TokenError.LoadQRCodeError("Cant parse decoded QR code")
        }

        print(otpAuthUrl.debugDescription)

        guard otpAuthUrl.scheme == "otpauth" else {
            throw TokenError.LoadQRCodeError("only 'otpauth' scheme is supported")
        }

        guard otpAuthUrl.host == "totp" else {
            throw TokenError.LoadQRCodeError("only 'TOTP' is supported")
        }

        var tokenData = TokenData(id: self.tokenData.id)

        let path = otpAuthUrl.path.split(separator: ":")
        if path.count == 2 {
            tokenData.issuer = String(path[0])
            tokenData.account = String(path[1])
        } else if path.count == 1 {
            tokenData.issuer = ""
            tokenData.account = String(path[0])
        } else {
            throw TokenError.LoadQRCodeError("cant parse 'path' component")
        }

        if let queryItems = otpAuthUrl.queryItems {
            for queryItem in queryItems {
                switch queryItem.name {
                case "issuer": do {
                    guard let issuer = queryItem.value else {
                        throw TokenError.LoadQRCodeError("cant read token 'issuer' param")
                    }
                    if self.tokenData.issuer.isEmpty && self.tokenData.issuer != issuer {
                        throw TokenError.LoadQRCodeError("issuer parameter does not mutch issuer label prefix")
                    }

                    tokenData.issuer = issuer
                }
                case "secret": do {
                    guard let secret = queryItem.value else {
                        throw TokenError.LoadQRCodeError("cant read 'secret' param")
                    }
                    tokenData.secret = secret
                }
                case "algorithm": do {
                    guard let value = queryItem.value else {
                        throw TokenError.LoadQRCodeError("cant read 'algorithm' param")
                    }
                    let algorithm = Algorithm.allCases.first { (a) -> Bool in
                        a.rawValue == value
                    }
                    guard algorithm != nil else {
                        throw TokenError.LoadQRCodeError("unknown algorithm")
                    }
                    tokenData.alg = algorithm!.rawValue
                }
                case "digits": do {
                    guard let value = queryItem.value, let digits = Int(value) else {
                        throw TokenError.LoadQRCodeError("cant read 'digits' param")
                    }
                    guard digits >= 6 && digits <= 8 else {
                        throw TokenError.LoadQRCodeError("'digits' is out of range")
                    }
                    tokenData.digits = digits
                }
                case "period": do {
                    // used only for TOTP
                    guard let value = queryItem.value, let period = Int(value) else {
                        throw TokenError.LoadQRCodeError("cant read 'period' param")
                    }
                    guard period >= 30 && period <= 60 else {
                        throw TokenError.LoadQRCodeError("'period' is out of range")
                    }
                    tokenData.period = period
                }
                default: ()
                }
            }
        }
        self.tokenData = tokenData
    }

    private func decodeBase32Secret(secret: String) -> Data? {
        guard let secretData = secret.uppercased().data(using: .utf8) as NSData? else {
            return nil
        }

        guard let transform = SecDecodeTransformCreate(kSecBase32Encoding, nil) else {
            return nil
        }

        if !SecTransformSetAttribute(transform, kSecTransformInputAttributeName, secretData, nil) {
            return nil
        }

        return SecTransformExecute(transform, nil) as? Data
    }

    private func with(key: Data, data: Data, handler: ([UInt8])->Void) {
        switch tokenData.algorithm {
        case .SHA1:
            var h =  HMAC<Insecure.SHA1>(key: SymmetricKey(data: key))
            h.update(data: data)
            let mac = h.finalize()

            mac.withUnsafeBytes { (buffer) -> Void in
                handler(Array.init(buffer))
            }
        case .SHA256:
            var h =  HMAC<SHA256>(key: SymmetricKey(data: key))
            h.update(data: data)
            let mac = h.finalize()

            mac.withUnsafeBytes { (buffer) -> Void in
                handler(Array.init(buffer))
            }
        case .SHA512:
            var h =  HMAC<SHA512>(key: SymmetricKey(data: key))
            h.update(data: data)
            let mac = h.finalize()

            mac.withUnsafeBytes { (buffer) -> Void in
                handler(Array.init(buffer))
            }
        }
    }

    func getHOTP() -> String {
        return ""
    }

    func genTOTP() throws -> String {
        guard let keyData = decodeBase32Secret(secret: tokenData.secret) else {
            throw TokenError.TOTPError("Cant decode key data")
        }
        let tData = withUnsafeBytes(of: UInt((Date().timeIntervalSince1970 - Double(tokenData.startTime)) / Double(tokenData.period)).byteSwapped) { (bytes) in
//        let tData = withUnsafeBytes(of: UInt((Int(Date().timeIntervalSince1970) - tokenData.startTime) / tokenData.period).byteSwapped) { (bytes) in
            Data(bytes)
        }
        var token: UInt32 = 0
        with(key: keyData, data: tData) { (bytes) in
            let offset = Int(bytes[bytes.count - 1] & 0xf)
            let value: UInt32 =
                UInt32(bytes[offset] & 0x7f) << 24 |
                UInt32(bytes[offset + 1] & 0xff) << 16 |
                UInt32(bytes[offset + 2] & 0xff) << 8 |
                UInt32(bytes[offset + 3] & 0xff)

            token = value % UInt32(floor(pow(10,Double(tokenData.digits))))
        }

        return String(format: "%0\(tokenData.digits)d",  token)
    }

    func touch() {
        tokenData.refresh += 1
    }

    func tokenAge() -> Float {
        return Float(Int(Date().timeIntervalSince1970 - Double(tokenData.startTime)) % tokenData.period) / Float(tokenData.period)
    }
}

class Tokens: ObservableObject {
    @Published var items: [Token] = []

    private let keychainName: String = "myotp.keychain"
    private let authContext: LAContext = LAContext()
    private var keychain: SecKeychain? = nil

    init() {
        var status = SecKeychainCreate(keychainName, 0, "", false, nil, &keychain)
        if status == errSecDuplicateKeychain {
            status = SecKeychainOpen(keychainName, &keychain)
        }

        if status != errSecSuccess {
            let errStr = SecCopyErrorMessageString(status, nil)
            print("Cant open keychain \(errStr.debugDescription)")
            return
        }

        authContext.localizedReason = "Allow MyOTP access to its keychain"

        let query: [String: Any] = [
            kSecUseKeychain as String: keychain as AnyObject,
            kSecUseAuthenticationContext as String: authContext as AnyObject,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrDescription as String: "MyOTP",
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return
        }

        guard status == errSecSuccess else {
            let errStr = SecCopyErrorMessageString(status, nil)
            print("Cant enumerate items in the keychain \(errStr.debugDescription)")
            return
        }

        guard let itemsRefs = result as? [Any] else {
            print("Unexpected result while enumerating keychain items")
            return
        }

        for itemRef in itemsRefs {
            var item: AnyObject?

            let itemQuery: [String: Any] = [
                kSecValueRef as String: itemRef,
                kSecReturnAttributes as String: true,
                kSecReturnData as String: true
            ]

            status = SecItemCopyMatching(itemQuery as CFDictionary, &item)
            guard status == errSecSuccess else {
                let errStr = SecCopyErrorMessageString(status, nil)
                print("Cant read keychain item: \(errStr.debugDescription)")
                continue
            }

            guard let itemAttrs = item as? [String: Any] else {
                print("Unexpected result while retrieving a keychain item")
                continue
            }

            guard let serializedData = itemAttrs[kSecValueData as String] as? Data else {
                print("Cant read keychain item's secret value")
                continue
            }

            guard let token = Token(serializedData: serializedData) else {
                print("Cant restore token from serialized data")
                continue
            }
            items.append(token)
        }
        touch()
    }

    init(_ items: [Token]) {
        self.keychain = nil
        self.items = items
    }

    func token(withId id: UUID) -> Token? {
        return items.first { item in
            item.id == id
        }
    }

    func saveToken(fromImage image: NSImage?) throws {
        throw TokenError.LoadQRCodeError("Not implementes")
    }

    func saveToken(_ token: Token) throws {
        guard let keychain = self.keychain else {
            throw TokenError.KeychainError("Keychain init error")
        }

        guard let secValue = token.serialize() else {
            throw TokenError.KeychainError("Serialization error")
        }

        let itemQuery: [String: Any] = [
            kSecUseKeychain as String: keychain as AnyObject,
            kSecUseAuthenticationContext as String: authContext as AnyObject,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrDescription as String: "MyOTP",
            kSecAttrLabel as String: token.tokenData.id.uuidString,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let attributes: [String: Any] = [
            kSecAttrService as String: token.tokenData.issuer,
            kSecAttrAccount as String: token.tokenData.account,
            kSecValueData as String: secValue as AnyObject
        ]

        var item: AnyObject?
        var status = SecItemCopyMatching(itemQuery as CFDictionary, &item)
        if status == errSecSuccess {
            status = SecItemUpdate(itemQuery as CFDictionary, attributes as CFDictionary)
        } else {
            status = SecItemAdd(itemQuery.merging(attributes) { (_, new) in new } as CFDictionary, nil)
            if status == errSecSuccess {
                items.append(token)
            }
        }

        if status != errSecSuccess {
            if let errorMessage = SecCopyErrorMessageString(status, nil) {
                throw TokenError.KeychainError("\(errorMessage)")
            }
            throw TokenError.KeychainError("Error: \(status)")
        }
        token.touch()
    }

    func deleteToken(_ token: Token) {
        let query: [String: Any] = [
            kSecUseKeychain as String: keychain as AnyObject,
            kSecUseAuthenticationContext as String: authContext as AnyObject,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrDescription as String: "MyOTP",
            kSecAttrLabel as String: token.id.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            let errStr = SecCopyErrorMessageString(status, nil)
            print("Cant delete keychain item with id '\(token.id.uuidString)': \(errStr.debugDescription)")
            return
        }

        items.removeAll { (item) -> Bool in
            item.id == token.id
        }
    }

    func touch() {
        items.forEach { token in
            token.touch()
        }
    }
}

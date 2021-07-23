import Cocoa
import Security

var status: OSStatus

// Restore default
//let loginKCName = "login.keychain"
//var loginKC: SecKeychain?
//
//status = SecKeychainOpen(loginKCName, &loginKC)
//if status == OSStatus(errSecSuccess) {
//    SecKeychainSetDefault(loginKC)
//}

let name = "test.keychain"
var keychain: SecKeychain?

status = SecKeychainCreate(name, 0, "", false, nil, &keychain)
if status == OSStatus(errSecDuplicateKeychain) {
    status = SecKeychainOpen(name, &keychain)
}
//SecKeychainSetDefault(keychain)

var item: AnyObject?

let item1 = [
    kSecAttrLabel: "MyOTP",
//    kSecAttrSynchronizable: true,
    kSecAttrComment: "MyOTP",
    kSecReturnAttributes: true,
    kSecReturnData: true,
    kSecValueData: "YAY PASSWORD!!".data(using: .utf8)!,
    kSecAttrServer: "google.shmoogle.com",
    kSecClass: kSecClassInternetPassword,
    kSecUseKeychain: "test."
] as CFDictionary

status = SecItemAdd(item1, &item)
if status != errSecSuccess {
    status = SecItemCopyMatching(item1, &item)
}
print("Operation finished with status: \(status)")

let item2 = [
    kSecAttrLabel: "MyOTP",
    //    kSecAttrSynchronizable: true,
//    kSecUseKeychain: "test.keychain",
    kSecAttrComment: "MyOTP",
    kSecReturnAttributes: true,
    kSecReturnData: true,
    kSecValueData: "YAY PASSWORD!!".data(using: .utf8)!,
    kSecAttrServer: "google.hujugle.com",
    kSecClass: kSecClassInternetPassword
] as CFDictionary

status = SecItemAdd(item2, &item)
if status != errSecSuccess {
    status = SecItemCopyMatching(item2, &item)
}
print("Operation finished with status: \(status)")


let dic = item as! NSDictionary
//let username = dic[kSecAttrAccount] ?? ""
let passwordData = dic[kSecValueData] as! Data
let password = String(data: passwordData, encoding: .utf8)!
//print("Username: \(username)")
print("Password: \(password)")


//// Restore default
//let loginKCName = "login.keychain"
//var loginKC: SecKeychain?
//
//status = SecKeychainOpen(loginKCName, &loginKC)
//if status == OSStatus(errSecSuccess) {
//    SecKeychainSetDefault(loginKC)
//}

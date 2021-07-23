import Cocoa
import CryptoKit
//import CommonCrypto

func stringToBytes(_ string: String) -> [UInt8]? {
    let length = string.count
    if length & 1 != 0 {
        return nil
    }
    var bytes = [UInt8]()
    bytes.reserveCapacity(length/2)
    var index = string.startIndex
    for _ in 0..<length/2 {
        let nextIndex = string.index(index, offsetBy: 2)
        guard let b = UInt8(string[index..<nextIndex], radix: 16) else {
            return nil
        }
        bytes.append(b)
        index = nextIndex
    }
    return bytes
}

let secret = "3132333435363738393031323334353637383930"
let x: UInt = 30
let t0: UInt = 0

let timeInterval: UInt = 20000000000 // Date().timeIntervalSince1970

let t = UInt((timeInterval - t0) / x)

let tData = withUnsafeBytes(of: t.byteSwapped) { (bytes) in
    Data(bytes)
}

var h = HMAC<Insecure.SHA1>(key: SymmetricKey(data: stringToBytes(secret)!))
h.update(data: tData)
let mac = h.finalize()
let bin: UInt32 = mac.withUnsafeBytes { (buffer) -> UInt32 in
    let offset = Int(buffer[buffer.count - 1] & 0x0f)
    let value: UInt32 =
        UInt32(buffer[offset] & 0x7f) << 24 |
        UInt32(buffer[offset + 1] & 0xff) << 16 |
        UInt32(buffer[offset + 2] & 0xff) << 8 |
        UInt32(buffer[offset + 3] & 0xff)

    return value % UInt32(floor(pow(10,8)))
}

if bin == 94287082 {
    print("YAY!")
} else {
    print("NO")
}


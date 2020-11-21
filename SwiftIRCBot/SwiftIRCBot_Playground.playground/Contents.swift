// : Playground - noun: a place where people can play

import Cocoa

var uts = utsname()
uname(&uts)

let mirror = Mirror(reflecting: uts.version)
var version: String = ""
for (_, value) in mirror.children {
    if let casted = value as? Int8 {
        version.append(UnicodeScalar(UInt8(casted)))
    }
}

print(version.stringByReplacingOccurrencesOfString(":", withString: "\\:"))
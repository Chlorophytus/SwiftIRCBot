import Foundation
struct SwiftIRCHandler {
    struct Version {
        static let major = 1
        static let minor = 3
        static let patch = 0
        static let status = VersioningStatus.Stable
    }
}

protocol IRCHandlerProtocol {
    var Host: String { get }
    var Port: Int16 { get }
    var UseSSL: Bool { get }
    var SASLCredentials: (String /* Username */, String /* Password */)? { get }
    var IRCBuffer: [UInt8] { get set }

    var GenericCredentials: (String? /* Password */, String /* Username */, String /* Computer username */, Bool /* Invisible */, String /* Real name */) { get }

    var Loop: Bool { get set }
    var CurrentNick: Int { get set }

    // set SASLCredentials to nil if we don't auth with SASL
    var InputStream: NSInputStream? { get }
    var OutputStream: NSOutputStream? { get }

    func doLoop()
    func doSend(Command: String, Params: [String], LongParam: String?)

    func connect()
    func disconnect()
    func onReceive(Prefix: String?, Command: String, Params: [String],
        LongParam: String?)
}

class IRCHandlerBase: NSObject, NSStreamDelegate {
    var Host: String
    var Port: Int16
    var UseSSL: Bool
    var SASLCredentials: (String, String)?
    var GenericCredentials: (String?, String, String, Bool, String)

    var IRCBuffer = [UInt8](count: 65536, repeatedValue: 0)

    var Loop: Bool = true
    var CurrentNick: Int = 0

    var InputStream: NSInputStream?
    var OutputStream: NSOutputStream?

    init(Host: String, Port: Int16, UseSSL: Bool, SASLCredentials: (String, String)?, GenericCredentials: (String?, String, String, Bool, String)) {
        self.Host = Host
        self.Port = Port
        self.UseSSL = UseSSL
        self.SASLCredentials = SASLCredentials
        self.GenericCredentials = GenericCredentials

        super.init()
        connect()
    }

    func doSend(Command: String, Params: [String], LongParam: String?) {
        var rawString = String()
        rawString += Command
        if !Params.isEmpty {
            for str in Params { rawString += " " + str }
        }
        if LongParam != nil { rawString += " :" + LongParam! }
        rawString += "\r\n"

        let data: NSData = rawString.dataUsingEncoding(NSUTF8StringEncoding)!
        var buffer = [UInt8](count: data.length, repeatedValue: 0)

        data.getBytes(&buffer, length: data.length)
        OutputStream!.write(&buffer, maxLength: data.length)
    }

    func doLoop() {
        if InputStream!.hasBytesAvailable {
            var lines = [[UInt8]]()
            lines.append([UInt8]())
            while InputStream!.hasBytesAvailable {
                InputStream!.read(&IRCBuffer, maxLength: IRCBuffer.count)
                for rawcharacter in IRCBuffer {
                    switch rawcharacter {
                    case 0:
                        continue
                    case 10:
                        lines[lines.count - 1].append(0)
                        lines.append([UInt8]())
                        break
                    case 13:
                        continue
                    default:
                        lines[lines.count - 1].append(rawcharacter)
                    }
                }
                IRCBuffer = [UInt8](count: IRCBuffer.count, repeatedValue: 0)
            }
            lines.removeLast()
            for rawstring in lines {
                let string = String.fromCString(UnsafePointer<CChar>(rawstring))
                if string != nil {
                    var Prefix: String?
                    var Command: String = ""
                    var Params = [""]
                    var LongParam: String? = nil

                    var currPart: UInt8 = 0
                    for theChar in string!.characters {
                        if theChar == " " {
                            switch currPart {
                            case 64:
                                Params.append("")
                                currPart = 4
                                continue
                            case 65:
                                LongParam!.append(theChar)
                                continue
                            default:
                                currPart += 1
                                continue
                            }
                        }

                        switch currPart {
                        case 0:
                            if theChar == ":" {
                                Prefix = ""
                                currPart = 1 }
                            else {
                                Prefix = nil
                                currPart = 2
                                Command.append(theChar)
                            }
                        case 1:
                            Prefix!.append(theChar)
                        case 2:
                            Command.append(theChar)
                            currPart = 3
                        case 3:
                            Command.append(theChar)
                        case 4:
                            if theChar == ":" {
                                LongParam = String()
                                currPart = 65
                            }
                            else {
                                Params[Params.count - 1].append(theChar)
                                currPart = 64
                            }
                        case 64:
                            Params[Params.count - 1].append(theChar)
                        case 65: LongParam!.append(theChar)
                        default: continue
                        }
                    }
                    Params.removeLast()

                    onReceive(Prefix, Command: Command, Params: Params, LongParam: LongParam)
                }
            }
        }
    }

    func connect() {
        // print("Initializing streams...")

        NSStream.getStreamsToHostWithName(Host, port: Int(Port),
            inputStream: &InputStream, outputStream: &OutputStream)

        InputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(),
            forMode: NSDefaultRunLoopMode)
        OutputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(),
            forMode: NSDefaultRunLoopMode)

        InputStream!.delegate = self
        OutputStream!.delegate = self

        // print("Opening streams...")
        InputStream!.open()
        OutputStream!.open()

        if UseSSL {
            InputStream!.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
            OutputStream!.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
        }

        if SASLCredentials != nil {
            doSend("CAP", Params: ["REQ"], LongParam: "sasl")
        }

        if GenericCredentials.0 != nil {
            doSend("PASS", Params: [GenericCredentials.0!], LongParam: nil)
        }

        doSend("NICK", Params: [GenericCredentials.1], LongParam: nil)
        doSend("USER", Params: [GenericCredentials.2, (GenericCredentials.3 ? "8" : "0"), "*"], LongParam: GenericCredentials.4)

        Loop = true

    }

    func disconnect() {
        Loop = false

        InputStream!.close()
        OutputStream!.close()

        InputStream!.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        OutputStream!.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)

        InputStream = nil
        OutputStream = nil
    }

    func onReceive(Prefix: String?, Command: String, Params: [String], LongParam: String?) {
        switch Command {
        case "AUTHENTICATE":
            if let data = "\(SASLCredentials!.0)\0\(SASLCredentials!.0)\0\(SASLCredentials!.1)".dataUsingEncoding(NSUTF8StringEncoding) {
                let str = data.base64EncodedStringWithOptions([])
                doSend("AUTHENTICATE", Params: [str], LongParam: nil)
            }
        case "CAP":
            if Params.contains("ACK") {
                if let caps = LongParam?.componentsSeparatedByString(" ") {
                    if caps.contains("sasl") {
                        doSend("AUTHENTICATE", Params: ["PLAIN"], LongParam: nil)
                    }
                }
            }
        case "903":
            doSend("CAP", Params: ["END"], LongParam: nil)
        default:
            break
        }
    }
}

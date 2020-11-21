import Foundation

struct SwiftIRCBot {
    struct Variables {
        static let Location: String = NSString(string: "~/.swiftircbot/\(Process.arguments[1])/\(Process.arguments[2])").stringByExpandingTildeInPath
        static var ConfigData = Config.factory()
        static var Plugins = [BotIRCPluginProtocol]()
        static let MaxGTHits = 8
        static let FileManager = NSFileManager.defaultManager()
    }
    struct Version {
        static let major = 1
        static let minor = 9
        static let patch = 1
        static let codename = "Bakersfield"
        static let build = NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as? String
        static let status = VersioningStatus.Stable
    }
}

protocol BotIRCHandlerProtocol: IRCHandlerProtocol {
    var Channel: String { get }
    var Trigger: String { get }
    var Owner: String { get }
    var LoadedPlugins: [BotIRCPluginProtocol] { get }
    var GTQueue: dispatch_queue_t { get }
    var GTHits: UInt { get set }
}

protocol BotIRCPluginProtocol {
    static var Identity: String { get }
}

protocol BotIRCFilePluginProtocol {
    static var File: BotIRCFileWrapper { get }
}

protocol BotIRCDatabasePluginProtocol {
    static var Files: [BotIRCFileWrapper] { get set }
}

protocol BotIRCNestedDatabaseWrapperProtocol: BotIRCDatabasePluginProtocol {
    static var Directories: [BotIRCDatabaseWrapper] { get set }
}

protocol BotIRCParentPluginGroupProtocol: BotIRCPluginProtocol {
    associatedtype ChildPluginType

    static var Plugins: [ChildPluginType] { get set }
    var LoadedPlugins: [ChildPluginType] { get }
}

protocol BotIRCDumbPluginProtocol: BotIRCPluginProtocol {
    func onEvent(Target: BotIRCHandlerBase, Prefix: String?, Command: String, Params: [String], LongParam: String?)
}

protocol BotIRCCommandPluginProtocol: BotIRCPluginProtocol {
    static var CommandName: String { get }
}

protocol BotIRCSmartPluginProtocol: BotIRCCommandPluginProtocol {
    static var CommandName: String { get }
    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String])
}

class BotIRCFileWrapper {
    private var Location: String
    private var Dirty = true
    private var DirtyData = ""
    var Data: String? {
        get {
            do {
                if Dirty {
                    DirtyData = try NSString(contentsOfFile: self.Location, encoding: NSUTF8StringEncoding) as String
                    Dirty = false
                }
                return DirtyData
            }
            catch let error as NSError {
                print("\u{7}Error in BotIRCFileWrapper.Data.get")
                print("\(error.userInfo)")
                print("====== END ERROR ======")
                return nil
            }
        }
        set {
            do {
                try newValue?.writeToFile(Location, atomically: true, encoding: NSUTF8StringEncoding)
                Dirty = true
            }
            catch let error as NSError {
                print("\u{7}Error in BotIRCFileWrapper.Data.set")
                print("\(error.userInfo)")
                print("====== END ERROR ======")

            }
        }
    }

    init(Location: String) {
        self.Location = "\(SwiftIRCBot.Variables.Location)/\(Location).txt"
    }

    func setDirty() { Dirty = true }
    private func remove() {
        do {
            try SwiftIRCBot.Variables.FileManager.removeItemAtPath(self.Location)
        }
        catch let error as NSError {
            print("\u{7}Error in BotIRCFileWrapper.remove")
            print("\(error.userInfo)")
            print("====== END ERROR ======")

        }
    }
}

class BotIRCDatabaseWrapper {
    private var Files = [String: BotIRCFileWrapper]()
    private var Directory: String
    private var Location: String

    private var Enumerator: NSDirectoryEnumerator? {
        get {
            let FileManager = SwiftIRCBot.Variables.FileManager
            if let RawEnumerator = FileManager.enumeratorAtPath(Directory) {
                return RawEnumerator
            }
            else {
                do {
                    try FileManager.createDirectoryAtPath(Directory, withIntermediateDirectories: true, attributes: nil)
                    return FileManager.enumeratorAtPath(Directory)
                }
                catch let error as NSError {
                    print("\u{7}Error in BotIRCDatabaseWrapper.Enumerator.get")
                    print("\(error.userInfo)")
                    print("====== END ERROR ======")
                    return nil
                }
            }
        }
    }

    init(Location: String) {
        self.Location = Location
        self.Directory = NSString(string: "\(SwiftIRCBot.Variables.Location)/\(Location)").stringByExpandingTildeInPath
        let enumerator = Enumerator

        while let file = enumerator?.nextObject() as? String {
            if file == ".DS_Store" { continue }
            let strip = file.stringByReplacingOccurrencesOfString(".txt", withString: "")
            Files[strip] = BotIRCFileWrapper(Location: "\(Location)/\(strip)")
        }
    }

    subscript(index: String) -> String? {
        get {
            if let File = Files[index] {
                return File.Data
            }
            else {
                return nil
            }
        }
        set {
            if let val = Files[index] {
                if let string = newValue {
                    val.Data = string
                }
                else {
                    val.remove()
                    Files[index] = nil
                }
            }
            else if let string = newValue {
                Files[index] = BotIRCFileWrapper(Location: "\(Location)/\(index)")
                if let file = Files[index] {
                    file.Data = string
                }
            }
        }
    }
}

class BotIRCHandlerBase: IRCHandlerBase {
    let Channel: String = Process.arguments[2]
    let Trigger: String = SwiftIRCBot.Variables.ConfigData.1.trigger!
    let Owner: String = SwiftIRCBot.Variables.ConfigData.1.owner_account!
    var LoadedPlugins = [BotIRCPluginProtocol]()

    let GTQueue = dispatch_queue_create(
        "com.metivier.roland.IRCHandlerAsyncJobs", DISPATCH_QUEUE_CONCURRENT)
    var GTHits = 0

    init(OtherLoad: [(String, ([String]) -> ())]) {
        let module_line = SwiftIRCBot.Variables.ConfigData.1.module_load_line!.componentsSeparatedByString(" ")
        let module_line_plugins = module_line[0].componentsSeparatedByString(",")

        if module_line.count > 1 {
            let args = module_line[1 ..< module_line.count]
            for arg in args {
                let mod = arg.componentsSeparatedByString(":")
                let submods = mod[1].componentsSeparatedByString(",")
                for (wantedMod, wantedFun) in OtherLoad {
                    if wantedMod == mod[0] {
                        wantedFun(submods)
                    }
                }
            }
        }

        for ident in module_line_plugins {
            for plugin in SwiftIRCBot.Variables.Plugins {
                if plugin.dynamicType.Identity == ident {
                    LoadedPlugins.append(plugin)
                }
            }
        }

        super.init(
            Host: SwiftIRCBot.Variables.ConfigData.1.host!,
            Port: SwiftIRCBot.Variables.ConfigData.1.port,
            UseSSL: SwiftIRCBot.Variables.ConfigData.1.use_ssl,
            SASLCredentials: (SwiftIRCBot.Variables.ConfigData.1.use_sasl ?
                (SwiftIRCBot.Variables.ConfigData.1.sasl_username!,
                    SwiftIRCBot.Variables.ConfigData.1.sasl_password!) :
                    nil),
            GenericCredentials: (SwiftIRCBot.Variables.ConfigData.1.password,
                SwiftIRCBot.Variables.ConfigData.1.nickname!,
                SwiftIRCBot.Variables.ConfigData.1.ident!,
                SwiftIRCBot.Variables.ConfigData.1.invisible,
                SwiftIRCBot.Variables.ConfigData.1.real_name!))
    }

    override func onReceive(Prefix: String?, Command: String, Params: [String], LongParam: String?) {
        super.onReceive(Prefix, Command: Command, Params: Params,
            LongParam: LongParam)
        for plugin in LoadedPlugins {
            if let handler = plugin as? BotIRCDumbPluginProtocol {
                handler.onEvent(self, Prefix: Prefix, Command: Command, Params: Params, LongParam: LongParam)
            }
        }
    }
}

class BotIRCSmartPluginDump: BotIRCSmartPluginProtocol {
    static let CommandName = "dump"
    static let Identity = "dump"

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): Command parameter dump: \(Params)")
    }
}

class BotIRCSmartPluginPing: BotIRCSmartPluginProtocol {
    static let CommandName = "ping"
    static let Identity = "ping"

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): \"ping\" takes no arguments.")
            return
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): Pong")
    }
}

class BotIRCSmartPluginVersion: BotIRCSmartPluginProtocol {
    static let CommandName = "version"
    static let Identity = "version"

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): \"version\" takes no arguments.")
            return
        }

        if let num = SwiftIRCBot.Version.build {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): SwiftIRCHandler v\(SwiftIRCHandler.Version.major).\(SwiftIRCHandler.Version.minor).\(SwiftIRCHandler.Version.patch)\(GetVersionString(SwiftIRCHandler.Version.status)) - SwiftIRCBot v\(SwiftIRCBot.Version.major).\(SwiftIRCBot.Version.minor).\(SwiftIRCBot.Version.patch)\(GetVersionString(SwiftIRCBot.Version.status)) b\(num) \"\(SwiftIRCBot.Version.codename)\"")
        }
        else {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): SwiftIRCHandler v\(SwiftIRCHandler.Version.major).\(SwiftIRCHandler.Version.minor).\(SwiftIRCHandler.Version.patch)\(GetVersionString(SwiftIRCHandler.Version.status)) - SwiftIRCBot v\(SwiftIRCBot.Version.major).\(SwiftIRCBot.Version.minor).\(SwiftIRCBot.Version.patch)\(GetVersionString(SwiftIRCBot.Version.status)) BUILD NUMBER UNSPECIFIED \"\(SwiftIRCBot.Version.codename)\"")
        }
    }
}

class BotIRCSmartPluginWisdom: BotIRCSmartPluginProtocol {
    static let CommandName = "wisdom"
    static let Identity = "wisdom"
    static var Wisdom = [String]()
    static let File = BotIRCFileWrapper(Location: Identity)

    init?() {
        if let data = self.dynamicType.File.Data {
            var data2: String
            if data.isEmpty {
                data2 = "Wisdom file was empty. The waters are red."
                self.dynamicType.File.Data = data2
            } else {
                data2 = data
            }
            var wisdom = data2.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
            for i in 0 ... wisdom.count - 1 {
                if wisdom[i].isEmpty { wisdom.removeAtIndex(i) }
            }

            self.dynamicType.Wisdom = wisdom
        }
        else {
            print("Error loading wisdom plugin: Data failure")
            return nil
        }
    }

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): \"wisdom\" takes no arguments.")
            return
        }

        let theWisdom = Int(arc4random_uniform(UInt32(self.dynamicType.Wisdom.count)))

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): Wisdom #\(theWisdom + 1): \(self.dynamicType.Wisdom[theWisdom])")
    }
}

class BotIRCSmartPluginHelp: BotIRCSmartPluginProtocol {
    static let Identity = "help"
    static let CommandName = "help"

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): \"help\" takes no arguments.")
            return
        }

        var names = [String]()
        for plugin in Target.LoadedPlugins {
            if let handler = plugin as? BotIRCSmartPluginProtocol {
                names.append(handler.dynamicType.CommandName)
            }
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User): Available commands - \(names.joinWithSeparator(", "))")
    }
}

class BotIRCDumbPluginCore: BotIRCDumbPluginProtocol {
    static let Identity = "core"

    func onEvent(Target: BotIRCHandlerBase, Prefix: String?, Command: String, Params: [String], LongParam: String?) {
        switch Command {
        case "466":
            print("S>C: *** BAN WARNING, ACTIVATING KILLSWITCH ***")
            Target.doSend("QUIT", Params: [], LongParam: "SwiftIRCHandler - Error 466")
            Target.disconnect()
            exit(EXIT_FAILURE)
        case "376":
            sleep(1)
            Target.doSend("JOIN", Params: [Target.Channel], LongParam: nil)
        case "PING":
            print("S>C: Pinged by the server")
            Target.doSend("PONG", Params: [], LongParam: LongParam)
        case "PRIVMSG":
            let user = Prefix![Prefix!.startIndex ... Prefix!.rangeOfString("!")!.startIndex.predecessor()]
            let host = Prefix![Prefix!.rangeOfString("!")!.startIndex.successor() ... Prefix!.endIndex.predecessor()]
            let Source = ((Params[0] == Target.GenericCredentials.1) ? user : Params[0])
            print("S>C: \(Source): <\(user) (\(host))> \(LongParam)")

            if let lparam = LongParam {
                if lparam.containsString("\u{1}") {
                    let ctcpreq = lparam.componentsSeparatedByString("\u{1}")
                    print("S>C: Parsed CTCP request: \(ctcpreq)")
                    if ctcpreq.count > 2 {
                        if ctcpreq[1] == "VERSION" {
                            var uts = utsname()
                            uname(&uts)

                            let mirror = Mirror(reflecting: uts.version)
                            var version: String = ""
                            for (_, value) in mirror.children {
                                if let casted = value as? Int8 {
                                    if casted == 0 { break }
                                    version.append(UnicodeScalar(UInt8(casted)))
                                }
                            }

                            Target.doSend("NOTICE", Params: [Source], LongParam: "\u{1}VERSION \(Target.GenericCredentials.1):SwiftIRCBot v\(SwiftIRCBot.Version.major).\(SwiftIRCBot.Version.minor).\(SwiftIRCBot.Version.patch)\(GetVersionString(SwiftIRCBot.Version.status)):\(version))\u{1}")
                        }
                    }
                }
            }

            if LongParam!.hasPrefix(Target.Trigger) {
                if LongParam! == Target.Trigger {
                    Target.doSend("PRIVMSG", Params: Params, LongParam: "\(user): You did not send a command")
                }
                else {
                    let command = LongParam![LongParam!.rangeOfString(Target.Trigger)!.endIndex ... LongParam!.endIndex.predecessor()].componentsSeparatedByString(" ")
                    let commandslice = Array(command[1 ..< command.count])
                    var found = false
                    for plugin in Target.LoadedPlugins {
                        if let handler = plugin as? BotIRCSmartPluginProtocol {
                            if handler.dynamicType.CommandName == command[0] {
                                handler.onEvent(Target, User: user, Host: host, Source: Source, Params: commandslice)
                                found = true
                            }
                        }
                    }
                    if !found {
                        Target.doSend("PRIVMSG", Params: Params, LongParam: "\(user): Command not found")
                    }
                }
            }
        case "ERROR":
            print("S>C: *** Errored out... ***")
            exit(EXIT_FAILURE)
        default:
            print("S>C: Prefix: \(Prefix); Command: \(Command); Params: \(Params); LongParam: \(LongParam)")
        }
    }
}

class BotIRCHandler: BotIRCHandlerBase, IRCHandlerProtocol {
    var BotBusy: Bool = false
    var EcoTimer: NSTimer?
    var LoopTimer: NSTimer?

    override func doLoop() {
        if !Loop {
            print("*** Loop halted ***")
            if EcoTimer != nil {
                EcoTimer!.invalidate()
                EcoTimer = nil
            }
            return
        }
        super.doLoop()
        LoopTimer = NSTimer.scheduledTimerWithTimeInterval((BotBusy ? 0.05 : 1), target: self, selector: #selector(IRCHandlerBase.doLoop), userInfo: nil, repeats: false)
        LoopTimer!.tolerance = (BotBusy ? 0.1 : 0.5)
    }

    override func doSend(Command: String, Params: [String], LongParam: String?) {
        print("C>S: Command: \(Command); Params: \(Params); LongParam: \(LongParam)")
        super.doSend(Command, Params: Params, LongParam: LongParam)
    }

    override func onReceive(Prefix: String?, Command: String, Params: [String], LongParam: String?) {
        if !BotBusy {
            print("*** Eco throttle inactive ***")
            BotBusy = true
            if EcoTimer != nil {
                EcoTimer!.invalidate()
            }
            EcoTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(BotIRCHandler.startThrottling), userInfo: nil, repeats: false)
            EcoTimer!.tolerance = 1
        }
        super.onReceive(Prefix, Command: Command, Params: Params, LongParam: LongParam)
    }

    // non-protocol functions
    func startThrottling() {
        print("*** Eco throttle active ***")
        BotBusy = false
    }

    func startLoop() { doLoop() }
}

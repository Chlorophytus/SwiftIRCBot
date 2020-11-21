import Foundation

protocol BotIRCSecurePluginProtocol: BotIRCPluginProtocol { }

protocol BotIRCSecureDumbPluginProtocol: BotIRCSecurePluginProtocol {
    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, Prefix: String?, Command: String, Params: [String], LongParam: String?)
}

protocol BotIRCSecureAuthPluginProtocol: BotIRCSecurePluginProtocol {
    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String)
}

protocol BotIRCSecureSmartPluginProtocol: BotIRCCommandPluginProtocol, BotIRCSecurePluginProtocol {
    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String])
}

class BotIRCSecureSmartPluginPing: BotIRCSecureSmartPluginProtocol {
    static let CommandName = "ping"
    static let Identity = "ping"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): \"ping\" takes no arguments.")
            return
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Pong")
    }
}

class BotIRCSecureSmartPluginWhoAmI: BotIRCSecureSmartPluginProtocol {
    static let CommandName = "whoami"
    static let Identity = "whoami"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): \"whoami\" takes no arguments.")
            return
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Your NickServ account is \(Account)")
    }
}

class BotIRCSecureSmartPluginHelp: BotIRCSecureSmartPluginProtocol {
    static let Identity = "help"
    static let CommandName = "help"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): \"help\" takes no arguments.")
            return
        }

        var names = [String]()
        for plugin in Plugin.LoadedPlugins {
            if let handler = plugin as? BotIRCSecureSmartPluginProtocol {
                names.append(handler.dynamicType.CommandName)
            }
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Available commands - \(names.joinWithSeparator(", "))")
    }
}

class BotIRCSecureSmartPluginReloadWhitelist: BotIRCSecureSmartPluginProtocol {
    static let Identity = "reload_whitelist"
    static let CommandName = "reload_whitelist"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String]) {
        if Account != Target.Owner {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): You are not authorized to run this command.")
            return
        }

        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): \"reload_whitelist\" takes no arguments.")
            return
        }

        BotIRCSecureAuthPluginWhitelist.File.setDirty()
        if let data = BotIRCSecureAuthPluginWhitelist.File.Data {
            var whitelist = data.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
            for i in 0 ... whitelist.count - 1 {
                if whitelist[i].isEmpty { whitelist.removeAtIndex(i) }
            }

            BotIRCSecureAuthPluginWhitelist.Whitelist = whitelist
        }
        else {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Error reloading whitelist.")
            return
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Reloaded whitelist.")
    }
}

class BotIRCSecureSmartPluginReloadWisdom: BotIRCSecureSmartPluginProtocol {
    static let Identity = "reload_wisdom"
    static let CommandName = "reload_wisdom"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String]) {
        if Account != Target.Owner {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): You are not authorized to run this command.")
            return
        }

        if Params.count != 0 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): \"reload_wisdom\" takes no arguments.")
            return
        }

        BotIRCSmartPluginWisdom.File.setDirty()
        if let data = BotIRCSmartPluginWisdom.File.Data {
            var wisdom = data.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
            for i in 0 ... wisdom.count - 1 {
                if wisdom[i].isEmpty { wisdom.removeAtIndex(i) }
            }

            BotIRCSmartPluginWisdom.Wisdom = wisdom
        }
        else {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Error reloading wisdom.")
            return
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Reloaded wisdom.")
    }
}

class BotIRCSecureSmartPluginPrivchg: BotIRCSecureSmartPluginProtocol {
    static let Identity = "privchg"
    static let CommandName = "privchg"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String, Host: String, Source: String, Params: [String]) {
        if Account != Target.Owner {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): You are not authorized to run this command.")
            return
        }

        if Params.count != 1 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): \"privchg\" takes 1 arguments.")
            return
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (SecureMod): Reloading privilege for user \(Params[0]).")
        Plugin.authenticate(Target, User: Params[0])
    }
}

class BotIRCSecureAuthPluginWhitelist: BotIRCSecureAuthPluginProtocol {
    static let Identity = "whitelist"
    static let File = BotIRCFileWrapper(Location: Identity)
    static var Whitelist = [String]()

    init?() {
        if let data = self.dynamicType.File.Data {
            var whitelist = data.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
            for i in 0 ... whitelist.count - 1 {
                if whitelist[i].isEmpty { whitelist.removeAtIndex(i) }
            }

            self.dynamicType.Whitelist = whitelist
        }
        else {
            print("(SecureMod) Error loading whitelist plugin: Data failure")
            return nil
        }
    }

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCDumbPluginSecureFeatures, Account: String, User: String) {
        if self.dynamicType.Whitelist.contains(Account) {
            Target.doSend("PRIVMSG", Params: ["ChanServ"], LongParam: "VOICE \(Target.Channel) \(User)")
        }
        else {
            Target.doSend("PRIVMSG", Params: ["ChanServ"], LongParam: "DEVOICE \(Target.Channel) \(User)")
        }
    }
}

class BotIRCDumbPluginSecureFeatures: BotIRCParentPluginGroupProtocol, BotIRCDumbPluginProtocol {
    static let Identity = "secure_features"
    static var SecureUsers = [String: String]()

    typealias Plugin = BotIRCSecurePluginProtocol
    static var Plugins = [BotIRCSecurePluginProtocol]()
    var LoadedPlugins = [BotIRCSecurePluginProtocol]()

    init(DesiredPlugins: [String]) {
        for ident in DesiredPlugins {
            for plugin in BotIRCDumbPluginSecureFeatures.Plugins {
                if plugin.dynamicType.Identity == ident {
                    LoadedPlugins.append(plugin)
                }
            }
        }
    }

    func authenticate(Target: BotIRCHandlerBase, User: String) {
        print("S>C (SecureMod): Initiating authentication request (Nick: \(User))")
        Target.doSend("PRIVMSG", Params: ["NickServ"], LongParam: "ACC \(User) *")
    }

    func onEvent(Target: BotIRCHandlerBase, Prefix: String?, Command: String, Params: [String], LongParam: String?) {
        if let Existent = Prefix {
            if Existent.containsString("!") {
                let user = Existent[Existent.startIndex ... Existent.rangeOfString("!")!.startIndex.predecessor()]
                let host = Existent[Existent.rangeOfString("!")!.startIndex.successor() ... Existent.endIndex.predecessor()]
                switch Command {
                case "JOIN":
                    print("S>C (SecureMod): User joined (Nick: \(user))")
                    self.authenticate(Target, User: user)
                case "PART":
                    print("S>C (SecureMod): User parted (Nick: \(user); Account: \(self.dynamicType.SecureUsers[user]))")
                    if let userIndex = self.dynamicType.SecureUsers.indexForKey(user) {
                        self.dynamicType.SecureUsers.removeAtIndex(userIndex)
                    }
                case "NOTICE":
                    if user == "NickServ" {
                        let components = LongParam!.componentsSeparatedByString(" ")
                        if components.count == 6 && components[4] == "3" {
                            let realuser = components[0]
                            let account = components[2]
                            print("S>C (SecureMod): Completing authentication (Nick: \(realuser); Account: \(account))")
                            self.dynamicType.SecureUsers[realuser] = account
                            for plugin in LoadedPlugins {
                                if let handler = plugin as? BotIRCSecureAuthPluginProtocol {
                                    handler.onEvent(Target, Plugin: self, Account: account, User: realuser)
                                }
                            }
                        }
                    }
                case "PRIVMSG":
                    let sectrig = "s_\(Target.Trigger)"
                    if LongParam!.hasPrefix(sectrig) {
                        if LongParam! == Target.Trigger {
                            Target.doSend("PRIVMSG", Params: Params, LongParam: "\(user) (SecureMod): You did not a secure command")
                        }
                        else {
                            let Source = ((Params[0] == Target.GenericCredentials.1) ? user : Params[0])
                            let command = LongParam![LongParam!.rangeOfString(sectrig)!.endIndex ... LongParam!.endIndex.predecessor()].componentsSeparatedByString(" ")
                            let commandslice = Array(command[1 ..< command.count])
                            var found = false
                            for plugin in LoadedPlugins {
                                if let handler = plugin as? BotIRCSecureSmartPluginProtocol {
                                    if handler.dynamicType.CommandName == command[0] {
                                        if let account = self.dynamicType.SecureUsers[user] {
                                            handler.onEvent(Target, Plugin: self, Account: account, User: user, Host: host, Source: Source, Params: commandslice)
                                        }
                                        else {
                                            Target.doSend("PRIVMSG", Params: Params, LongParam: "\(user) (SecureMod): You must authenticate with NickServ before running secure commands")
                                        }
                                        found = true
                                    }
                                }
                            }
                            if !found {
                                Target.doSend("PRIVMSG", Params: Params, LongParam: "\(user) (SecureMod): Command not found")
                            }
                        }
                    }
                default: break
                }
                if let account = self.dynamicType.SecureUsers[user] {
                    for plugin in LoadedPlugins {
                        if let handler = plugin as? BotIRCSecureDumbPluginProtocol {
                            handler.onEvent(Target, Plugin: self, Account: account, Prefix: Prefix, Command: Command, Params: Params, LongParam: LongParam)
                        }
                    }
                }
            }
            else {
                switch Command {
                case "353":
                    let users = LongParam!.componentsSeparatedByString(" ")
                    var realUsers = [String]()
                    for user in users {
                        if user == "@ChanServ" || user == Params[0] { continue }
                        switch user[user.startIndex] {
                        case "+": realUsers.append(user.stringByReplacingOccurrencesOfString("+", withString: ""))
                        case "@": realUsers.append(user.stringByReplacingOccurrencesOfString("@", withString: ""))
                        default: realUsers.append(user)
                        }
                    }
                    for realUser in realUsers { self.authenticate(Target, User: realUser) }
                default: break
                }
            }
        }
    }
}

func SecureMod_Load(Plugins: [String]) {
    BotIRCDumbPluginSecureFeatures.Plugins = [
        BotIRCSecureSmartPluginHelp(),
        BotIRCSecureSmartPluginPing(),
        BotIRCSecureSmartPluginWhoAmI(),
        BotIRCSecureSmartPluginReloadWisdom(),
        BotIRCSecureSmartPluginReloadWhitelist(),
        BotIRCSecureSmartPluginPrivchg()
    ]
    if let plugin = BotIRCSecureAuthPluginWhitelist() { BotIRCDumbPluginSecureFeatures.Plugins.append(plugin) }

    let SecureMod = BotIRCDumbPluginSecureFeatures(DesiredPlugins: Plugins)
    SwiftIRCBot.Variables.Plugins.append(SecureMod)
}

import Foundation

protocol BotIRCDBPluginProtocol: BotIRCPluginProtocol { }

protocol BotIRCDBJoinPluginProtocol: BotIRCDBPluginProtocol {
    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String)
}

protocol BotIRCDBSmartPluginProtocol: BotIRCDBPluginProtocol {
    static var SubCommandName: String { get }

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String])
}

class BotIRCDBPluginGreet: BotIRCDBJoinPluginProtocol {
    static let Identity = "greet"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String) {
        if let greeting = BotIRCPluginDBFeatures.Greetings[User] {
            Target.doSend("PRIVMSG", Params: [Target.Channel], LongParam: "\(User) (DBMod): \(greeting)")
        }
    }
}

class BotIRCDBPluginGet: BotIRCDBSmartPluginProtocol {
    static let Identity = "get"
    static let SubCommandName = "get"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 1 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \"get\" takes 1 argument.")
            return
        }

        if BotIRCPluginDBFeatures.Tags[Params[0]] == nil {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Tag doesn't exist or something went wrong beforehand - \(Params[0])")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \(Params[0]) -> \(BotIRCPluginDBFeatures.Tags[Params[0]]!) ")
            Target.GTHits += -1
        })
    }
}

class BotIRCDBPluginSet: BotIRCDBSmartPluginProtocol {
    static let Identity = "set"
    static let SubCommandName = "set"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count < 2 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \"set\" takes 2+ arguments.")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            let data = Params[1 ..< Params.count].joinWithSeparator(" ")
            BotIRCPluginDBFeatures.Tags[Params[0]] = data

            if BotIRCPluginDBFeatures.Tags[Params[0]] == data {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Tag set - \(Params[0]) -> \(data)")
            }
            else {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Something went wrong while setting tag - \(Params[0])")
            }
            Target.GTHits += -1
        })
    }
}

class BotIRCDBPluginDrop: BotIRCDBSmartPluginProtocol {
    static let Identity = "drop"
    static let SubCommandName = "drop"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 1 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \"drop\" takes 1 argument.")
            return
        }

        if BotIRCPluginDBFeatures.Tags[Params[0]] == nil {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Tag doesn't exist or something went wrong beforehand - \(Params[0])")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            BotIRCPluginDBFeatures.Tags[Params[0]] = nil

            if BotIRCPluginDBFeatures.Tags[Params[0]] == nil {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Tag dropped - \(Params[0])")
            }
            else {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Something went wrong while dropping tag - \(Params[0])")
            }
            Target.GTHits += -1
        })
    }
}

class BotIRCDBPluginGetGreeting: BotIRCDBSmartPluginProtocol {
    static let Identity = "gget"
    static let SubCommandName = "gget"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 1 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \"gget\" takes 1 argument.")
            return
        }

        if BotIRCPluginDBFeatures.Greetings[Params[0]] == nil {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Greeting doesn't exist or something went wrong beforehand (for user \(Params[0]))")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Greeting (for user \(Params[0])) -> \(BotIRCPluginDBFeatures.Greetings[Params[0]]!)")
            Target.GTHits += -1
        })
    }
}

class BotIRCDBPluginSetGreeting: BotIRCDBSmartPluginProtocol {
    static let Identity = "gset"
    static let SubCommandName = "gset"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count < 2 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \"gset\" takes 2+ arguments.")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            let data = Params[1 ..< Params.count].joinWithSeparator(" ")
            BotIRCPluginDBFeatures.Greetings[Params[0]] = data

            if BotIRCPluginDBFeatures.Greetings[Params[0]] == data {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Greeting set (for user \(Params[0])) -> \(data)")
            }
            else {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Something went wrong while setting greeting (for user \(Params[0]))")
            }
            Target.GTHits += -1
        })
    }
}

class BotIRCDBPluginDropGreeting: BotIRCDBSmartPluginProtocol {
    static let Identity = "gdrop"
    static let SubCommandName = "gdrop"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginDBFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 1 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): \"gdrop\" takes 1 argument.")
            return
        }

        if BotIRCPluginDBFeatures.Greetings[Params[0]] == nil {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Greeting doesn't exist or something went wrong beforehand (for user \(Params[0]))")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            BotIRCPluginDBFeatures.Greetings[Params[0]] = nil

            if BotIRCPluginDBFeatures.Greetings[Params[0]] == nil {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Greeting dropped (for user \(Params[0]))")
            }
            else {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Something went wrong while dropping greeting (for user \(Params[0]))")
            }
            Target.GTHits += -1
        })
    }
}

class BotIRCPluginDBFeatures: BotIRCParentPluginGroupProtocol, BotIRCSmartPluginProtocol, BotIRCDumbPluginProtocol {
    static let Identity = "db_features"
    static let CommandName = "db"
    static let Tags = BotIRCDatabaseWrapper(Location: "db_tags")
    static let Greetings = BotIRCDatabaseWrapper(Location: "db_greetings")

    typealias Plugin = BotIRCDBPluginProtocol
    static var Plugins = [BotIRCDBPluginProtocol]()
    var LoadedPlugins = [BotIRCDBPluginProtocol]()

    init(DesiredPlugins: [String]) {
        for ident in DesiredPlugins {
            for plugin in BotIRCPluginDBFeatures.Plugins {
                if plugin.dynamicType.Identity == ident {
                    LoadedPlugins.append(plugin)
                }
            }
        }
    }

    func onEvent(Target: BotIRCHandlerBase, Prefix: String?, Command: String, Params: [String], LongParam: String?) {
        if let Existent = Prefix {
            if Existent.containsString("!") {
                let user = Existent[Existent.startIndex ... Existent.rangeOfString("!")!.startIndex.predecessor()]
                switch Command {
                case "JOIN":
                    print("S>C (DBMod): User joined (Nick: \(user))")
                    for rawPlugin in LoadedPlugins {
                        if let plugin = rawPlugin as? BotIRCDBJoinPluginProtocol {
                            plugin.onEvent(Target, Plugin: self, User: user)
                        }
                    }
                default: break
                }
            }
        }
    }

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count < 1 {
            var plugins = [String]()
            for rawPlugin in LoadedPlugins {
                if let plugin = rawPlugin as? BotIRCDBSmartPluginProtocol {
                    plugins.append(plugin.dynamicType.SubCommandName)
                }
            }

            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Available subcommands: \(plugins.joinWithSeparator(", "))")
            return
        }

        let Command = Params[0]
        for rawPlugin in LoadedPlugins {
            if let plugin = rawPlugin as? BotIRCDBSmartPluginProtocol {
                if Command == plugin.dynamicType.SubCommandName {
                    plugin.onEvent(Target, Plugin: self, User: User, Host: Host, Source: Source, Params: [String](Params[1 ..< Params.count]))
                    return
                }
            }
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (DBMod): Subcommand not found")
    }
}

func DBMod_Load(Plugins: [String]) {
    BotIRCPluginDBFeatures.Plugins = [
        BotIRCDBPluginGet(),
        BotIRCDBPluginSet(),
        BotIRCDBPluginDrop(),
        BotIRCDBPluginGetGreeting(),
        BotIRCDBPluginSetGreeting(),
        BotIRCDBPluginDropGreeting(),
        BotIRCDBPluginGreet()
    ]

    let DBMod = BotIRCPluginDBFeatures(DesiredPlugins: Plugins)
    SwiftIRCBot.Variables.Plugins.append(DBMod)
}

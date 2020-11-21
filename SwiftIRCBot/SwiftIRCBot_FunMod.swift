import Foundation

protocol BotIRCFunPluginProtocol: BotIRCPluginProtocol {
    static var SubCommandName: String { get }

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginFunFeatures, User: String, Host: String, Source: String, Params: [String])
}

class BotIRCFunPluginDice: BotIRCFunPluginProtocol {
    static let Identity = "dice"
    static let SubCommandName = "dice"

    func onEvent(Target: BotIRCHandlerBase, Plugin: BotIRCPluginFunFeatures, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count != 2 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): \"dice\" takes 2 arguments.")
            return
        }

        if let numberOfDice = UInt32(Params[0]) {
            if let numberOfSides = UInt32(Params[1]) {
                if numberOfDice < 1 || numberOfDice > 16 {
                    Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Dice number out of range. Try a number from 1 to 16.")
                    return
                }
                if numberOfSides < 2 || numberOfSides > 256 {
                    Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Dice sides out of range. Try a number from 2 to 256.")
                    return
                }
                var dice = [UInt32]()
                for _ in 1 ... numberOfDice {
                    dice.append(arc4random_uniform(numberOfSides) + 1)
                }

                let sum = dice.reduce(0, combine: { $0 + $1 })

                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Dice results - Thrown: \(dice); Sum: \(sum); Average: \(Double(sum) / Double(numberOfDice))")
            }
            else {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Invalid syntax. \"\(Target.Trigger)fun dice numberOfDice numberOfSides\"")
                return
            }
        }
        else {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Invalid syntax. \"\(Target.Trigger)fun dice numberOfDice numberOfSides\"")
            return
        }
    }
}

class BotIRCPluginFunFeatures: BotIRCParentPluginGroupProtocol, BotIRCSmartPluginProtocol {
    static let Identity = "fun_features"
    static let CommandName = "fun"

    typealias Plugin = BotIRCFunPluginProtocol
    static var Plugins = [BotIRCFunPluginProtocol]()
    var LoadedPlugins = [BotIRCFunPluginProtocol]()

    init(DesiredPlugins: [String]) {
        for ident in DesiredPlugins {
            for plugin in BotIRCPluginFunFeatures.Plugins {
                if plugin.dynamicType.Identity == ident {
                    LoadedPlugins.append(plugin)
                }
            }
        }
    }

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count < 1 {
            var plugins = [String]()
            for plugin in LoadedPlugins {
                plugins.append(plugin.dynamicType.SubCommandName)
            }

            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Available subcommands: \(plugins.joinWithSeparator(", "))")
            return
        }

        let Command = Params[0]
        for plugin in LoadedPlugins {
            if Command == plugin.dynamicType.SubCommandName {
                plugin.onEvent(Target, Plugin: self, User: User, Host: Host, Source: Source, Params: [String](Params[1 ..< Params.count]))
                return
            }
        }

        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (FunMod): Subcommand not found")
    }
}

func FunMod_Load(Plugins: [String]) {
    BotIRCPluginFunFeatures.Plugins = [
        BotIRCFunPluginDice()
    ]

    let FunMod = BotIRCPluginFunFeatures(DesiredPlugins: Plugins)
    SwiftIRCBot.Variables.Plugins.append(FunMod)
}

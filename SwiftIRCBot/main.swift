import Foundation

do {
    try SwiftIRCBot.Variables.FileManager.createDirectoryAtPath(SwiftIRCBot.Variables.Location, withIntermediateDirectories: true, attributes: nil)
}
catch {
    fatalError("Error while creating your .swiftircbot directory: \(error)")
}

func set_module_line() {
    if Process.arguments.contains("--set-module-line") {
        print("CONFIG: Please enter the bot's new module line.")
        print("Stored module line: \(SwiftIRCBot.Variables.ConfigData.1.module_load_line)")

        SwiftIRCBot.Variables.ConfigData.1.module_load_line = readLine(stripNewline: true)!

        do {
            try SwiftIRCBot.Variables.ConfigData.0.managedObjectContext.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
        exit(EXIT_SUCCESS)
    }
}

if Process.arguments.contains("--configure") {
    print("CONFIG: We will now configure the IRC bot.")
    print("CONFIG: Please enter your server")
    SwiftIRCBot.Variables.ConfigData.1.host = readLine(stripNewline: true)!
    print("CONFIG: Please enter your server's port (0-32768)")
    SwiftIRCBot.Variables.ConfigData.1.port = Int16(readLine(stripNewline: true)!)!

    while true {
        print("CONFIG: Are we using SSL? (yes/no)")
        let val = readLine(stripNewline: true)!
        switch val {
        case "yes":
            SwiftIRCBot.Variables.ConfigData.1.use_ssl = true
            break
        case "no":
            SwiftIRCBot.Variables.ConfigData.1.use_ssl = false
            break
        default:
            print("CONFIG: Please enter a yes or no value.")
            continue
        }
        break
    }

    while true {
        print("CONFIG: Are we using SASL? (yes/no)")
        let val = readLine(stripNewline: true)!
        switch val {
        case "yes":
            SwiftIRCBot.Variables.ConfigData.1.use_sasl = true
            print("CONFIG: Please enter your SASL username")
            SwiftIRCBot.Variables.ConfigData.1.sasl_username = readLine(stripNewline: true)!
            print("CONFIG: Please enter your SASL password")
            SwiftIRCBot.Variables.ConfigData.1.sasl_password = readLine(stripNewline: true)!
            break
        case "no":
            SwiftIRCBot.Variables.ConfigData.1.use_sasl = false
            break
        default:
            print("CONFIG: Please enter a yes or no value.")
            continue
        }
        break
    }

    print("CONFIG: Please enter your bot nickname")
    SwiftIRCBot.Variables.ConfigData.1.nickname = readLine(stripNewline: true)!
    print("CONFIG: Please enter your bot ident (appears in the hostmask)")
    SwiftIRCBot.Variables.ConfigData.1.ident = readLine(stripNewline: true)!
    while true {
        print("CONFIG: Are you using a server password, or is your bot going to authenticate with NickServ through the server password? (yes/no)")
        print("CONFIG: You will usually say yes unless you know your bot doesn't have a NickServ password or you're connecting to Rizon.")
        let val = readLine(stripNewline: true)!
        switch val {
        case "yes":
            print("CONFIG: Please enter the password")
            SwiftIRCBot.Variables.ConfigData.1.password = readLine(stripNewline: true)!
            break
        case "no":
            SwiftIRCBot.Variables.ConfigData.1.password = nil
            break
        default:
            print("CONFIG: Please enter a yes or no value.")
            continue
        }
        break
    }
    while true {
        print("CONFIG: Declare your bot as invisible? (yes/no)")
        let val = readLine(stripNewline: true)!
        switch val {
        case "yes":
            SwiftIRCBot.Variables.ConfigData.1.invisible = true
            break
        case "no":
            SwiftIRCBot.Variables.ConfigData.1.invisible = false
            break
        default:
            print("CONFIG: Please enter a yes or no value.")
            continue
        }
        break
    }

    print("CONFIG: Please enter the bot's whois realname")
    SwiftIRCBot.Variables.ConfigData.1.real_name = readLine(stripNewline: true)!
    print("CONFIG: Please enter the bot owner's NickServ account name.")
    SwiftIRCBot.Variables.ConfigData.1.owner_account = readLine(stripNewline: true)!

    print("CONFIG: Please enter the bot's trigger.")
    SwiftIRCBot.Variables.ConfigData.1.trigger = readLine(stripNewline: true)!

    set_module_line()
    do {
        try SwiftIRCBot.Variables.ConfigData.0.managedObjectContext.save()
    } catch {
        fatalError("Failure to save context: \(error)")
    }
    exit(EXIT_SUCCESS)
}

set_module_line()

SwiftIRCBot.Variables.Plugins = [
    BotIRCDumbPluginCore(),
    BotIRCSmartPluginDump(),
    BotIRCSmartPluginHelp(),
    BotIRCSmartPluginPing(),
    BotIRCSmartPluginVersion()
]

if let plugin = BotIRCSmartPluginWisdom() { SwiftIRCBot.Variables.Plugins.append(plugin) }
if let plugin = BotIRCSmartPluginPython() { SwiftIRCBot.Variables.Plugins.append(plugin) }

let queue = dispatch_queue_create("com.metivier.roland.IRCHandler", DISPATCH_QUEUE_SERIAL)

let bot = BotIRCHandler(OtherLoad: [("secure_features", SecureMod_Load), ("db_features", DBMod_Load), ("fun_features", FunMod_Load)])
var loop = true
dispatch_async(queue, {
    bot.startLoop()
    NSRunLoop.currentRunLoop().run()
})
while loop {
    print("-> Ready for input")
    let line = readLine(stripNewline: true)
    if line == nil {
        continue
    }
    switch line! {
    case "quit":
        loop = false
        break
    case "say":
        print("--> Target:")
        let channel = readLine(stripNewline: true)
        print("--> Message:")
        let message = readLine(stripNewline: true)
        if channel == nil {
            continue
        }
        bot.doSend("PRIVMSG", Params: [channel!], LongParam: message)
    case "do":
        print("--> Target:")
        let channel = readLine(stripNewline: true)
        print("--> Action:")
        var message = readLine(stripNewline: true)
        if channel == nil {
            continue
        }
        if message == nil { message! = "" }
        bot.doSend("PRIVMSG", Params: [channel!], LongParam: "\u{1}ACTION \(message!)\u{1}")
    default: print("--> Unknown command")
    }
}

bot.doSend("QUIT", Params: [], LongParam: "SwiftIRCBot")

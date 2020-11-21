import Foundation

class BotIRCSmartPluginPython: BotIRCSmartPluginProtocol {
    static let CommandName = "py"
    static let Identity = "py"
    static let Directory = "\(SwiftIRCBot.Variables.Location)/py_modules"

    init?() {
        if let name = Process.arguments[0].cStringUsingEncoding(NSUTF32StringEncoding) {
            var programName = name.map({ Int32($0) })

            let env = getenv("PYTHONPATH")

            if env != nil {
                setenv("PYTHONPATH", "\(BotIRCSmartPluginPython.Directory):\(String(env))", 1)
            } else {
                setenv("PYTHONPATH", "\(BotIRCSmartPluginPython.Directory)", 1)
            }

            Py_SetProgramName(&programName)
            Py_Initialize()
        } else {
            print("Error loading PyMod: Failed to get C String for process argument 0")
            return nil
        }
    }

    deinit {
        Py_Finalize()
    }

    func onEvent(Target: BotIRCHandlerBase, User: String, Host: String, Source: String, Params: [String]) {
        if Params.count < 1 {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): \"py\" takes 1+ arguments.")
            return
        }

        if Target.GTHits > SwiftIRCBot.Variables.MaxGTHits {
            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Too many jobs at once. Please wait a while.")
            return
        }

        Target.GTHits += 1
        dispatch_async(Target.GTQueue, {
            if SwiftIRCBot.Variables.FileManager.fileExistsAtPath("\(BotIRCSmartPluginPython.Directory)/\(Params[0]).py") {
                if let rawFile = Params[0].cStringUsingEncoding(NSUTF8StringEncoding) {
                    let rawFile8 = rawFile.map({ Int8($0) })
                    let string8 = PyUnicode_DecodeFSDefault(rawFile8)
                    let module = PyImport_Import(string8)
                    Py_DecRef(string8)

                    if module != nil {
                        // do stuff
                        let function = PyObject_GetAttrString(module, "on_event")
                        if function != nil && PyCallable_Check(function) == 1 {
                            let args = PyTuple_New(3)

                            if let string = User.cStringUsingEncoding(NSUTF8StringEncoding) {
                                let string8 = string.map({ Int8($0) })
                                let value = PyBytes_FromString(string8)
                                PyTuple_SetItem(args, 0, value)
                            } else {
                                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Tuple bridge failure on \"User\" variable.")
                                return
                            }

                            if let string = Host.cStringUsingEncoding(NSUTF8StringEncoding) {
                                let string8 = string.map({ Int8($0) })
                                let value = PyBytes_FromString(string8)
                                PyTuple_SetItem(args, 1, value)
                            } else {
                                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Tuple bridge failure on \"Host\" variable.")
                                return
                            }

                            let value = PyList_New(0)
                            for string in Params[1..<Params.count] {
                                if let rawString = string.cStringUsingEncoding(NSUTF8StringEncoding) {
                                    let string8 = rawString.map({ Int8($0) })
                                    PyList_Append(value, PyBytes_FromString(string8))
                                } else {
                                    Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): List bridge failure inside args variable.")
                                    return
                                }
                            }
                            PyTuple_SetItem(args, 2, value)

                            let result = PyObject_CallObject(function, args)
                            Py_DecRef(args)

                            if result != nil {
                                let str = String(UTF8String: UnsafePointer<CChar>(PyBytes_AsString(result)))
                                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod: \(Params[0])): \(str!)")
                                Py_DecRef(result)
                            } else {
                                PyErr_Print()
                                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Function call bridge failure.")
                            }
                        } else {
                            if PyErr_Occurred() != nil {
                                PyErr_Print()
                            }
                            Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Function bridge failure.")
                        }
                        Py_DecRef(function)
                        Py_DecRef(module)
                    } else {
                        PyErr_Print()
                        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Module bridge failure.")
                    }
                } else {
                    Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Failed to get bridge string for file.")
                }
            } else {
                Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Plugin not found.")
            }
            Target.GTHits -= 1
        })
        Target.doSend("PRIVMSG", Params: [Source], LongParam: "\(User) (PyMod): Doing Python job, this may take a while...")
    }
}
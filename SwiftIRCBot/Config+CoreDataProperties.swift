import Foundation
import CoreData

extension Config {

    @NSManaged var host: String?
    @NSManaged var trigger: String?
    @NSManaged var port: Int16
    @NSManaged var use_ssl: Bool
    @NSManaged var sasl_username: String?
    @NSManaged var sasl_password: String?
    @NSManaged var use_sasl: Bool
    @NSManaged var ident: String?
    @NSManaged var nickname: String?
    @NSManaged var real_name: String?
    @NSManaged var password: String?
    @NSManaged var owner_account: String?
    @NSManaged var module_load_line: String?
    @NSManaged var invisible: Bool

}

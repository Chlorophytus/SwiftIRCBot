import Foundation
import CoreData

class DataController: NSObject {
    var managedObjectContext: NSManagedObjectContext
    let theConfig: Config

    override init() {
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = NSBundle.mainBundle().URLForResource("Config", withExtension: "momd") else {
            fatalError("Error loading model from bundle")
        }
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let storeURL = NSURL(fileURLWithPath: SwiftIRCBot.Variables.Location).URLByAppendingPathComponent("config.xml")
            do {
                try psc.addPersistentStoreWithType(NSXMLStoreType, configuration: nil, URL: storeURL, options: nil)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }

        let moc = managedObjectContext
        let fetch = NSFetchRequest(entityName: "Config")
        fetch.returnsObjectsAsFaults = false

        do {
            guard let config = try moc.executeFetchRequest(fetch) as? [Config] else {
                fatalError("Error fetching config.")
            }

            if config.count != 0 {
                self.theConfig = config[0]
            } else {
                self.theConfig = NSEntityDescription.insertNewObjectForEntityForName("Config", inManagedObjectContext: self.managedObjectContext) as! Config
            }
        } catch {
            fatalError("Failed to fetch: \(error)")
        }

        super.init()
    }
}

class Config: NSManagedObject {
    static func factory() -> (DataController, Config) {
        let theController = DataController()
        return (theController, theController.theConfig)
    }
}
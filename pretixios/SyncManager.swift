//
//  SyncManager.swift
//  pretixios
//
//  Created by Marc Delling on 10.09.17.
//  Copyright © 2017 Silpion IT-Solutions GmbH. All rights reserved.
//

import UIKit
import CoreData

class SyncManager: NSObject {
    
    static let sharedInstance = SyncManager()
    
    public private(set) var backgroundContext: NSManagedObjectContext!
    public private(set) var viewContext: NSManagedObjectContext!
    public private(set) var managedObjectModel: NSManagedObjectModel!
    
    private let persistentContainer = NSPersistentContainer(name: "PretixModel")
    private var syncState = [String:Syncstate]()
    
    private override init() {
        super.init()
        setup()
    }
    
    private func setup() {
        self.persistentContainer.loadPersistentStores { (persistentStoreDescription, error) in
            if let error = error {
                print("Unable to Load Persistent Store")
                print("\(error), \(error.localizedDescription)")
                self.deleteDatabase()
            } else {
                self.backgroundContext = self.persistentContainer.newBackgroundContext()
                self.viewContext = self.persistentContainer.viewContext
                self.managedObjectModel = self.persistentContainer.managedObjectModel
                self.syncState.removeAll()
                let fetchSyncstate: NSFetchRequest<Syncstate> = Syncstate.fetchRequest()
                do {
                    let results = try self.backgroundContext.fetch(fetchSyncstate)
                    for result in results {
                        self.syncState[result.path] = result
                        if let last = result.lastsync {
                            print("Last sync for \(result.path) was \(last)")
                        } else {
                            print("Last sync for \(result.path) is unknown")
                        }
                    }
                } catch {
                    print("Fetch error: \(error) description: \(error.localizedDescription)")
                }
                print("SyncManager ready.")
            }
        }
    }
    
    public func checkDefaultCheckinList() {
        
        var checkinList = UserDefaults.standard.value(forKey: "pretix_checkin_list") as? Int32
        
        let fetchRequest: NSFetchRequest<Checkinlist> = Checkinlist.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        
        do {
            let results = try self.backgroundContext.fetch(fetchRequest)
            if results.count > 0 {
                if checkinList != nil {
                    var found = false
                    for result in results {
                        if result.id == checkinList {
                            found = true
                        }
                    }
                    if !found {
                        checkinList = results.first?.id
                    }
                } else {
                    checkinList = results.first?.id
                }
                print("Set checkin list to \(checkinList!)")
                UserDefaults.standard.set(checkinList, forKey: "pretix_checkin_list")
            } else {
                UserDefaults.standard.removeObject(forKey: "pretix_checkin_list")
            }
        } catch {
            print("Fetch error: \(error.localizedDescription)")
        }
        
        UserDefaults.standard.synchronize()
    }

    public func deleteDatabase() {
        guard let storeURL = persistentContainer.persistentStoreCoordinator.persistentStores.first?.url else {
            return
        }
        do {
            viewContext.reset()
            backgroundContext.reset()
            try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            setup()
        } catch {
            print(error)
        }
    }
    
    public func performForegroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        self.viewContext.perform {
            block(self.viewContext)
        }
    }
    
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        self.persistentContainer.performBackgroundTask(block)
    }

    public func save() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                // FIXME upload changes
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror) in save(), \(nserror.userInfo)")
            }
        }
    }
    
    private func saveBackground() {
        if backgroundContext.hasChanges {
            do {
                try backgroundContext.save()
                NotificationCenter.default.post(name: Notification.Name("syncDone"), object: nil)
            } catch {
                fatalError("Unresolved error \(error) in saveBackground(), \(error.localizedDescription)")
            }
        }
    }
    
    public func saveBackgroundPartial(state: (Int, Int)) {
        if backgroundContext.hasChanges {
            do {
                try backgroundContext.save()
                NotificationCenter.default.post(name: Notification.Name("syncUpdate"), object: state)
                print("Partial save.")
            } catch {
                fatalError("Unresolved error \(error) in saveBackgroundIntermediate(), \(error.localizedDescription)")
            }
        }
    }
    
    public func lastSync(_ path: String) -> Date? {
        if let s = self.syncState[path] {
            return s.lastsync as Date?
        } else {
            let s = Syncstate(context: self.backgroundContext)
            s.path = path
            self.syncState[path] = s
            return nil
        }
    }
    
    public func success(_ path: String, code: Int) {
        if let s = self.syncState[path] {
            s.lastsync = Date()
            s.lasterror = Int16(code)
        } else {
            let s = Syncstate(context: self.backgroundContext)
            s.lastsync = Date()
            s.lasterror = Int16(code)
            s.path = path
            self.syncState[path] = s
        }
        saveBackground()
    }
    
    public func failure(_ path: String, code: Int) {
        print("Sync \(path) failed with \(code)")
        if let s = self.syncState[path] {
            s.lastsync = Date.distantPast
            s.lasterror = Int16(code)
            s.retry += 1
        } else {
            let s = Syncstate(context: self.backgroundContext)
            s.lastsync = Date.distantPast
            s.lasterror = Int16(code)
            s.retry += 1
            s.path = path
            self.syncState[path] = s
        }
        saveBackground()
    }
}

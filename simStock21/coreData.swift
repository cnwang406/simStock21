//
//  coreData.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
import CoreData

public class coreData {

    static var shared = coreData()

    private init() {} // Prevent clients from creating another instance.

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "simStock21")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
              fatalError("persistentContainer error \(storeDescription) \(error) \(error.userInfo)")
            }
        })
        return container
    }()

    lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    

    func getContext(_ context:NSManagedObjectContext?=nil) -> NSManagedObjectContext {
        if let context = context {
            return context
        } else {
            if Thread.current == Thread.main {
                return mainContext
            } else {
                let context = persistentContainer.newBackgroundContext()
//                context.automaticallyMergesChangesFromParent = true
                return context
            }
        }
    }

    func saveContext(_ context:NSManagedObjectContext?=nil) {   //每個線程結束的最後不再用到coredata物件時就save
        var theContext:NSManagedObjectContext
        if let context = context {
            theContext = context
        } else {
            theContext = mainContext
        }
        if theContext.hasChanges {
            do {
                try theContext.save()
            } catch {
              let nserror = error as NSError
              NSLog("saveContext error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    
    
    
    
    func fetchRequestStock (sId:[String]?=nil, sName:[String]?=nil, fetchLimit:Int?=nil) -> NSFetchRequest<Stock> {
        let fetchRequest = NSFetchRequest<Stock>(entityName: "Stock")
        var predicates:[NSPredicate] = []
        if let ids = sId {
            for sId in ids {
                let upperId = (sId == "t00" ? sId : sId.localizedUppercase)
                predicates.append(NSPredicate(format: "sId CONTAINS %@", upperId))
            }
        }
        if let names = sName {
            for sName in names {
                let upperName = sName.localizedUppercase
                predicates.append(NSPredicate(format: "sName CONTAINS %@", upperName))
            }
        }
        let grouping = NSPredicate(format: "group != %@", "")
        //合併以上條件為OR，可能都沒有就是ALL（list為nil時不是ALL,是tableview的預設查詢）
        if predicates.count > 0 {
            if predicates.count > 1 {
                predicates.append(grouping)
            }
            fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        } else {
            fetchRequest.predicate = grouping
        }
        //固定的排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "group", ascending: true), NSSortDescriptor(key: "sName", ascending: true)]

        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }

        return fetchRequest
    }

    func fetchStock (_ context:NSManagedObjectContext?=nil, sId:[String]?=nil, sName:[String]?=nil, fetchLimit:Int?=nil) -> (context:NSManagedObjectContext,stocks:[Stock]) {
        let theContext = getContext(context)
        let fetchRequest = fetchRequestStock(sId: sId, sName: sName, fetchLimit: fetchLimit)
        do {
            return try (theContext,theContext.fetch(fetchRequest))
        } catch {
            NSLog("\tfetch Stock error:\n\(error)")
            return (theContext,[])
        }
    }
    
    func newStock(_ context:NSManagedObjectContext?=nil, sId:String, sName:String, group:String?=nil) -> (context:NSManagedObjectContext,stock:Stock) {
        let theContext = getContext(context)
        let stock = Stock(context: theContext)
        stock.sId    = sId
        stock.sName  = sName
        if let group = group {
            stock.group = group
        }
        return (theContext,stock)
    }
    
    func updateStock(_ context:NSManagedObjectContext?=nil, sId:String, sName:String?=nil, group:String?=nil) -> (context:NSManagedObjectContext,stock:Stock?) {
        let theContext = getContext(context)
        let fetched = fetchStock(theContext, sId:[sId])
        if let stock = fetched.stocks.first {
            if let sName = sName {
                stock.sName = sName
            }
            if let group = group {
                stock.group = group
            }
            return (fetched.context,stock)
        } else {
            if let sName = sName {
                return newStock(theContext, sId: sId, sName: sName)
            } else {
                return newStock(theContext, sId: sId, sName: "")
            }
        }
    }

    
}


public class Stock: NSManagedObject {


}

extension Stock {

    @NSManaged public var group: String
    @NSManaged public var sId: String
    @NSManaged public var sName: String

}


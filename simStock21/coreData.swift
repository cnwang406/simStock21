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

    lazy private var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "simStock21")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
              fatalError("persistentContainer error \(storeDescription) \(error) \(error.userInfo)")
            }
        })
        return container
    }()

    lazy private var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    

    var context:NSManagedObjectContext {
        if Thread.current == Thread.main {
            return mainContext
        } else {
            let context = persistentContainer.newBackgroundContext()
            return context
        }
    }
    
}


public class Stock: NSManagedObject {
    
    static func fetchRequest (sId:[String]?=nil, sName:[String]?=nil, fetchLimit:Int?=nil) -> NSFetchRequest<Stock> {
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
        let grouping = NSPredicate(format: "group.gName != %@", "")
        //合併以上條件為OR，或不搜尋sId,sName時只查回股群清單（過濾掉不在股群內的上市股）
        if predicates.count > 0 {
            if predicates.count > 1 {
                predicates.append(grouping)
            }
            fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        } else {
            fetchRequest.predicate = grouping
        }
        //固定的排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sName", ascending: true)]

        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }

        return fetchRequest
    }

    static func fetch (_ context:NSManagedObjectContext, sId:[String]?=nil, sName:[String]?=nil, fetchLimit:Int?=nil) -> [Stock] {
        let fetchRequest = self.fetchRequest(sId: sId, sName: sName, fetchLimit: fetchLimit)
        return (try? context.fetch(fetchRequest)) ?? []
    }

        
    static func new(_ context:NSManagedObjectContext, sId:String, sName:String, gName:String?=nil) -> Stock {
        let stock = Stock(context: context)
        stock.sId    = sId
        stock.sName  = sName
        let pName = String(sName.first ?? Character(""))
        let prefix = StockPrefix.get(context, pName: pName)
        stock.prefix = prefix
        let group = StockGroup.get(context, gName: gName)
        stock.group = group
        return stock
    }
    
    static func update(_ context:NSManagedObjectContext, sId:String, sName:String?=nil, gName:String?=nil) {
        let stocks = fetch(context, sId:[sId])
        if stocks.count == 0 {
            if let sName = sName {
                let _ = new(context, sId: sId, sName: sName, gName: gName)
            }
        } else {
            for stock in stocks {
                if let sName = sName {
                    stock.sName = sName
                    let pName = String(sName.first ?? Character(""))
                    let prefix = StockPrefix.get(context, pName: pName)
                    stock.prefix = prefix
                }
                if let gName = gName {
                    let group = StockGroup.get(context, gName: gName)
                    stock.group = group
                }
            }
        }
    }

}

extension Stock {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Stock> {
        return NSFetchRequest<Stock>(entityName: "Stock")
    }


    @NSManaged public var sId: String
    @NSManaged public var sName: String
    @NSManaged public var group: StockGroup
    @NSManaged public var prefix: StockPrefix

}


@objc(StockGroup)
public class StockGroup: NSManagedObject {
    
    static func fetchRequest (gName:[String]?=nil, fetchLimit:Int?=nil) -> NSFetchRequest<StockGroup> {
        let fetchRequest = NSFetchRequest<StockGroup>(entityName: "StockGroup")
        var predicates:[NSPredicate] = []

        if let gnames = gName {
            for gname in gnames {
                predicates.append(NSPredicate(format: "gName CONTAINS %@", gname))
            }
        }
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        }

        //固定的排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "gName", ascending: true)]

        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }

        return fetchRequest
    }

    static func fetch (_ context:NSManagedObjectContext, gName:[String]?=nil, fetchLimit:Int?=nil) -> [StockGroup] {
        let fetchRequest = self.fetchRequest(gName: gName, fetchLimit: fetchLimit)
        return (try? context.fetch(fetchRequest)) ?? []
    }

    
    static func get(_ context:NSManagedObjectContext, gName:String?=nil) -> StockGroup {
        let gname = gName ?? ""
        let groups = StockGroup.fetch(context, gName: [gname])
        if let group = groups.first {
            return group
        } else {
            let group = StockGroup(context: context)
            group.gName  = gname
            return group
        }
    }
        
    static func update(_ context:NSManagedObjectContext, gName:String, gNameNew:String) {
        let group = fetch(context, gName:[gName])
        for (i,g) in group.enumerated() {
            if i == 0 {
                g.gName = gNameNew
            } else {
                context.delete(g)
            }
        }
    }

    

}

extension StockGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StockGroup> {
        return NSFetchRequest<StockGroup>(entityName: "StockGroup")
    }

    @NSManaged public var gName: String
    @NSManaged public var stocks: NSSet

}

// MARK: Generated accessors for stocks
extension StockGroup {

    @objc(addStocksObject:)
    @NSManaged public func addToStocks(_ value: Stock)

    @objc(removeStocksObject:)
    @NSManaged public func removeFromStocks(_ value: Stock)

    @objc(addStocks:)
    @NSManaged public func addToStocks(_ values: NSSet)

    @objc(removeStocks:)
    @NSManaged public func removeFromStocks(_ values: NSSet)

}

@objc(StockPrefix)
public class StockPrefix: NSManagedObject {
    
    static func fetchRequest (pName:[String]?=nil, fetchLimit:Int?=nil) -> NSFetchRequest<StockPrefix> {
        let fetchRequest = NSFetchRequest<StockPrefix>(entityName: "StockPrefix")
        var predicates:[NSPredicate] = []

        if let pnames = pName {
            for pname in pnames {
                predicates.append(NSPredicate(format: "pName CONTAINS %@", pname))
            }
        }
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        }
        
        //固定的排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "pName", ascending: true)]

        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }

        return fetchRequest
    }

    static func fetch (_ context:NSManagedObjectContext, pName:[String]?=nil, fetchLimit:Int?=nil) -> [StockPrefix] {
        let fetchRequest = self.fetchRequest(pName: pName, fetchLimit: fetchLimit)
        return (try? context.fetch(fetchRequest)) ?? []
    }

    
    static func get(_ context:NSManagedObjectContext, pName:String) -> StockPrefix {
        let prefix = StockPrefix.fetch(context, pName: [pName])
        if let prefix = prefix.first {
            return prefix
        } else {
            let prefix = StockPrefix(context: context)
            prefix.pName  = pName
            return prefix
        }
    }

    static func update(_ context:NSManagedObjectContext, pName:String, pNameNew:String) {
        let prefix = fetch(context, pName:[pName])
        for (i,p) in prefix.enumerated() {
            if i == 0 {
                p.pName = pNameNew
            } else {
                context.delete(p)
            }
        }
    }

}

extension StockPrefix {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StockPrefix> {
        return NSFetchRequest<StockPrefix>(entityName: "StockPrefix")
    }

    @NSManaged public var pName: String
    @NSManaged public var stocks: NSSet

}

// MARK: Generated accessors for stocks
extension StockPrefix {

    @objc(addStocksObject:)
    @NSManaged public func addToStocks(_ value: Stock)

    @objc(removeStocksObject:)
    @NSManaged public func removeFromStocks(_ value: Stock)

    @objc(addStocks:)
    @NSManaged public func addToStocks(_ values: NSSet)

    @objc(removeStocks:)
    @NSManaged public func removeFromStocks(_ values: NSSet)

}

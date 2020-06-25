//
//  Price.swift
//  simStock
//
//  Created by peiyu on 2016/9/8.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import Foundation
import CoreData

public class coreData {
    
    static let shared = coreData()

    private init() {} // Prevent clients from creating another instance.
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "simStock")
        
        //採預設名simStock.sqlite時，以下可省略
        let url:URL = {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let applicationDocumentsDirectory = urls[urls.count-1]
            return applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        }()
        let description = NSPersistentStoreDescription(url: url)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.isReadOnly = false
        container.persistentStoreDescriptions = [description]
        //採預設名simStock.sqlite時，以上可省略

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
        if let cx = context {
            return cx
        } else {
            if Thread.current == Thread.main {
                return mainContext
            } else {
                let cx = self.persistentContainer.newBackgroundContext()
                return cx
            }
        }
    }
    
    func saveContext(_ context:NSManagedObjectContext?=nil) {   //最好在每個線程結束的最後不再用到coredata物件時就save
        var theContext:NSManagedObjectContext
        if let cx = context {
            theContext = cx
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
    
    
    
    
    
    func fetchRequestTimeline (dateOP:String?=nil, date:Date?=nil, fetchLimit:Int?=nil, asc:Bool?=nil) -> NSFetchRequest<Timeline> {
        let fetchRequest = NSFetchRequest<Timeline>(entityName: "Timeline")
        if let d = date {
            let theDate = twDateTime.startOfDay(d)
            var predicates:[NSPredicate] = []
            if let dtOP = dateOP {
                predicates.append(NSPredicate(format: "date \(dtOP) %@", theDate as CVarArg))
            } else {
                predicates.append(NSPredicate(format: "date == %@", theDate as CVarArg))
            }
            fetchRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: predicates)
        }
        if let a = asc {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: a)]
        }
        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }
        return fetchRequest
    }
    
    
    func fetchTimeline (_ context:NSManagedObjectContext?=nil, dateOP:String?=nil, date:Date?=nil, fetchLimit:Int?=nil, asc:Bool?=nil) -> (context:NSManagedObjectContext,Timelines:[Timeline]) {
        let theContext:NSManagedObjectContext = getContext(context)
        let fetchRequest = fetchRequestTimeline(dateOP:dateOP, date:date, fetchLimit:fetchLimit, asc:asc)
        do {
            return try (theContext,theContext.fetch(fetchRequest))
        } catch {
            NSLog("\tfetch Timeline error:\n\(error)")
            return (theContext,[])
        }
    }
    
    func deleteTimeline (_ context:NSManagedObjectContext?=nil, dateOP:String?=nil, date:Date?=nil, fetchLimit:Int?=nil, asc:Bool?=nil) {
        let theContext:NSManagedObjectContext = getContext(context)
        let fetched = fetchTimeline(theContext, dateOP:dateOP, date:date, fetchLimit:fetchLimit, asc:asc)
        NSLog("\tdeleting Timelines (\(fetched.Timelines.count))")
        for e in fetched.Timelines {
            theContext.delete(e)
        }
        saveContext(theContext)
    }
    
    func newTimeline(_ context:NSManagedObjectContext?=nil, date:Date, noTrading:Bool) -> (context:NSManagedObjectContext,timeline:Timeline) {
        let theContext:NSManagedObjectContext = getContext(context)
        let timeline = Timeline(context: theContext)
        timeline.date           = twDateTime.startOfDay(date)
        timeline.noTrading      = noTrading //預設true但是newTimeline正常應為false
        return (theContext,timeline)
    }


    func updateTimeline(_ context:NSManagedObjectContext?=nil, date:Date, noTrading:Bool) -> (context:NSManagedObjectContext,timeline:Timeline) {
        let theDate = twDateTime.startOfDay(date)
        let theContext:NSManagedObjectContext = getContext(context)
        let fetched = fetchTimeline(theContext, date: theDate)
        if let timeline = fetched.Timelines.first {
            timeline.noTrading = noTrading  //休市日預設為否
            return (fetched.context,timeline)
        } else {
            return newTimeline(theContext, date:theDate, noTrading: noTrading)
        }
    }
    
    func fetchRequestPrice (sim:simPrice?=nil, dateOP:String?=nil, dateStart:Date?=nil, dateEnd:Date?=nil, bySource:[String]?=nil, byIN:Bool?=nil, fetchLimit:Int?=nil, asc:Bool?=nil) -> NSFetchRequest<Price> {
        let fetchRequest = NSFetchRequest<Price>(entityName: "Price")
        var predicates:[NSPredicate] = []
        //股票代號
        if let sId = sim?.id {
            predicates.append(NSPredicate(format: "id = %@", sId))
        }
        //日期區間
        var dtS:Date = Date.distantPast
        var dtE:Date = Date.distantFuture
        if let dtStart = dateStart {
            dtS = twDateTime.startOfDay(dtStart)
        } else {
            if let dateS = sim?.dateEarlier {
                dtS = dateS
            }
        }
        if let dtEnd = dateEnd {
            dtE = twDateTime.endOfDay(dtEnd)
        } else {
            if let s = sim {
                dtE = (s.dateEndSwitch ? s.dateEnd : twDateTime.endOfDay())
            }
        }
        if let dtOP = dateOP {
            if dtOP == "<" {
                predicates.append(NSPredicate(format: "dateTime < %@", dtS as CVarArg))
            } else if dtOP == ">" {
                predicates.append(NSPredicate(format: "dateTime > %@", dtE as CVarArg))
            } else if dtOP == "=" {
                predicates.append(NSPredicate(format: "dateTime >= %@", dtS as CVarArg))
                predicates.append(NSPredicate(format: "dateTime <= %@", dtE as CVarArg))
            } //有OP但都不是以上條件，就是all，抓全部日期
        } else {
            //沒有OP就是"="
            predicates.append(NSPredicate(format: "dateTime >= %@", dtS as CVarArg))
            predicates.append(NSPredicate(format: "dateTime <= %@", dtE as CVarArg))
        }
        //data source
        if let by = bySource {
            var IN:String
            if let include = byIN {
                IN = (include ? "IN" : "NOT IN")
            } else {
                IN = "IN"
            }
            predicates.append(NSPredicate(format: "updatedBy " + IN + " %@",IN,by))
        }
        //股票代號、日期區間和source的AND合併
        fetchRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: predicates)
        //排序
        if let a = asc {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true),NSSortDescriptor(key: "year", ascending: a),NSSortDescriptor(key: "dateTime", ascending: a)]
        }
        //筆數
        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }
//        fetchRequest.returnsObjectsAsFaults = false   //debug才需要
        return fetchRequest
    }

    func fetchPrice (_ context:NSManagedObjectContext?=nil, sim:simPrice?=nil, dateOP:String?=nil, dateStart:Date?=nil, dateEnd:Date?=nil, bySource:[String]?=nil, byIN:Bool?=nil, fetchLimit:Int?=nil, asc:Bool?=nil) -> (context:NSManagedObjectContext,Prices:[Price]) {
        let theContext:NSManagedObjectContext = getContext(context)
        let fetchRequest = fetchRequestPrice(sim:sim, dateOP:dateOP, dateStart:dateStart, dateEnd:dateEnd, bySource:bySource, byIN:byIN, fetchLimit:fetchLimit, asc:asc)
        do {
            return try (theContext,theContext.fetch(fetchRequest))
        } catch {
            NSLog("\tfetch Price error:\n\(error)")
            return (theContext,[])
        }
    }

    func deletePrice (_ context:NSManagedObjectContext?=nil, sim:simPrice?=nil, dateOP:String?=nil, dateStart:Date?=nil, dateEnd:Date?=nil, bySource:[String]?=nil, byIN:Bool?=nil, fetchLimit:Int?=nil, progress:Bool=false, solo:Bool=false) {    //當指定progress時，才須指定是否solo
        let theContext:NSManagedObjectContext = getContext(context)
        let fetched = fetchPrice(theContext, sim:sim, dateOP:dateOP, dateStart:dateStart, dateEnd:dateEnd, bySource:bySource, byIN:byIN, fetchLimit:fetchLimit)
        let allCount = fetched.Prices.count
        if let s = sim {
            NSLog("\(s.id)\(s.name) \tdeleting Prices (\(allCount))")
        } else {
            NSLog("\tdeleting Prices (\(fetched.Prices.count))")
        }
        var deletedCount:Int = 0
        for e in fetched.Prices {
            theContext.delete(e)
            if progress {
                deletedCount += 1
                if deletedCount % 100 == 0 || deletedCount == allCount {
                    if let s = sim {
                        let msg = "刪除 \(s.id) \(s.name) (\(deletedCount)/\(allCount))"
                        let progress:Float = Float(deletedCount/allCount)
                        s.masterUI?.getStock().setProgress(s.id, progress: progress, message: msg, solo:solo)
                    }
                }
            }
        }
        if context == nil && deletedCount > 0 {
            saveContext(theContext)
            if let s = sim {
                NSLog("\(s.id)\(s.name) \tdeleted and saved.")
            } else {
                NSLog("\tdeleted and saved.")
            }
        }
    }
    
    
    func newPrice(_ context:NSManagedObjectContext?=nil, source:String, id:String, dateTime:Date, year:String, close:Double, high:Double, low:Double, open:Double, volume:Double) -> (context:NSManagedObjectContext,price:Price) {
        let theContext:NSManagedObjectContext = getContext(context)
        let price = Price(context: theContext)
        price.id           = id
        price.updatedBy    = source
        price.dateTime     = dateTime
        price.year         = year
        price.priceClose   = close
        price.priceHigh    = high
        price.priceLow     = low
        price.priceOpen    = open              
        price.priceVolume  = volume
        price.simUpdated   = false
        return (theContext,price)
    }
        
    func updatePrice(_ context:NSManagedObjectContext?=nil, source:String, sim:simPrice, dateTime:Date, year:String, close:Double, high:Double, low:Double, open:Double, volume:Double) -> (context:NSManagedObjectContext,price:Price) {
        let theContext:NSManagedObjectContext = getContext(context)
        let fetched = fetchPrice(theContext, sim: sim, dateStart: twDateTime.startOfDay(dateTime), dateEnd: twDateTime.endOfDay(dateTime))
        if let price = fetched.Prices.first {
            price.updatedBy    = source
            price.dateTime     = dateTime
            price.year         = year
            price.priceClose   = close
            price.priceHigh    = high
            price.priceLow     = low
            price.priceOpen    = open
            price.priceVolume  = volume
            price.simUpdated   = false
            return (fetched.context,price)
        } else {
            return newPrice(theContext, source:source, id:sim.id, dateTime:dateTime, year:year, close:close, high:high, low:low, open:open, volume:volume)
        }
    }

        
        
        
    
    //Stock中list和name的常數值
    let sectionInList:String    = "<股群清單>"
    let sectionWasPaused:String = "[暫停模擬]"
    let sectionBySearch:String  = " 搜尋結果" //搜尋來的代號都在資料庫中；前有半形空格是為了排序在前
    let NoData:String = "查無符合。"

    func fetchRequestStock (list:[String]?=nil, id:[String]?=nil, name:[String]?=nil, fetchLimit:Int?=nil) -> NSFetchRequest<Stock> {
        let fetchRequest = NSFetchRequest<Stock>(entityName: "Stock")
        var predicates:[NSPredicate] = []
        if let ID = id {
            for sId in ID {
                let upperId = (sId == "t00" ? sId : sId.localizedUppercase)
                predicates.append(NSPredicate(format: "id CONTAINS %@", upperId))
            }
        }
        if let NAME = name {
            for sName in NAME {
                let upperName = sName.localizedUppercase
                predicates.append(NSPredicate(format: "name CONTAINS %@", upperName))
            }
        }
        if list == nil && id != nil && id == name {
            //這種組合是tableview的預設查詢
            predicates.append(NSPredicate(format: "list == %@", sectionInList))
            predicates.append(NSPredicate(format: "list == %@", sectionWasPaused))
            predicates.append(NSPredicate(format: "name == %@", NoData))
        } else {
            //tableview以外的指定條件，包括ALL
            if let inList = list {
                for s in inList {
                    if s == "ALL" { //list為"ALL"時為全部不過濾條件
                        predicates = []
                        break
                    } else {
                        predicates.append(NSPredicate(format: "list == %@", s))
                    }
                }
            }
        }
        //合併以上條件為OR，可能都沒有就是ALL（list為nil時不是ALL,是tableview的預設查詢）
        if predicates.count > 0 {
            fetchRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.or, subpredicates: predicates)
        }
        //固定的排序
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "list", ascending: true),NSSortDescriptor(key: "name", ascending: true)]

        if let limit = fetchLimit {
            fetchRequest.fetchLimit = limit
        }

        return fetchRequest
    }

    func fetchStock (_ context:NSManagedObjectContext?=nil, list:[String]?=nil, id:[String]?=nil, name:[String]?=nil, fetchLimit:Int?=nil) -> (context:NSManagedObjectContext,Stocks:[Stock]) {
        let theContext = getContext(context)
        let fetchRequest = fetchRequestStock(list:list, id: id, name: name, fetchLimit: fetchLimit)
        do {
            return try (theContext,theContext.fetch(fetchRequest))
        } catch {
            NSLog("\tfetch Stock error:\n\(error)")
            return (theContext,[])
        }
    }
    
    func deleteStock (_ context:NSManagedObjectContext?=nil, list:[String]?=nil, id:[String]?=nil, name:[String]?=nil, fetchLimit:Int?=nil) {
        let theContext:NSManagedObjectContext = getContext(context)
        let fetched = fetchStock(theContext, list:list, id: id, name: name, fetchLimit: fetchLimit)
        if fetched.Stocks.count > 0 {
            NSLog("\tdeleting Stocks (\(fetched.Stocks.count))")
        }
        for e in fetched.Stocks {
            theContext.delete(e)
        }
        saveContext(theContext)
    }

    func newStock(_ context:NSManagedObjectContext?=nil, id:String, name:String, list:String) -> (context:NSManagedObjectContext,stock:Stock) {
        let theContext = getContext(context)
        let stock = Stock(context: theContext)
        stock.id    = id
        stock.name  = name
        stock.list  = list
        return (theContext,stock)
    }
    
    func updateStock(_ context:NSManagedObjectContext?=nil, id:String, name:String, list:String) -> (context:NSManagedObjectContext,stock:Stock) {
        let theContext = getContext(context)
        let fetched = fetchStock(theContext, id:[id])
        if let stock = fetched.Stocks.first {
            stock.name = name
            stock.list = list
            return (fetched.context,stock)
        } else {
            return newStock(theContext, id: id, name: name, list: list)
        }
    }



}

public class Timeline: NSManagedObject {
    
}

extension Timeline {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Timeline> {
        return NSFetchRequest<Timeline>(entityName: "Timeline")
    }

    @NSManaged public var date: Date
    @NSManaged public var noTrading: Bool
    @NSManaged public var tradePrice: Set<Price>?

}

// MARK: Generated accessors for tradePrice
extension Timeline {

    @objc(addTradePriceObject:)
    @NSManaged public func addToTradePrice(_ value: Price)

    @objc(removeTradePriceObject:)
    @NSManaged public func removeFromTradePrice(_ value: Price)

//    @objc(addTradePrice:)
//    @NSManaged public func addToTradePrice(_ values: NSSet)
//
//    @objc(removeTradePrice:)
//    @NSManaged public func removeFromTradePrice(_ values: NSSet)

}

public class Stock: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

}

extension Stock {

    @NSManaged public var id: String
    @NSManaged public var list: String
    @NSManaged public var name: String

}

public class Price: NSManagedObject {

    // Insert code here to add functionality to your managed object subclass

}

//為什麼不用Codegen？因為要指定數值為Double而不是NSNumber以簡化型別轉換
extension Price {
    @NSManaged public var cumulCost: Double
    @NSManaged public var cumulCut: Float
    @NSManaged public var cumulDays: Float
    @NSManaged public var cumulProfit: Double
    @NSManaged public var cumulROI: Double
    @NSManaged public var dateTime: Date
    @NSManaged public var dividend: Float       //距除權息日數
    @NSManaged public var id: String
    @NSManaged public var k20Base: Double
    @NSManaged public var k80Base: Double
    @NSManaged public var kdD: Double
    @NSManaged public var kdJ: Double
    @NSManaged public var kdK: Double
    @NSManaged public var kdKZ: Double          //kdK的標準分數（125天）
    @NSManaged public var kGrow: Double         //與前筆相關不省略
    @NSManaged public var kGrowRate: Double
    @NSManaged public var kMaxIn5d: Double      //9天最高K值
    @NSManaged public var kMinIn5d: Double      //9天最低K值
    @NSManaged public var ma20: Double
    @NSManaged public var ma20Days: Float
    @NSManaged public var ma20Diff: Double
    @NSManaged public var ma20H: Double
    @NSManaged public var ma20L: Double
    @NSManaged public var ma20Max9d: Double
    @NSManaged public var ma20Min9d: Double
    @NSManaged public var ma60: Double
    @NSManaged public var ma60Avg: Double
    @NSManaged public var ma60Days: Float
    @NSManaged public var ma60Diff: Double
    @NSManaged public var ma60H: Double
    @NSManaged public var ma60L: Double
    @NSManaged public var ma60Max9d: Double
    @NSManaged public var ma60Min9d: Double
    @NSManaged public var ma60Rank: String
    @NSManaged public var ma60Z: Double         //ma60的標準分數（375天）
    @NSManaged public var ma60Z1: Double        //ma60的標準分數（125天）
    @NSManaged public var ma60Z2: Double        //ma60的標準分數（250天）
    @NSManaged public var macd9: Double         //與前筆相關不省略
    @NSManaged public var macdEma12: Double     //與前筆相關不省略
    @NSManaged public var macdEma26: Double     //與前筆相關不省略
    @NSManaged public var macdMax9d: Double
    @NSManaged public var macdMin9d: Double
    @NSManaged public var macdOsc: Double
    @NSManaged public var macdOscH: Double
    @NSManaged public var macdOscL: Double
    @NSManaged public var macdOscZ: Double      //macdOsc的標準分數（125天）
    @NSManaged public var maDiff: Double        //(ma20 - ma60) / priceClose
    @NSManaged public var maDiffDays: Float
    @NSManaged public var maMax9d: Double
    @NSManaged public var maMin9d: Double
    @NSManaged public var moneyChange: Double
    @NSManaged public var moneyMultiple: Double
    @NSManaged public var moneyRemark: String
    @NSManaged public var price60HighDiff: Double   //60天最高價距離現價的比率
    @NSManaged public var price60LowDiff: Double    //60天最低價距離現價的比率
    @NSManaged public var price250HighDiff: Double  //250天最高價距離現價的比率
    @NSManaged public var price250LowDiff: Double   //250天最低價距離現價的比率
    @NSManaged public var priceClose: Double
    @NSManaged public var priceHigh: Double
    @NSManaged public var priceHighDiff: Double
    @NSManaged public var priceLow: Double
    @NSManaged public var priceLowDiff: Double
    @NSManaged public var priceOpen: Double
    @NSManaged public var priceUpward: String
    @NSManaged public var priceVolume: Double
    @NSManaged public var priceVolumeZ: Double
    @NSManaged public var qtyBuy: Double
    @NSManaged public var qtyInventory: Double
    @NSManaged public var qtySell: Double
    @NSManaged public var simBalance: Double
    @NSManaged public var simCost: Double
    @NSManaged public var simDays: Float
    @NSManaged public var simIncome: Double
    @NSManaged public var simReverse: String
    @NSManaged public var simROI: Double
    @NSManaged public var simRound: Float
    @NSManaged public var simRule: String
    @NSManaged public var simRuleBuy: String
    @NSManaged public var simRuleLevel: Float
    @NSManaged public var simUnitCost: Double
    @NSManaged public var simUnitDiff: Double
    @NSManaged public var simUpdated: Bool
    @NSManaged public var updatedBy: String
    @NSManaged public var year: String
    @NSManaged public var tradeDate: Timeline?

}

//
//  simStock.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation


struct simStock {
    
    let simTesting:Bool = false
    let request = urlRequest()
    let defaults = UserDefaults.standard

    private(set) var stocks:[Stock] = []
//    private(set) var trades:[Trade] = []

    init() {
        if defaults.integer(forKey: "simYears") == 0 {
            defaults.set(1, forKey: "simYears")
        }
        self.stocks = Stock.fetch(coreData.shared.context)
        if self.stocks.count == 0 {
            let group1:[(sId:String,sName:String)] = [
                (sId:"1590", sName:"亞德客-KY"),
                (sId:"3406", sName:"玉晶光"),
                (sId:"2327", sName:"國巨"),
                (sId:"2330", sName:"台積電"),
                (sId:"2474", sName:"可成")]
            self.newStock(stocks: group1, group: "股群1")
            
            let group2:[(sId:String,sName:String)] = [
                (sId:"9914", sName:"美利達"),
                (sId:"2377", sName:"微星"),
                (sId:"1476", sName:"儒鴻"),
                (sId:"2912", sName:"統一超"),
                (sId:"9910", sName:"豐泰")]
            self.newStock(stocks: group2, group: "股群2")
        }
    }
        
    mutating func fetchStocks(_ searchText:[String]?=nil) {
        self.stocks = Stock.fetch(coreData.shared.context, sId: searchText, sName: searchText)
    }
    
//    mutating func fetchTrades(_ stock:Stock) {
//        let context = stock.managedObjectContext ?? coreData.shared.context
//        self.trades = Trade.fetch(context, stock: stock, asc: false)
//    }

        
    mutating func newStock(stocks:[(sId:String,sName:String)], group:String?=nil) {
        let defaultDate = self.defaultDate
        let context = coreData.shared.context
        for stock in stocks {
            let s = Stock.new(context, sId:stock.sId, sName:stock.sName, group: group)
            s.dateFirst = defaultDate.first
            s.dateStart = defaultDate.start
        }
        try? context.save()
        self.fetchStocks()
        NSLog("new stocks added: \(stocks)")
    }
    
    mutating func moveStocksToGroup(_ stocks:[Stock], group:String) {
        var requestStocks:[Stock] = []
        if let context = stocks.first?.context {
            let defaultDate = self.defaultDate
            for stock in stocks {
                if stock.group == "" && group != "" {
                    if defaultDate.first < stock.dateFirst {
                        stock.dateFirst = defaultDate.first
                        stock.dateStart = defaultDate.start
                    }
                    requestStocks.append(stock)
                }
                stock.group = group
            }
            try? context.save()
            self.fetchStocks()
            if requestStocks.count > 0 {
                request.runRequest(stocks: requestStocks)
            }
        }
    }
    
    var defaultDate:(first:Date,start:Date) {
        let simYears = defaults.integer(forKey: "simYears")
        let dt0 = twDateTime.calendar.date(byAdding: .year, value: (0 - simYears), to: twDateTime.startOfDay()) ?? Date.distantFuture
        let dt1 = twDateTime.calendar.date(byAdding: .year, value: 1, to: dt0) ?? Date.distantFuture
        return (dt0,dt1)
    }
        
    
//    var stocksJSON: Data? { try? JSONEncoder().encode(stocks) }
//    init?(stocksJSON: Data?) {
//        if let json = stocksJSON, let s = try? JSONDecoder().decode(Array<Stock>.self, from: json) {
//            stocks = s
//        } else {
//            stocks = []
//        }
//    }
    
    func downloadStocks(doItNow:Bool = false) {
        if doItNow {
            request.twseDailyMI()
        } else if let timeStocksDownloaded = defaults.object(forKey: "timeStocksDownloaded") as? Date {
            if timeStocksDownloaded.timeIntervalSinceNow < 0 - (10 * 24 * 60 * 60) {    //10天更新一次
                request.twseDailyMI()
            }
        } else {
            request.twseDailyMI()
        }
    }
        
    func downloadTrades(doItNow:Bool = false) {
        if doItNow {
            NSLog("立即下載全部交易！")
            request.runRequest(stocks: stocks, all: true)
        } else if simTesting {
            NSLog("模擬測試...")
        } else {
            let last1332 = twDateTime.time1330(twDateTime.yesterday(), delayMinutes: 2)
            let time1332 = twDateTime.time1330(delayMinutes: 2)
            let time0900 = twDateTime.time0900()
            if (request.isOffDay && twDateTime.isDateInToday(request.timeTradesDownloaded)) {
                NSLog("休市日且今天已更新。")
            } else if request.timeTradesDownloaded > last1332 && Date() < time0900 {
                NSLog("今天還沒開盤且上次更新是昨收盤後。")
            } else if request.timeTradesDownloaded > time1332 {
                NSLog("上次更新是今天收盤之後。")
            } else { //if timeTradesDownloaded.compare(time0900) == .orderedDescending && timeTradesDownloaded.compare(time1332) == .orderedAscending {
                NSLog("下載交易及排程...")
                request.runRequest(stocks: stocks)
            }
        }
    }

    
}


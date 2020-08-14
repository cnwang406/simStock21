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
    let simTestStart:Date? = twDateTime.dateFromString("2005/7/31")
    let request = simDataRequest()
    let defaults = UserDefaults.standard

    private(set) var stocks:[Stock] = []

    init() {
        if defaults.double(forKey: "simMoneyBase") == 0 {
            let dateStart = twDateTime.calendar.date(byAdding: .year, value: -3, to: twDateTime.startOfDay()) ?? Date.distantFuture
            setDefaults(start: dateStart, money: 70.0, invest: true)
        }
        self.stocks = Stock.fetch(coreData.shared.context)
        if self.stocks.count == 0 {
            let group1:[(sId:String,sName:String)] = [
                (sId:"1590", sName:"亞德客-KY"),
                (sId:"1515", sName:"力山"),
                (sId:"2330", sName:"台積電"),
                (sId:"2327", sName:"國巨")]
            self.newStock(stocks: group1, group: "股群_1")
            
            let group2:[(sId:String,sName:String)] = [
                (sId:"2324", sName:"仁寶"),
                (sId:"1301", sName:"台塑"),
                (sId:"2201", sName:"裕隆"),
                (sId:"2317", sName:"鴻海")]
            self.newStock(stocks: group2, group: "股群_2")
        }
    }
        
    mutating func fetchStocks(_ searchText:[String]?=nil) {
        self.stocks = Stock.fetch(coreData.shared.context, sId: searchText, sName: searchText)
    }
        
    mutating func newStock(stocks:[(sId:String,sName:String)], group:String?=nil) {
        let context = coreData.shared.context
        for stock in stocks {
            let s = Stock.new(context, sId:stock.sId, sName:stock.sName, group: group)
            s.dateFirst = self.simDefaults.first
            s.dateStart = self.simDefaults.start
            s.simMoneyBase = self.simDefaults.money
        }
        try? context.save()
        self.fetchStocks()
        NSLog("new stocks added: \(stocks)")
    }
    
    mutating func moveStocksToGroup(_ stocks:[Stock], group:String) {
        var requestStocks:[Stock] = []
        if let context = stocks.first?.context {
            for stock in stocks {
                if stock.group == "" && group != "" {
                    if simDefaults.first < stock.dateFirst {
                        stock.dateFirst = self.simDefaults.first
                        stock.dateStart = self.simDefaults.start
                    }
                    stock.simMoneyBase = self.simDefaults.money
                    requestStocks.append(stock)
                }
                stock.group = group
            }
            try? context.save()
            if requestStocks.count > 0 {
                self.request.runRequest(stocks: requestStocks, action: .tUpdateAll)
            }
            if group == "" {    //整群改群同時重讀會因雙重UI變動當掉
                self.fetchStocks()
            }
        }
    }
    
    func addInvest(_ trade: Trade) {
        if let context = trade.managedObjectContext {
            if trade.simInvestByUser == 0 {
                if trade.simInvestAdded > 0 {
                    trade.simInvestByUser = -1
                } else if trade.simInvestAdded == 0 {
                    trade.simInvestByUser = 1
                }
            } else {
                trade.simInvestByUser = 0
            }
//                if trade.simInvestTimes <= 3 {
//                    trade.stock.simAddInvest = false    //取消前兩次加碼時，關閉自動加碼
//                }
            
            try? context.save()
            DispatchQueue.global().async {
                self.request.simTechnical(stock: trade.stock, action: .simUpdateAll)
            }
        }
    }
    
    func setReversed(_ trade: Trade) {
        if let context = trade.managedObjectContext {
            let trades = Trade.fetch(context, stock: trade.stock, simReversed:true)
            let simQty = trade.simQty
            if trade.simReversed == "" {
                switch simQty.action {
                case "買":
                    trade.simReversed = "B-"
                case "賣":
                    trade.simReversed = "S-"
                case "餘":
                    trade.simReversed = "S+"
                default:
                    trade.simReversed = "B+"
                }
                for tr in trades {
                    if tr.date > trade.date {
                        tr.simReversed = ""
                    }
                }
            } else {
                for tr in trades {
                    tr.simReversed = ""
                }
            }
            try? context.save()
            DispatchQueue.global().async {
                self.request.simTechnical(stock: trade.stock, action: .simUpdateAll)
            }
        }
    }
    
    func settingStocks(_ stocks:[Stock],dateStart:Date,moneyBase:Double,addInvest:Bool) {
        if let context = stocks[0].managedObjectContext {
            for stock in stocks {
                stock.dateStart = dateStart
                stock.dateFirst = twDateTime.calendar.date(byAdding: .year, value: -1, to: dateStart) ?? stock.dateStart
                stock.simMoneyBase = moneyBase
                stock.simAddInvest = addInvest
            }
            if !simTesting {
                DispatchQueue.main.async {
                    try? context.save()
                }
                request.runRequest(stocks: stocks, action: .simResetAll)
            }
        }
    }
    
    var simDefaults:(first:Date,start:Date,money:Double,invest:Bool) {
        let start = defaults.object(forKey: "simDateStart") as? Date ?? Date.distantFuture
        let money = defaults.double(forKey: "simMoneyBase")
        let invest = defaults.bool(forKey: "simAddInvest")
        let first = twDateTime.calendar.date(byAdding: .year, value: -1, to: start) ?? start
        return (first,start,money,invest)
    }
    
    func setDefaults(start:Date,money:Double,invest:Bool) {
        defaults.set(start, forKey: "simDateStart")
        defaults.set(money, forKey: "simMoneyBase")
        defaults.set(invest,forKey: "simAddInvest")
    }
    
    var t00:Stock? {
        let t00 = stocks.filter{$0.sId == "t00"}
        if t00.count > 0 {
            return t00[0]
        }
        return nil
    }
    
        
    var groupStocks:[[Stock]] {
        Dictionary(grouping: stocks) { (stock:Stock)  in
            stock.group
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].group < $1[0].group}
    }
    
    func stocksSummary(_ stocks:[Stock]) -> (count:Double, roi:Double, days:Double) {
        if stocks.count == 0 {
            return (0,0,0)
        }
        var sumRoi:Double = 0
        var sumDays:Double = 0
        let s = stocks.filter{$0.sId != "t00"}
        for stock in s {
            if let trade = stock.lastTrade(stock.context) {
                sumRoi += (trade.rollAmtRoi / stock.years)
                sumDays += trade.days
            }
        }
        let count = Double(s.count)
        let roi = sumRoi / count
        let days = sumDays / count
        return (count, roi, days)
    }
    
    func runTest(start:Date) {
        defaults.set(true, forKey: "simResetAll")
        NSLog("")
        NSLog("== simTesting \(twDateTime.stringFromDate(start)) ==")
        var groupRoi:String = ""
        var groupDays:String = ""
        for g in 0...(groupStocks.count - 1) {
            let stocks = groupStocks[g].filter{$0.sId != "t00"}
            let group  = stocks[0].group
            let result = testStocks(stocks, group: group, start: start)
            groupRoi = groupRoi + (groupRoi.count > 0 ? ",, " : "") + result.roi
            groupDays = groupDays + (groupDays.count > 0 ? ",, " : "") + result.days
        }
        print("\n")
        print(groupRoi)
        print(groupDays)
        print("\n")
        NSLog("== simTesting finished. ==")
        NSLog("")
    }
    
    func testStocks(_ stocks:[Stock], group:String, start:Date) -> (roi:String, days:String) {
        var roi:String = ""
        var days:String = ""
        let years:Int = Int(round(Date().timeIntervalSince(start) / 86400 / 365))
        print("\n\n\(group)： 自\(twDateTime.stringFromDate(start,format:"yyyy"))第\(years)年起 ... ", terminator:"")
        var nextYear:Date = start
        while nextYear <= (twDateTime.calendar.date(byAdding: .year, value: -1, to: twDateTime.startOfDay()) ?? Date.distantPast) {
            settingStocks(stocks, dateStart: nextYear, moneyBase: 100, addInvest: true)
            self.request.runRequest(stocks: stocks, action: .simTesting)
            let summary = stocksSummary(stocks)
            roi = String(format:"%.1f", summary.roi) + (roi.count > 0 ? ", " : "") + roi
            days = String(format:"%.f", summary.days) + (days.count > 0 ? ", " : "") + days
            print("\(twDateTime.stringFromDate(nextYear, format: "yyyy"))" + String(format:"(%.1f/%.f) ",summary.roi,summary.days), terminator:"")
            nextYear = (twDateTime.calendar.date(byAdding: .year, value: 1, to: nextYear) ?? Date.distantPast)
        }
        return (roi,days)
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
            let days:TimeInterval = (0 - timeStocksDownloaded.timeIntervalSinceNow) / 86400
            if days > 10 {    //10天更新一次
                request.twseDailyMI()
            } else {
                NSLog("stocks   上次：\(twDateTime.stringFromDate(timeStocksDownloaded,format: "yyyy/MM/dd HH:mm:ss")), next: in \(String(format:"%.1f",10 - days)) days")
            }
        } else {
            request.twseDailyMI()
        }
    }
        
    func downloadTrades(requestAction:simDataRequest.simTechnicalAction?=nil) {
        if let action = requestAction {
            request.runRequest(stocks: stocks, action: action)
        } else if simTesting {
            NSLog("模擬測試...")
        } else {
            let last1332 = twDateTime.time1330(twDateTime.yesterday(), delayMinutes: 2)
            let time1332 = twDateTime.time1330(delayMinutes: 2)
            let time0900 = twDateTime.time0900()
            if (request.isOffDay && twDateTime.isDateInToday(request.timeTradesUpdated)) {
                NSLog("休市日且今天已更新。")
            } else if request.timeTradesUpdated > last1332 && Date() < time0900 {
                NSLog("今天還沒開盤且上次更新是昨收盤後。")
            } else if request.timeTradesUpdated > time1332 {
                NSLog("上次更新是今天收盤之後。")
            } else {
                let all:Bool = !twDateTime.inMarketingTime(request.timeTradesUpdated, delay: 2, forToday: true)
                request.runRequest(stocks: stocks, action: (all ? .newTrades : .realtime))
            }
        }
    }

    
}


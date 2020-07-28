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
    let simTestStart:Date? = nil //twDateTime.dateFromString("2005/7/27")
    var tUpdateAll:Bool = false
    let request = simDataRequest()
    let defaults = UserDefaults.standard

    private(set) var stocks:[Stock] = []

    init() {
        if defaults.double(forKey: "simMoneyBase") == 0 {
            let dateStart = twDateTime.calendar.date(byAdding: .year, value: -3, to: twDateTime.startOfDay()) ?? Date.distantFuture
            setDefaults(start: dateStart, money: 50.0, invest: true)
        }
        self.stocks = Stock.fetch(coreData.shared.context)
        if self.stocks.count == 0 {
            let group1:[(sId:String,sName:String)] = [
                (sId:"1590", sName:"亞德客-KY"),
                (sId:"2330", sName:"台積電"),
                (sId:"2201", sName:"裕隆"),
                (sId:"2317", sName:"鴻海")]
            self.newStock(stocks: group1, group: "股群1")

//            let group1:[(sId:String,sName:String)] = [
//                (sId:"1590", sName:"亞德客-KY"),
//                (sId:"3406", sName:"玉晶光"),
//                (sId:"2327", sName:"國巨"),
//                (sId:"2330", sName:"台積電"),
//                (sId:"2474", sName:"可成")]
//            self.newStock(stocks: group1, group: "股群1")
//
//            let group2:[(sId:String,sName:String)] = [
//                (sId:"9914", sName:"美利達"),
//                (sId:"2377", sName:"微星"),
//                (sId:"1476", sName:"儒鴻"),
//                (sId:"2912", sName:"統一超"),
//                (sId:"9910", sName:"豐泰")]
//            self.newStock(stocks: group2, group: "股群2")
        }
    }
        
    mutating func fetchStocks(_ searchText:[String]?=nil) {
        self.stocks = Stock.fetch(coreData.shared.context, sId: searchText, sName: searchText)
    }
        
    mutating func newStock(stocks:[(sId:String,sName:String)], group:String?=nil) {
        let defaults = self.simDefaults
        let context = coreData.shared.context
        for stock in stocks {
            let s = Stock.new(context, sId:stock.sId, sName:stock.sName, group: group)
            s.dateFirst = defaults.first
            s.dateStart = defaults.start
            s.simMoneyBase = defaults.money
        }
        try? context.save()
        self.fetchStocks()
        NSLog("new stocks added: \(stocks)")
    }
    
    mutating func moveStocksToGroup(_ stocks:[Stock], group:String) {
        var requestStocks:[Stock] = []
        if let context = stocks.first?.context {
            let defaults = self.simDefaults
            for stock in stocks {
                if stock.group == "" && group != "" {
                    if defaults.first < stock.dateFirst {
                        stock.dateFirst = defaults.first
                        stock.dateStart = defaults.start
                    }
                    stock.simMoneyBase = defaults.money
                    requestStocks.append(stock)
                }
                stock.group = group
            }
            try? context.save()
            self.fetchStocks()
            if requestStocks.count > 0 {
                request.runRequest(stocks: requestStocks, action: .simUpdateAll)
            }
        }
    }
    
    func addInvest(_ trade: Trade) {
        if let context = trade.managedObjectContext {
            if trade.simInvestAdded > 0 {
                trade.simInvestAdded = 0
                trade.stock.simAddInvest = false
            } else {
                trade.simInvestAdded = 1
            }
            try? context.save()
            DispatchQueue.global(qos: .userInitiated).async {
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
                try? context.save()
                request.runRequest(stocks: stocks, action: .simUpdateAll)
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
    
    func stocksSummary(_ stocks:[Stock]) -> String {
        var roi:Double = 0
        var days:Double = 0
        let s = stocks.filter{$0.sId != "t00"}
        for stock in s {
            if let trade = stock.lastTrade(stock.context) {
                roi += (trade.rollAmtRoi / stock.years)
                days += (trade.rollDays / trade.rollRounds)
            }
        }
        let sCount = "\(s.count)支股 "
        let sRoi = String(format:"平均年報酬:%.1f%% ",roi / Double(s.count))
        let sDays = String(format:"平均週期:%.f天",days / Double(s.count))
        return "\(sCount)\(sRoi)\(sDays)"
    }

        
    var groupStocks:[[Stock]] {
        Dictionary(grouping: stocks) { (stock:Stock)  in
            stock.group
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].group < $1[0].group}
    }
    
    func runTest(start:Date) {
        if start <= (twDateTime.calendar.date(byAdding: .year, value: -1, to: twDateTime.startOfDay()) ?? Date.distantPast) {
            settingStocks(groupStocks[0], dateStart: start, moneyBase: 100, addInvest: true)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                self.request.runRequest(stocks: self.groupStocks[0], action: .simTesting)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                    let years:Int = Int(round(Date().timeIntervalSince(start) / 86400 / 365))
                    NSLog("== \(twDateTime.stringFromDate(start,format:"yyyy")) \(self.stocksSummary(self.groupStocks[0])) == \(years)\((years - 1) % 5 == 0 ? "\n" : "")")
                    let nextYear = (twDateTime.calendar.date(byAdding: .year, value: 1, to: start) ?? Date.distantPast)
                    self.runTest(start: nextYear)
                }
            }
        } else {
//            let d = simDefaults
//            settingStocks(stocks, dateStart: d.start, moneyBase: d.money, addInvest: d.invest, runTesting: true)
            defaults.set(true, forKey: "updateAll")
            NSLog("== simTesting finished. ==\n\n")
        }
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
        
    func downloadTrades(updateAll:Bool = false) {
        if updateAll {
            NSLog("立即下載全部交易！")
            request.runRequest(stocks: stocks, action: (self.tUpdateAll ? .tUpdateAll : .simUpdateAll))
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
            } else {
                let all:Bool = !twDateTime.inMarketingTime(request.timeTradesDownloaded, delay: 2, forToday: true)
                NSLog("下載\(all ? "歷史價" : "盤中價")...（上次：" + twDateTime.stringFromDate(request.timeTradesDownloaded, format: "yyyy/MM/dd HH:mm:ss") + "）")
                request.runRequest(stocks: stocks, action: (all ? .newTrades : .realtime))
            }
        }
    }

    
}


//
//  simStockList.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
import SwiftUI
import MobileCoreServices

class simStockList:ObservableObject {
    @Published private var sim:simStock = simStock()
    @Published var widthClass:WidthClass = .compact
    @Published var runningMsg:String = ""

//    @Published var filterIsOn:Bool = false
    
    var versionNow:String
    var versionLast:String = ""

    private let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    private let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String

    enum WidthClass {
        case compact
        case widePhone
        case regular
        case widePad
    }
    
    private var hClass = UITraitCollection.current.horizontalSizeClass
    private var vClass = UITraitCollection.current.verticalSizeClass
    private var isPad  = UIDevice.current.userInterfaceIdiom == .pad

    var deviceWidthClass: WidthClass {
        if UIDevice.current.orientation.isLandscape {
            return (self.hClass == .regular && isPad ? .widePad : .widePhone)
        } else {
            return (self.hClass == .regular ? .regular : .compact)
        }
    }
    
    init() {
        versionNow = versionNo + (buildNo == "0" ? "" : "(\(buildNo))")
        widthClass = deviceWidthClass
        NotificationCenter.default.addObserver(self, selector: #selector(self.setWidthClass), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.setRequestStatus), name: NSNotification.Name("requestRunning") , object: nil)
    }
        
    var searchText:[String]? = nil {    //搜尋String以空格逗號分離為關鍵字Array
        didSet {
            sim.fetchStocks(searchText)
        }
    }
    
    var searchTextInGroup:Bool {    //單詞的搜尋目標已在股群內？
        if let search = searchText, search.count == 1 {
            if sim.stocks.map({$0.sId}).contains(search[0]) || sim.stocks.map({$0.sName}).contains(search[0]) {
                return true
            }
        }
        return false
    }
    
    private var prefixedStocks:[[Stock]] {
        Dictionary(grouping: sim.stocks) { (stock:Stock)  in
            stock.prefix
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].prefix < $1[0].prefix}
    }
    
    var prefixs:[String] {
        prefixedStocks.map{$0[0].prefix}
    }
    
    func shiftRightStock(_ stock:Stock) -> Stock {
        if let i = sim.stocks.firstIndex(of: stock) {
            if i > 0 {
                return sim.stocks[i - 1]
            } else {
                return sim.stocks[sim.stocks.count - 1]
            }
        }
        return stock
    }
    
    func shiftLeftStock(_ stock:Stock) -> Stock {
        if let i = sim.stocks.firstIndex(of: stock) {
            if i < sim.stocks.count - 1 {
                return sim.stocks[i + 1]
            } else {
                return sim.stocks[0]
            }
        }
        return stock
    }
    
    func prefixStocks(prefix:String) -> [Stock] {
        return prefixedStocks.filter{ $0[0].prefix == prefix}[0]
    }
        
    var groupStocks:[[Stock]] {
        Dictionary(grouping: sim.stocks) { (stock:Stock)  in
            stock.group
        }.values
            .map{$0.map{$0}.sorted{$0.sName < $1.sName}}
            .sorted {$0[0].group < $1[0].group}
    }
    
    var groups:[String] {
        groupStocks.map{$0[0].group}.filter{$0 != ""}
    }
    
    func csvStocksIdName(_ stocks:[Stock]) -> String {
        var csv:String = ""
        for stock in stocks {
            if csv.count > 0 {
                csv += ", "
            }
            csv += stock.sId + " " + stock.sName
        }
        return csv
    }
        
    var searchGotResults:Bool { //查無搜尋目標？
        if let firstGroup = groupStocks.first?[0].group, firstGroup == "" {
            return true
        }
        return false
    }
    
    var isRunning:Bool {
        self.runningMsg.count > 0
    }
    
    func deleteTrades(_ stocks:[Stock], oneMonth:Bool=false) {
        DispatchQueue.global().async {
            for stock in stocks {
                stock.deleteTrades(oneMonth: oneMonth)
            }
            DispatchQueue.main.async {
                self.sim.request.downloadTrades(stocks, requestAction: (stocks.count > 1 ? .allTrades : .newTrades), allStocks: self.sim.stocks)    //allTrades才會提示等候訊息
            }
        }
    }

    func moveStocks(_ stocks:[Stock], toGroup:String = "") {
        sim.moveStocksToGroup(stocks, group:toGroup)
    }
    
    func addInvest(_ trade: Trade) {
        sim.addInvest(trade)
    }
    
    func setReversed(_ trade: Trade) {
        sim.setReversed(trade)
    }

    var simDefaults:String {
        let defaults = sim.simDefaults
        let start = twDateTime.stringFromDate(defaults.start,format: "起始日yyyy/MM/dd")
        let money = String(format:"起始本金%.f萬元",defaults.money)
        if defaults.invest == 9 {
            
        }
        let invest = (defaults.invest > 9 ? "自動無限加碼" : (defaults.invest > 0 ? String(format:"自動%.0f次加碼", defaults.invest) : ""))
        return "預設：\(start) \(money) \(invest)"
    }
    
    func stocksSummary(_ stocks:[Stock]) -> String {
        let summary = sim.stocksSummary(stocks)
        let count = String(format:"%.f支股 ",summary.count)
        let roi = String(format:"平均年報酬:%.1f%% ",summary.roi)
        let days = String(format:"平均週期:%.f天",summary.days)
        return "\(count) \(roi) \(days)"
    }
    
    func reloadNow(_ stocks: [Stock], action:simDataRequest.simTechnicalAction) {
        if let context = stocks.first?.context {
            for stock in stocks {
                if stock.simAutoInvest == 0 {
                    stock.simAutoInvest = 2
                }
            }
            try? context.save()
        }
        self.sim.request.downloadTrades(stocks, requestAction: action, allStocks: self.sim.stocks)
    }
    
    func applySetting (_ stock:Stock, dateStart:Date,moneyBase:Double,autoInvest:Double, applyToGroup:Bool, applyToAll:Bool, saveToDefaults:Bool) {
        var stocks:[Stock] = []
        if applyToAll {
            stocks = sim.stocks
        } else if applyToGroup {
            for g in groupStocks {
                if g[0].group == stock.group {
                    for s in g {
                        stocks.append(s)
                    }
                }
            }
        } else {
            stocks.append(stock)
        }
        sim.settingStocks(stocks, dateStart: dateStart, moneyBase: moneyBase, autoInvest: autoInvest)
        if saveToDefaults {
            sim.setDefaults(start: dateStart, money: moneyBase, invest: autoInvest)
        }
    }
    
    @objc private func setWidthClass(_ notification: Notification) {
        widthClass = deviceWidthClass
        NSLog("widthClass:\(widthClass)")
    }
    
    @objc private func setRequestStatus(_ notification: Notification) {
        if let userInfo = notification.userInfo, let msg = userInfo["msg"] as? String {
            runningMsg = msg
        }
    }


    @objc private func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            simLog.addLog ("=== appDidBecomeActive v\(versionNow) ===")
            self.versionLast = UserDefaults.standard.string(forKey: "simStockVersion") ?? ""
            if sim.simTesting {
                let start = sim.simTestStart ?? (twDateTime.calendar.date(byAdding: .year, value: -15, to: twDateTime.startOfDay()) ?? Date.distantPast)
                sim.runTest(start: start)
            } else {
                UserDefaults.standard.set(versionNow, forKey: "simStockVersion")
                sim.request.downloadStocks()
                var action:simDataRequest.simTechnicalAction? {
                    if UserDefaults.standard.bool(forKey: "simResetAll") {
                        UserDefaults.standard.removeObject(forKey: "simResetAll")
                        return .simResetAll
                    } else if versionLast != versionNow {
                        if buildNo == "0" || versionLast == "" {
                            return .tUpdateAll
                        } else {
                            return .simResetAll
                        }
//                    } else if self.runningMsg != "" {
//                        return .allTrades
                    }
                    return nil
                }
                DispatchQueue.global().async {
                    self.sim.request.downloadTrades(self.sim.stocks, requestAction: action)
                }
            }
        case UIApplication.willResignActiveNotification:
            simLog.addLog ("=== appWillResignActive ===\n")
            self.sim.request.invalidateTimer()
        default:
            break
        }

    }

    
}

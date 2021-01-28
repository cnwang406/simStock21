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
import BackgroundTasks

class simStockList:ObservableObject {
    @Published private var sim:simStock = simStock()
    @Published var widthClass:WidthClass = .compact
    @Published var runningMsg:String = ""
    
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
//        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
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
    
    var newGroupName:String {
        var nameInGroup:String = "股群_"
        var numberInGroup:Int = 0
        for groupName in self.groups {
            if let numbersRange = groupName.rangeOfCharacter(from: .decimalDigits) {
                let n = Int(groupName[numbersRange.lowerBound..<numbersRange.upperBound]) ?? 0
                if n > numberInGroup {
                    nameInGroup = String(groupName[..<numbersRange.lowerBound])
                    numberInGroup = n
                }
            }
        }
        return (nameInGroup + String(numberInGroup + 1))
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
    
    func csvMonthlyRoi(_ stocks: [Stock], from:Date?=nil) -> String {
        var text:String = ""
        var txtMonthly:String = ""

        func combineMM(_ allHeader:[String], newHeader:[String], newBody:[String]) -> (header:[String],body:[String]) {
            var mm = allHeader
            var bb = newBody
            for n in newHeader {
                var lm:String = ""
                var inserted:Bool = false
                for (idxM,m) in mm.enumerated() {
                    if n < m && n > lm {
                        mm.insert(n, at: idxM)
                        inserted = true
                        break
                    }
                    lm = m
                }
                if let ml = mm.last {
                    if !inserted && n > ml {
                        mm.append(n)
                    }
                } else {
                    mm.append(n)
                }
            }
            for m in mm {   //反過來用補完的header來補body的欄位
                var ln:String = ""
                var inserted:Bool = false
                for (idxN,n) in newHeader.enumerated() {
                    if m < n && m > ln {
                        bb.insert("", at: idxN)
                        inserted = true
                        break
                    }
                    ln = n
                }
                if let nl = newHeader.last {
                    if !inserted && m > nl {
                        bb.append("")
                    }
                } else {
                    bb.append("")
                }
            }
            return (mm,bb)
        }
        


        var allHeader:[String] = []     //合併後的月別標題：如果各股起迄月別不一致？所以需要合併
        var allHeaderX2:[String] = []   //前兩欄，即簡稱和本金
        for stock in stocks {
            if stock.sId != "t00" {
                var tFrom:Date {
                    if let f = from {
                        return f
                    } else {
                        if let d = stock.lastTrade(stock.context)?.date, let f = twDateTime.calendar.date(byAdding: .month, value: -6, to: d) {
                            return f
                        }
                    }
                    return Date.distantPast
                }
                let txt = sim.csvStockRoi(stock, from: tFrom)
                if txt.body.count > 0 { //有損益才有字
                    let subHeader = txt.header.split(separator: ",")
                    var newHeader:[String] = []   //待合併的新的月別標題
                    if subHeader.count >= 3 {
                        for (i,s) in subHeader.enumerated() {
                            if i < 2 {
                                if allHeaderX2.count < 2 {
                                    allHeaderX2.append(String(s).replacingOccurrences(of: " ", with: ""))
                                }
                            } else {
                                newHeader.append(String(s).replacingOccurrences(of: " ", with: ""))   //順便去空白
                            }
                        }
                    }
                    let subBody = txt.body.split(separator: ",")
                    var newBody:[String] = []   //待補”,"分隔的數值欄
                    var newBodyX2:[String] = [] //前兩欄，即簡稱和本金
                    if subBody.count >= 3 {
                        for (i,s) in subBody.enumerated() {
                            if i < 2 {
                                newBodyX2.append(String(s).replacingOccurrences(of: " ", with: "")) //順便去空白
                            } else {
                                newBody.append(String(s).replacingOccurrences(of: " ", with: ""))   //順便去空白
                            }
                        }
                    }
                    if newBody.count > 0 && newHeader.count > 0 {
                        //每次都把標題和逐月損益，跟之前各股的合併，這樣才能確保全部股的月欄是對齊的
                        let all = combineMM(allHeader, newHeader:newHeader, newBody:newBody)   //<<<<<<<<<< 合併
                        let allBody = newBodyX2 + all.body
                        let txtBody = (allBody.map{String($0)}).joined(separator: ", ")
                        txtMonthly += txtBody + "\n"
                        allHeader   = all.header
                    }
                }
            }
        }
        if txtMonthly.count > 0 {
            let title:String = "逐月已實現損益(%)"
            for (idx,h) in allHeader.enumerated() {
                if let d = twDateTime.dateFromString(h + "/01") {
                    if h.suffix(2) == "01" {
                        allHeader[idx] = twDateTime.stringFromDate(d, format: "yyyy/M月")
                    } else {
                        allHeader[idx] = twDateTime.stringFromDate(d, format: "M月")
                    }
                }
            }
            
            //計算逐月合計，只能等全部股都合併完成後才好合計
            var sumMonthly:[Double]=[]  //月別合計
            let txtBody:[String] = txtMonthly.components(separatedBy: CharacterSet.newlines) as [String]
            for b in txtBody {
                let txtROI:[String] = b.components(separatedBy: ", ") as [String]
                for (idx,r) in txtROI.enumerated() {
                    var roi:Double = 0
                    if let dROI = Double(r) {
                        roi = dROI
                    }
                    if idx >= 2 {   //前兩欄是簡稱和本金，故跳過
                        let i = idx - 2
                        if i == sumMonthly.count {
                            sumMonthly.append(roi)
                        } else {
                            sumMonthly[i] += roi
                        }
                    }
                }
            }
            let txtSummary = "合計,," + (sumMonthly.map{String(format:"%.1f",$0)}).joined(separator: ", ")
            
            //把文字通通串起來
            let allHeader = allHeaderX2 + allHeader //冠上之前保存的前兩欄標題，即簡稱和本金
            let txtHeader = (allHeader.map{String($0)}).joined(separator: ", ") + "\n"
            text = "\(txtHeader)\(txtMonthly)\(txtSummary)\n\n\(title)\n" //最後空行可使版面周邊的留白對稱
        }

        return text
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

    var simDefaults:(first:Date,start:Date,money:Double,invest:Double,text:String) {
        let defaults = sim.simDefaults
        let startX = twDateTime.stringFromDate(defaults.start,format: "起始日yyyy/MM/dd")
        let moneyX = String(format:"起始本金%.f萬元",defaults.money)
        let investX = (defaults.invest > 9 ? "自動無限加碼" : (defaults.invest > 0 ? String(format:"自動%.0f次加碼", defaults.invest) : ""))
        let txt = "新股預設：\(startX) \(moneyX) \(investX)"
        return (defaults.first, defaults.start, defaults.money, defaults.invest, txt)
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
    
    func applySetting (_ stock:Stock?=nil, dateStart:Date,moneyBase:Double,autoInvest:Double, applyToGroup:Bool?=false, applyToAll:Bool, saveToDefaults:Bool) {
        var stocks:[Stock] = []
        if let st = stock {
            if let ag = applyToGroup, ag == true {
                for g in groupStocks {
                    if g[0].group == st.group {
                        for s in g {
                            stocks.append(s)
                        }
                    }
                }
            } else {
                stocks.append(st)
            }
        } else if applyToAll {
            stocks = sim.stocks
        }
        if stocks.count > 0 {
            sim.settingStocks(stocks, dateStart: dateStart, moneyBase: moneyBase, autoInvest: autoInvest)
        }
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
            simLog.shrinkLog(200)
            self.versionLast = UserDefaults.standard.string(forKey: "simStockVersion") ?? ""
            if sim.simTesting {
                sim.runTest()
            } else {
                UserDefaults.standard.set(versionNow, forKey: "simStockVersion")
                sim.request.downloadStocks()
                var action:simDataRequest.simTechnicalAction? {
                    if UserDefaults.standard.bool(forKey: "simResetAll") {
                        UserDefaults.standard.removeObject(forKey: "simResetAll")
                        return .simResetAll
                    } else if versionLast != versionNow {
                        let lastNo = (versionLast == "" ? "" : versionLast.split(separator: ".")[0])
                        let thisNo = versionNow.split(separator: ".")[0]
                        if lastNo != thisNo || buildNo == "0" || versionLast == "" {
                            return .tUpdateAll      //改版後需要重算技術值時，應另起版號其build為0或留空
                        } else {
                            return .simResetAll     //否則就只會重算模擬，即使另起新版其build不為0或留空
                        }
                    }
                    return nil  //其他由現況來判斷
                }
                DispatchQueue.global().async {
                    self.sim.request.downloadTrades(self.sim.stocks, requestAction: action)
                }
            }
//        case UIApplication.didEnterBackgroundNotification:
//            simLog.addLog("=== appDidEnterBackground ===")
        case UIApplication.willResignActiveNotification:
            simLog.addLog ("=== appWillResignActive ===")
            self.sim.request.invalidateTimer()
        default:
            break
        }

    }
    
    func reviseWithTWSE(_ stocks:[Stock]?=nil, bgTask:BGTask?=nil) {
        let requestStocks = stocks ?? sim.stocks
        DispatchQueue.global().async {
            self.sim.request.reviseWithTWSE(requestStocks, bgTask: bgTask)
        }
    }

    
}

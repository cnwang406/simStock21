//
//  simStock.swift
//  simStock
//
//  Created by peiyu on 2017/12/18.
//  Copyright © 2017年 unlock.com.tw. All rights reserved.
//

import Foundation

//股群的下載和計算進度、介面和清單狀態等控制
class simStock: NSObject {

// >>>>>>>>>> ＊＊＊＊＊ 版本參數 ＊＊＊＊＊ >>>>>>>>>>

    var simTesting:Bool = false     //執行模擬測試 = false >>> 注意updateMA是否省略？ <<<
    let justTestIt:Bool = true      //simTesting時，不詢問直接執行13年測試
    let simTestDate:Date? = nil     //twDateTime.dateFromString("2019/07/01")

    let defaultYears:Int    = 3     //預設起始3年前 = 3
    let defaultMoney:Double = 50    //本金50萬元  = 50
    let defaultYearsMax:Int = 13    //起始日限10年內 = 10
    let defaultId:String = "2330"   //預設為2330
    let defaultName:String = "台積電"  //預設為台積電

    var simPrices:[String:simPrice] = [:]   //每支股票Id所對照的模擬參數
    var sortedStocks:[(id:String,name:String)] = []   //依股票名稱排序的模擬中股票清單
    var simId:String = ""                   //目前主畫面顯示的股票Id
    var simName:String = ""

    let defaults:UserDefaults = UserDefaults.standard
    let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    var versionLast:String  = ""    //上次記錄的程式版本 versionNow
    var versionNow:String   = ""    //versionNo + "," + buildNo

    var masterUI:masterUIDelegate?
    var Timelines:[Timeline] = []
    var TimelinesLiveDate:Date = Date.distantPast
    
    func getTimelines()->[Timeline] {
        if twDateTime.isDateInToday(TimelinesLiveDate) {
            return Timelines
        } else {
            let fetched = coreData.shared.fetchTimeline()
            Timelines = fetched.Timelines
            TimelinesLiveDate = Date()
            return fetched.Timelines
        }
    }

    func setSimId(newId:String) -> String {
        let oldId = simId
        if oldId != newId {
            simId = newId
            defaults.set(simId, forKey: "simId")
            if let name = simPrices[simId]?.name {
                simName = name
            }
            self.masterUI?.setSegment()
        }
        return oldId
    }

    func connectMasterUI(_ master:masterUIDelegate) {
        self.masterUI = master
        loadDefaults()  //先載入simPrices才能接下來指定masterUI
    }


    func loadDefaults() {
        
        versionNow = versionNo + (buildNo <= "1" ? "" : "(\(buildNo))")
        if let ver = defaults.string(forKey: "version") {
            versionLast = ver
            if versionLast < "3.2" {
                resetDefaults()
            }
        }

        if let Id = defaults.string(forKey: "simId") {
            if let simData = defaults.object(forKey: "simPrices") as? Data {
                simPrices = NSKeyedUnarchiver.unarchiveObject(with: simData) as! [String:simPrice]
            }
            for sim in Array(simPrices.values) {
                sim.connectMaster(self.masterUI)
            }
            sortedStocks = sortStocks()
            let _ = setSimId(newId: Id) //要等simPrices & sortedStocks好了，才能設定simId & simName
            if versionLast != versionNow  {
                self.masterUI?.nsLog("\(versionLast) -> \(versionNow)")
                self.setDefaults()
                self.timePriceDownloaded = Date.distantPast
                self.defaults.removeObject(forKey: "timePriceDownloaded")
                                
                //當資料庫欄位變動時，必須重算數值
                if versionLast < "3.4.1(3)" {
                    for sim in Array(self.simPrices.values) {
                        sim.timelineChecked = (Date.distantFuture,Date.distantPast)
                    }
                }
                if versionLast < "3.4(7)" {
                    self.masterUI?.nsLog("＊＊＊ 重算數值 ＊＊＊")
                    for sim in Array(self.simPrices.values) {
                        sim.resetSimUpdated()    //重算統計數值
                    }
                }
                //變更買賣規則時，才要重算模擬、重配加碼，清除反轉買賣
                if versionLast < "3.3.5" {
                    self.masterUI?.nsLog("＊＊＊ 清除反轉及重算模擬 ＊＊＊")
                    self.resetAllSimStatus()
                } else if versionLast < "3.4.1(3)" {
                    self.masterUI?.nsLog("＊＊＊ 重算模擬 ＊＊＊")
                    for id in simPrices.keys {
                        simPrices[id]!.willUpdateAllSim = true     //至少要重算模擬、重配加碼，但不清除反轉
                        simPrices[id]!.willResetMoney = true
                        simPrices[id]!.willGiveMoney = true
                        simPrices[id]!.willResetReverse = false
                        simPrices[id]!.maxMoneyMultiple = 0
                    }
                }
                
                defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")

            }
        } else {    //第一次，則建立預設股群
            setDefaults()
            let _ = addNewStock(id: defaultId, name: defaultName)
        }


        if let t = defaults.object(forKey: "timePriceDownloaded") {
            timePriceDownloaded = t as! Date
        }
    }

    func resetDefaults() {
        defaults.removeObject(forKey: "stockId")
        defaults.removeObject(forKey: "simStocks")
        defaults.removeObject(forKey: "dateDownloaded")
        defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期則下次搜尋時可重新下載清單
    }

    func setDefaults() {    //預設參數：起始本金、期間年、往前年限
        if defaults.object(forKey: "realtimeSource") == nil {   //打開從twse下載盤中價的開關
            defaults.set(true, forKey: "realtimeSource")
        }
        if defaults.object(forKey: "defaultMoney") == nil {
            defaults.set(defaultMoney, forKey: "defaultMoney")
        }
        if defaults.object(forKey: "defaultYears") == nil {
            defaults.set(defaultYears, forKey: "defaultYears")            
        }
        defaults.set(defaultYearsMax, forKey: "defaultYearsMax")
        defaults.set(versionNow,      forKey: "version")
        defaults.removeObject(        forKey: "dateStockListDownloaded")   //清除日期則下次搜尋時可重新下載清單
    }


    func addNewStock(id:String,name:String) -> [String:simPrice] {
        if simPrices[id] == nil {
            simPrices[id] = simPrice(id: id, name: name, master:self.masterUI)
            sortedStocks = sortStocks()
            self.masterUI?.nsLog ("\(id)\(simPrices[id]!.name) \tadded to simPrices.")
        }
        let _ = setSimId(newId: id)
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
        return simPrices
    }
    
    func addNewStocks(_ stock:[(id:String,name:String)]) {
        for s in stock {
            if simPrices[s.id] == nil {
                simPrices[s.id] = simPrice(id: s.id, name: s.name, master:self.masterUI)
                self.masterUI?.nsLog ("\(s.id)\(simPrices[s.id]!.name) \tadded to simPrices.")
            } else if let s = simPrices[s.id] {
                if s.paused {
                    s.paused = false
                    s.resetToDefault()
                }
            }
        }
        sortedStocks = sortStocks()
        if let s = stock.last {
            let _ = setSimId(newId: s.id)
        }
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
    }

    func sortStocks(includePaused:Bool=false) -> [(id:String,name:String)] {
        var unSorted:[(id:String,name:String)] = []
        for id in simPrices.keys {
            if !simPrices[id]!.paused || includePaused {
                unSorted.append((id,simPrices[id]!.name))
            }
        }
        if includePaused {
            return unSorted.sorted{$0.name<$1.name}
        } else {    //sortedStocks一定是只有模擬中的而不含暫停模擬的
            sortedStocks = unSorted.sorted{$0.name<$1.name}
            segmentedByFirstCharacter(sortedStocks)
            return sortedStocks
        }

    }

    var segment:[String] = []               //首字
    var segmentId:[String:String] = [:]     //首字 -> Id
    var segmentIndex:[String:Int] = [:]     //Id  -> 首字的Index
    func segmentedByFirstCharacter(_ sorted:[(id:String,name:String)]) {
        segment = []           //首字
        segmentId = [:]        //首字 -> Id
        segmentIndex = [:]     //Id  -> 首字的Index
        var last:String = ""
        for s in sorted {
            if let s0 = s.name.first {
                let s1:String = String(s0)
                if s1 != last {
                    segment.append(s1)
                    segmentId[s1] = s.id
                }
                last = s1
            }
            segmentIndex[s.id] = segment.count - 1
        }
    }
    
    func pausePriceSwitch(_ id:String) -> [String:simPrice] {
        //shiftLeft --> setSimId(只有simId不同時) --> setSegment
        if simId == id && !simPrices[id]!.paused {  //將由模擬中改為暫停則需先切換主畫面simId
            let _ = shiftLeft() //至少還有1個模擬中的股可以把simId切換過去
        }
        simPrices[id]!.paused = !simPrices[id]!.paused
        simPrices[id]!.resetToDefault()
        sortedStocks = self.sortStocks()
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
        if !simPrices[id]!.paused {
            let _ = self.setSimId(newId: id)    //simId是新的就必然會執行到setSegment
        } else {
            self.masterUI?.setSegment()
        }
        return simPrices
    }

    func removeStock(_ id:String) -> [String:simPrice] {
        if let sim = simPrices[id] {
            if simId == defaultId && simPrices.count == 1 { //反正刪除預設股還得加回來，不如別刪了
                self.masterUI?.nsLog ("\(id)\(sim.name) \tskip removing the one simPrice.")
                return simPrices
            }
            self.masterUI?.nsLog ("\(id)\(sim.name) \tremoving from simPrices(\(simPrices.count)).")
            if simId == id {        //先切換simId不然稍後被刪就不知隔壁是誰了，刪後setSegment只好重複執行
                let _ = shiftLeft() //也有可能只剩1支股切換了simId不會變，而且稍後就被刪了
            }
            sim.deletePrice()
            simPrices.removeValue(forKey: id)
            if simPrices.count == 0 {
                let _ = addNewStock(id: defaultId, name: defaultName)
            }
            sortedStocks = self.sortStocks()
            defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期以強制重載股票清單
            defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
            self.masterUI?.setSegment()
        }
        return simPrices

    }
    

    func copySimPrice(_ simSource:simPrice) -> simPrice {
        let simData = NSKeyedArchiver.archivedData(withRootObject: simSource)
        let simPrice = NSKeyedUnarchiver.unarchiveObject(with: simData) as! simPrice
        if let _ = self.masterUI {
            simPrice.connectMaster(self.masterUI)
        }
        return simPrice
    }


    func resetAllSimStatus() {
        for id in Array(self.simPrices.keys) {
            self.simPrices[id]!.resetSimStatus()
        }
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")

    }

//    下載股票排行於Google SpreadSheets，使用試算表函數產生測試股群名單
//    A2=9904
//    B2=寶成
//    C2="let _ = addNewStock("&char(34)&A2&char(34)&", name:"&char(34)&B2&char(34)&")"
    
    func addTestStocks(_ group:String) {
        switch group {
        case "Test10":
            let stocks:[(id:String,name:String)] = [
                (id:"1590", name:"亞德客-KY"),
                (id:"2474", name:"可成"),
                (id:"3406", name:"玉晶光"),
                (id:"2912", name:"統一超"),
                (id:"9910", name:"豐泰"),
                (id:"2330", name:"台積電"),
                (id:"2327", name:"國巨"),
                (id:"9914", name:"美利達"),
                (id:"2377", name:"微星"),
                (id:"1476", name:"儒鴻")
            ]
            addNewStocks(stocks)

        case "Test35":
            let stocks:[(id:String,name:String)] = [
                (id:"2324", name:"仁寶"),
                (id:"1227", name:"佳格"),
                (id:"0050", name:"元大台灣50"),
                (id:"1303", name:"南亞"),
                (id:"1702", name:"南僑"),
                (id:"2332", name:"友訊"),
                (id:"2409", name:"友達"),
                
                (id:"1301", name:"台塑"),
                (id:"6505", name:"台塑化"),
                (id:"3045", name:"台灣大"),
                (id:"2308", name:"台達電"),
                (id:"1536", name:"和大"),
                (id:"4938", name:"和碩"),
                (id:"1312", name:"國喬"),
                (id:"2327", name:"國巨"),
                (id:"2882", name:"國泰金"),
                (id:"2371", name:"大同"),
                (id:"2353", name:"宏碁"),
                (id:"2498", name:"宏達電"),
                (id:"9921", name:"巨大"),
                
                (id:"2376", name:"技嘉"),
                (id:"6414", name:"樺漢"),
                (id:"2395", name:"研華"),
                (id:"1216", name:"統一"),
                (id:"3231", name:"緯創"),
                
                (id:"2454", name:"聯發科"),
                (id:"1229", name:"聯華"),
                (id:"2303", name:"聯電"),
                (id:"3450", name:"聯鈞"),
                (id:"1605", name:"華新"),
                (id:"2357", name:"華碩"),
                (id:"2344", name:"華邦電"),
                (id:"2201", name:"裕隆"),
                (id:"2731", name:"雄獅"),
                (id:"2317", name:"鴻海")
            ]
            addNewStocks(stocks)

        case "TW50":    //根據[維基百科「台灣50指數」](https://zh.wikipedia.org/wiki/台灣50指數)
            let stocks:[(id:String,name:String)] = [
                (id:"2301", name:"光寶科"),
                (id:"2303", name:"聯電"),
                (id:"2308", name:"台達電"),
                (id:"2317", name:"鴻海"),
                (id:"2327", name:"國巨"),
                (id:"2330", name:"台積電"),
                (id:"2354", name:"鴻準"),
                (id:"2357", name:"華碩"),
                (id:"2382", name:"廣達"),
                (id:"2395", name:"研華"),
                (id:"2408", name:"南亞科"),
                (id:"2409", name:"友達"),
                (id:"2412", name:"中華電"),
                (id:"2454", name:"聯發科"),
                (id:"2474", name:"可成"),
                (id:"2492", name:"華新科"),
                (id:"3008", name:"大立光"),
                (id:"3045", name:"台灣大"),
                (id:"3711", name:"日月光"),
                (id:"3481", name:"群創"),
                (id:"4904", name:"遠傳"),
                (id:"4938", name:"和碩"),

                (id:"1101", name:"台泥"),
                (id:"1102", name:"亞泥"),
                (id:"1216", name:"統一"),
                (id:"1301", name:"台塑"),
                (id:"1303", name:"南亞"),
                (id:"1326", name:"台化"),
                (id:"1402", name:"遠東新"),
                (id:"2002", name:"中鋼"),
                (id:"2105", name:"正新"),
                (id:"2633", name:"台灣高鐵"),
                (id:"2912", name:"統一超"),
                (id:"6505", name:"台塑化"),
                (id:"9904", name:"寶成"),

                (id:"2801", name:"彰銀"),
                (id:"2823", name:"中壽"),
                (id:"2880", name:"華南金"),
                (id:"2881", name:"富邦金"),
                (id:"2882", name:"國泰金"),
                (id:"2883", name:"開發金"),
                (id:"2884", name:"玉山金"),
                (id:"2885", name:"元大金"),
                (id:"2886", name:"兆豐金"),
                (id:"2887", name:"台新金"),
                (id:"2890", name:"永豐金"),
                (id:"2891", name:"中信金"),
                (id:"2892", name:"第一金"),
                (id:"5871", name:"中租KY"),
                (id:"5880", name:"合庫金")
            ]
            addNewStocks(stocks)
            
        case "t00":
            let _ = addNewStock(id:"t00",name:"*加權指")
            
        default:
            break
        }
        
    }
    


    func shiftRight() -> Bool {
        var shiftToId:String = simId
        if let index = sortedStocks.firstIndex(where: {$0.id == simId}) {
            if index < sortedStocks.count - 1 {
                shiftToId = sortedStocks[index+1].id
            } else {        //循環到首筆
                if index != 0 { //有首筆而且不是自己
                    shiftToId = sortedStocks[0].id
                }   //else 首筆是自己而且沒有下一筆，那就不需要動作
            }
        } else {
            if sortedStocks.count > 0 {
                shiftToId = sortedStocks[0].id
            }
        }
        if shiftToId != simId {
            let _ = setSimId(newId: shiftToId)
            return true
        } else {
            return false
        }
    }


    func shiftLeft() -> Bool {
        var shiftToId:String = simId
        if let index = sortedStocks.firstIndex(where: {$0.id == simId}) {
            if index > 0 {
                shiftToId = sortedStocks[index-1].id
            } else {        //循環到末筆
                shiftToId = sortedStocks[sortedStocks.count-1].id
            }
        } else {
            if sortedStocks.count > 0 {
                shiftToId = sortedStocks[0].id
            }
        }
        if shiftToId != simId {
            let _ = setSimId(newId: shiftToId)
            return true
        } else {
            return false
        }
    }


    let dispatchGroupSimTesting:DispatchGroup = DispatchGroup()
    func runSimTesting(fromYears:Int,forYears:Int=2,loop:Bool=true) {
        if fromYears % 3 == 1 {
            masterUI?.systemSound(1113)
        }
        dispatchGroupSimTesting.enter()
        OperationQueue().addOperation {
            for (id,_) in self.sortedStocks {
                self.simPrices[id]!.resetToDefault(fromYears:fromYears, forYears:forYears)
            }
            let testMode:String = (forYears >= 10 ? "maALL" : "all") //10年只有為了重算Ma
            self.setupPriceTimer(mode:testMode)
        }
        dispatchGroupSimTesting.notify(queue: DispatchQueue.main, execute: {
            let loopYears = fromYears - 1
            if loopYears >= 2 && loop {    //模擬到2年前時停止
                self.runSimTesting(fromYears: loopYears,forYears: forYears)
            } else {
                self.resetSimTesting()
            }
        })
    }


    func resetSimTesting() {
        if simTesting {
            masterUI?.systemSound(1114)
            if let simData = defaults.object(forKey: "simPrices") as? Data {
                simPrices = NSKeyedUnarchiver.unarchiveObject(with: simData) as! [String:simPrice]
            }
            for (id,_) in self.sortedStocks {
                self.simPrices[id]!.connectMaster(self.masterUI)
                self.simPrices[id]!.resetAllProperty()
                self.simPrices[id]!.resetSimStatus()
            }
            defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
            defaults.removeObject(forKey: "timePriceDownloaded")
            simTesting = false
            self.masterUI?.nsLog("== simTesting reseted ==\n")
        }
    }


    //
    //
    //
    //
    //
    //
    //  更新股價的Timer
    //
    //
    //
    //
    //
    //

    var priceTimer:Timer = Timer()
    var todayIsNotWorkingDay:Bool = false   //今天是休市日
    var timePriceDownloaded:Date = Date.distantPast //上次下載股價的時間
    var mainSource:String  = "cnyes"  //cnyes, twse
    var realtimeSource:String = "twse"
    let wasRealtimeSource:[String] = ["Google","Yahoo","yahoo","twse"]
    var realtimeInterval:TimeInterval = 270
    var switchToYahoo:Bool = false

    func isTodayOffDay(_ value:Bool?=nil) -> Bool { //true=休市日
        if let v = value {
            todayIsNotWorkingDay = v
        }
        return todayIsNotWorkingDay
    }

    func needPriceTimer() -> Bool {
        var needed:Bool = false
        let y1332 = twDateTime.time1330(twDateTime.yesterday(), delayMinutes: 2)
        let time1332 = twDateTime.time1330(delayMinutes: 2)
        let time0850 = twDateTime.time0900(delayMinutes: -2)
        if (todayIsNotWorkingDay && twDateTime.isDateInToday(timePriceDownloaded)) {
            self.masterUI?.nsLog("休市日且今天已更新。")
        } else if (timePriceDownloaded.compare(y1332) == .orderedDescending && Date().compare(time0850) == .orderedAscending) {
            self.masterUI?.nsLog("今天還沒開盤且上次更新是昨收盤後。")
        } else if timePriceDownloaded.compare(time1332) == .orderedDescending {
            self.masterUI?.nsLog("上次更新是今天收盤之後。")
        } else if self.simTesting {
            self.masterUI?.nsLog("執行模擬測試。")
        } else {
            needed = true
        }
        return needed
    }

    var goModeAll:Bool = false
    func whichMode() -> String {
        if self.timePriceDownloaded.compare(twDateTime.time0900(delayMinutes:2)) == .orderedDescending && self.timePriceDownloaded.compare(twDateTime.time1330(delayMinutes:2)) == .orderedAscending && !goModeAll {
            return "realtime"
        } else {
            goModeAll = false
            return "all"
        }
    }


    //modePriority: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
    let modePriority:[String:Int] = ["":1,"realtime":2,"simOnly":3,"all":4,"maALL":5,"retry":6,"reset":7]

    func setupPriceTimer(_ id:String="",mode:String="all",delay:TimeInterval=0) {
        
        var timerDelay:TimeInterval = delay
        var timerMode:String = mode
        var timerId:String = id
        
        DispatchQueue.main.async {
            if self.priceTimer.isValid {    //若已有作用中的timer取得諸元重排
                if let u = self.priceTimer.userInfo {
                    let uInfo = u as! (id:String,mode:String,delay:TimeInterval)
                    if self.modePriority[uInfo.mode]! >= self.modePriority[mode]! {    //mode以先前uInfo為主
                        if (uInfo.id == "" || uInfo.id == id) && uInfo.delay <= timerDelay { //id也不變
                            return
                        } else {
                            timerMode   = uInfo.mode
                            if uInfo.mode == "reset" || uInfo.id == id {  //reset必須指定id，才不會造成全部清除
                                timerId = uInfo.id
                            } else {
                                timerId = ""
                            }
                            if uInfo.delay < timerDelay {            //delay取較小者
                                timerDelay  = uInfo.delay
                            }
                        }
                    } else {    //以新mode,delay為主，除非先前的uInfo.id,uInfo.delay範圍較小
                        timerMode = mode
                        if mode == "reset" || uInfo.id == id {
                            timerId  = id
                        } else {
                            timerId  = ""
                        }
                        if timerDelay > uInfo.delay {
                            timerDelay = uInfo.delay
                        }
                    }   //if self.modePriority[uInfo.mode]!
                    let uInfoIdTitle = (uInfo.id == "" ? "" : " for:\(uInfo.id)")
                    self.masterUI?.nsLog("priceTimer: \t\(uInfo.mode)\(uInfoIdTitle) in \(uInfo.delay)s will be invalidated.")
                }   //if let u = self.priceTimer.userInfo
                
                self.priceTimer.invalidate()
            }   //if self.priceTimer.isValid
            
            if self.needPriceTimer() || self.modePriority[timerMode]! > 2 {
                let userInfo:(id:String,mode:String,delay:TimeInterval) = (timerId,timerMode,timerDelay)
                self.priceTimer = Timer.scheduledTimer(timeInterval: timerDelay, target: self, selector: #selector(simStock.updatePriceByTimer(_:)), userInfo: userInfo, repeats: false)
                var forId = ""
                if let sim = self.simPrices[timerId] {
                    forId = " for: \(timerId)\(sim.name)"
                }
                self.masterUI?.nsLog("priceTimer\t:\(mode)\(forId) in \(timerDelay)s.")
                self.masterUI?.setIdleTimer(timeInterval: -2)    //立即停止休眠
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5), execute: {Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(simStock.updateCountdown(_:)), userInfo: nil, repeats: true)})
            } else {
                self.priceTimer.invalidate()
                self.masterUI?.nsLog("priceTimer stop, idleTimer in 1min.\n")
                self.masterUI?.setIdleTimer(timeInterval: 60)    //不需要更新股價，就60秒恢復休眠眠排程
            }
            
            if #available(iOS 12.0, *) {
                self.masterUI?.masterSelf().donatePriceTimer()
            }
        }   //OperationQueue
    }
    
    @objc func updateCountdown (_ timer:Timer) {
        if self.priceTimer.isValid {
            let timeLeft = self.priceTimer.fireDate.timeIntervalSinceNow + timer.timeInterval - 1 //減1留1秒的顯示時間
            if timeLeft >= 0 {
                if !isUpdatingPrice {
                    let mm:Int = Int(floor(timeLeft/60))
                    let ss:Int = Int(timeLeft) % 60
                    let userInfo = self.priceTimer.userInfo as! (id:String,mode:String,delay:TimeInterval)
                    let msgMode = (userInfo.mode == "retry" ? "未完重試" : "即將更新")
                    let msg = String(format:"\(msgMode) %02d:%02d",mm,ss)
                    masterUI?.messageWithTimer(msg,seconds: (timeLeft < 2 ? 2 : 0))
                }
            } else {
                timer.invalidate()
            }
        } else {
            timer.invalidate()
        }
     }

    


    var timerFailedCount:Int = 0
    @objc func updatePriceByTimer(_ timer:Timer) {
        let uInfo:(id:String,mode:String,delay:TimeInterval) = timer.userInfo as! (id:String,mode:String,delay:TimeInterval)
        priceTimer.invalidate()
        let yesterday1332 = twDateTime.time1330(twDateTime.yesterday(),delayMinutes: 2)
        let overNightRealtime:Bool = self.modePriority[uInfo.mode]! <= 2 && timePriceDownloaded.compare(yesterday1332) == .orderedAscending && uInfo.mode != "all"
        let noNetwork:Bool = !NetConnection.isConnectedToNetwork()
        if noNetwork {
            masterUI?.messageWithTimer("沒有網路",seconds: 10)
        }
        if overNightRealtime {    //因為休眠而持續前日的realtime排程的話，應改為all
            setupPriceTimer(uInfo.id, mode:"all", delay:uInfo.delay)
        } else if updatedPrices.count > 0 || self.isUpdatingPrice || (noNetwork && uInfo.mode != "simOnly") {
            timerFailedCount += 1
            var delay:TimeInterval = 5  //第1次重試等5秒
            if timerFailedCount >= 2 {
                if timerFailedCount == 2 {
                    delay = 10
                } else {
                    delay = 15
                    timerFailedCount = 0
                }
            }
            setupPriceTimer(uInfo.id, mode:uInfo.mode, delay:delay) //已經更新中就把下一個排程要求延後
            let reason:String = {
                var rs:String = ""
                if self.isUpdatingPrice {
                    rs += " 因正在更新中。"
                }
                if updatedPrices.count > 0 {
                    rs += " updatedPrices=\(updatedPrices.count)\n\(updatedPrices)。"
                }
                if noNetwork {
                    rs += " 無網路。"
                }
                return rs
            }()
            self.masterUI?.nsLog("updatePriceByTimer: \(uInfo.mode) failed [\(timerFailedCount)], reset in \(delay)s. \(reason)")
        } else {
            var forId = ""
            var solo:Bool = false
            if uInfo.id != "" {
                solo = true
                forId = "for: \(uInfo.id)\(self.simPrices[uInfo.id]!.name)"
            }
            self.masterUI?.nsLog("updatePriceByTimer: \(uInfo.mode) \(forId) \(solo ? "solo" : "")")
            downloadAndUpdate(uInfo.id, mode:uInfo.mode, solo: solo)    //都沒問題就去下載更新
        }

    }
    
    

    //
    //
    //
    //
    //
    //
    //  下載及更新股價
    //
    //
    //
    //
    //
    //

    var isUpdatingPrice:Bool = false
    var twseTask:[String:String] = [:]

    func downloadAndUpdate(_ id:String="", mode:String="all", solo:Bool=false) {
        //mode: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
        var forId = ""
        if id != "" {
            forId = "for: \(id)\(self.simPrices[id]!.name)"
        }
        self.masterUI?.nsLog("downloadAndUpdate \t:\(mode) \(forId) \(solo ? "solo" : "")")
        var modeText:String = ""
        switch mode {
        case "realtime":
            modeText = "查詢成交價"
        case "retry":
            modeText = "重試未完下載"
        case "all","maALL":
            if simTesting {
                modeText = "模擬測試"
            } else {
                modeText = "查詢收盤價"
            }
        case "reset":
            modeText = "重新下載"
        default:
            modeText = "統計更新"
        }

        self.masterUI?.lockUI(modeText, solo:solo)
        if solo {    //單一股查詢
            self.simPrices[id]!.downloadPrice(mode, source:(self.mainSource,self.realtimeSource), solo: true)
        } else {
            //modePriority: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
            if mainSource == "twse" && modePriority[mode]! >= 4 {
                for (sId,_) in sortedStocks {
                    twseTask[sId] = mode
                }
                if let sId = twseTask.keys.first {  //twse是從第1個開始丟出查詢，完畢時才逐次接續
                    self.simPrices[sId]!.downloadPrice(mode, source:(self.mainSource,self.realtimeSource))
                }
            } else {
                var t00Exists:Bool = false
                var t00:simPrice?
                if let xtai = self.simPrices["t00"] {
                    if !xtai.paused {
                        t00Exists = true
                        t00 = xtai
                    }
                }
                if t00Exists && timePriceDownloaded.timeIntervalSinceNow < -180 {
                    for (sId,_) in sortedStocks {
                        twseTask[sId] = mode    //稍後setProgress會把這些股於TAIEX完成後丟出查詢
                    }
                    t00!.downloadPrice(mode, source:(self.mainSource,self.realtimeSource))
                } else {
                    for (sId,_) in sortedStocks { //沒有xtai故可放心直接丟出查詢
                        self.simPrices[sId]!.downloadPrice(mode, source:(self.mainSource,self.realtimeSource))
                    }
                }
            }
        }
        timePriceDownloaded = Date()

    }

    var progressStop:Float = 0
    var updatedPrices:[String] = [] //已完成更新股價的股票id
    func setProgress(_ id:String, progress:Float, message:String="", solo:Bool=false) { //progress == -1 表示沒有執行什麼，跳過
        DispatchQueue.main.async {
            var msg:String = ""
            let absProgress:Float = abs(progress)
            let idTitle:String = {
                if let s = self.simPrices[id] {
                    return "\(id)\(s.name)"
                } else {
                    return "id"
                }
            }()


            //顯示已更新哪個股的訊息
            if absProgress == 1 && !solo {
                //全部更新中，有1支已完成
                if self.updatedPrices.contains(id) {
                    self.masterUI?.nsLog("\(idTitle) * updatedPrices重複？\(self.updatedPrices) \(solo ? "solo" : "")")
                } else {
                    self.updatedPrices.append(id)
                }
                if self.updatedPrices.count == 1 || self.updatedPrices.count == self.sortedStocks.count {
                    self.masterUI?.nsLog("\(idTitle) \tsetProgress \(progress) updatedPrices = \(self.updatedPrices.count) / \(self.sortedStocks.count) \(solo ? "solo" : "")")
                }
                if progress == 1 {
                    msg = "\(idTitle)(\(self.updatedPrices.count)/\(self.sortedStocks.count))完成"
                } else {    //progress == -1 表示沒有執行什麼，跳過
                    msg = "\(idTitle)(\(self.updatedPrices.count)/\(self.sortedStocks.count))"
                }
                if self.twseTask.count > 0 {
                    self.twseTask.removeValue(forKey: id)
                    if self.mainSource == "twse" {  //source是twse必須逐股丟查詢
                        if let sId = self.twseTask.keys.first {
                            if let mode = self.twseTask[sId] {
                                self.simPrices[sId]!.downloadPrice(mode, source:(self.mainSource,self.realtimeSource))
                            }
                        }
                    } else {    //source不是twse就可以全部股一起丟查詢
                        for sId in self.twseTask.keys { //把downloadAndUpdate放在twseTask的非twse股全部向cnyes丟出去
                            if let mode = self.twseTask[sId] {
                                self.simPrices[sId]!.downloadPrice(mode, source:(self.mainSource,self.realtimeSource))
                            }
                            self.twseTask.removeValue(forKey: sId)  //一次丟完隨即清空
                        }
                    }
                }
            }
            //更新進度條....
            if absProgress == 1 && (self.updatedPrices.count == self.sortedStocks.count || solo) {
                //已完成這一輪更新
                if id == "t00" {
                    self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
                }
                if !solo {
                    msg = "完成 \(twDateTime.stringFromDate(Date(),format: "HH:mm:ss"))"
                    self.defaults.set(self.timePriceDownloaded, forKey: "timePriceDownloaded")
                    var fromYears:String = ""
                    if self.simTesting {
                        let firstId:String = self.sortedStocks[0].id
                        let simFirst:simPrice =  self.simPrices[firstId]!
                        if let y = twDateTime.calendar.dateComponents([.year], from: simFirst.dateStart, to: Date()).year {
                            fromYears = "第 \(String(describing: y)) 年起 "
                        }
                    }
                    let rois = self.roiSummary()
                    self.masterUI?.nsLog("== \(fromYears)\(rois.s1) ==")
                } else {
                    msg = message
                }
                if self.priceTimer.isValid {
                    let uInfo = self.priceTimer.userInfo as! (id:String,mode:String,delay:TimeInterval)
                    if uInfo.mode == "retry" {
                        msg = "未完，稍後重試"
                        if let t = self.defaults.object(forKey: "timePriceDownloaded") {
                            self.timePriceDownloaded = t as! Date
                        }
                    }
                }
                self.progressStop = 0
                self.masterUI?.unlockUI(msg) // <<<<<<<<<<< 這裡完成unlockUI，並恢復休眠 <<<<<<<<<<<
                if self.checkingDate == Date.distantPast && !self.switchToYahoo && !self.simTesting {
                    self.checkTimeline()
                }

                if self.simTesting {
                    self.dispatchGroupSimTesting.leave()
                } else {
                    if self.needPriceTimer() {  //09:05之前都不能放心的說是realtimeOnly
                        if self.switchToYahoo {
                            self.realtimeInterval = 0
                            self.realtimeSource = "yahoo"
                            self.switchToYahoo  = false
                        } else {
                            self.realtimeInterval = 270
                            self.realtimeSource = "twse"
                        }
                        self.setupPriceTimer(mode:self.whichMode(), delay:self.realtimeInterval)
                    }
                }
            } else {  //else if absProgress == 1 && (self.updatedPrices ==
                //未完成則顯示進度條
                self.masterUI?.setIdleTimer(timeInterval: -2)
                let allProgress:Float = (solo ? absProgress : (Float(self.updatedPrices.count) + absProgress) / Float(self.sortedStocks.count))
                if self.progressStop <= allProgress {
                    self.progressStop = allProgress
                }
                if message.count > 0 {
                    msg = message
                }
                self.masterUI?.setProgress(self.progressStop,message:msg)
            }
        }   //mainQueue.addOperation()
    }


    var checkingDate:Date = Date.distantPast
    func checkTimeline() {
        if self.simTesting {
            return
        }
        DispatchQueue.global().async {
            var checkedFrom:Date = Date.distantFuture
            var checkedTo:Date = Date.distantPast
            let fetched = coreData.shared.fetchTimeline(asc: true)
            if fetched.Timelines.count > 0 {
                for sim in self.simPrices {
                    let s = sim.value
                    if !s.paused {
                        if s.timelineChecked.from.compare(checkedFrom) == .orderedDescending || checkedFrom == Date.distantFuture {
                            checkedFrom = s.timelineChecked.from
                        }
                        if s.timelineChecked.to.compare(checkedTo) == .orderedAscending || checkedTo == Date.distantPast {
                            checkedTo = s.timelineChecked.to
                        }
                    }
                }
                var cnt:Int = 0
                for timeline in fetched.Timelines {
                    let t = timeline.date
                    cnt += 1
                    if t.compare(self.checkingDate) == .orderedAscending || (t.compare(checkedFrom) == .orderedDescending && t.compare(checkedTo) == .orderedAscending) {
                        continue
                    }
                    self.checkingDate = t
                    if cnt % 100 == 0 || cnt == fetched.Timelines.count {
                        let prg = Float(cnt) / Float(fetched.Timelines.count)
                        let msg = "查驗缺漏(\(cnt)/\(fetched.Timelines.count))"
                        self.masterUI?.setProgress(prg, message: msg)
//                        self.masterUI?.nsLog("查驗缺漏(\(cnt)/\(fetched.Timelines.count))")
                    }
                    if let tradePrice = timeline.tradePrice {
                        for sim in self.simPrices {
                            let s = sim.value
                            if s.paused {
                                continue
                            }
                            let d = s.dateRange()
                            if (t.compare(s.timelineChecked.from) == .orderedAscending || t.compare(s.timelineChecked.to) == .orderedDescending) && t.compare(twDateTime.startOfDay(d.earlier)) == .orderedDescending && t.compare(twDateTime.startOfDay(d.last)) != .orderedDescending && (t.compare(s.missed.first ?? Date.distantFuture) == .orderedAscending || t.compare(s.missed.last ?? Date.distantPast) == .orderedDescending) { //&& !tPrice.contains(sim.key)
                                var exist:Bool = false
                                for price in tradePrice {
                                    if price.id == sim.key {
                                        exist = true
                                        break
                                    }
                                }
                                if !exist {
                                    var i:Int = -1
                                    for (index,m) in s.missed.enumerated() {
                                        if m.compare(t) != .orderedDescending {
                                            i = index
                                        } else {
                                            break
                                        }
                                    }
                                    s.missed.insert(t, at: i+1)
                                } else {
                                    if let i = s.missed.firstIndex(of: t) {
                                        s.missed.remove(at: i)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            for sim in self.simPrices {
                if !sim.value.paused {
                    let dt = sim.value.dateRange()
                    sim.value.timelineChecked = (twDateTime.startOfDay(dt.first),twDateTime.endOfDay(dt.last))
                }
            }
            self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
            self.checkingDate = Date.distantPast
            self.masterUI?.setProgress(0, message: "")
        }
    }











    func roiSummary(forPaused:Bool=false, short:Bool=false) -> (s1:String,s2:String) {
        //累計
        var simCount:Int = 0
        var simROI:Double = 0
        var maxMultiple:Double = 0
        var simDays:Float = 0
        //目前
        var endCount:Int  = 0
        var endROI:Double = 0
        var endMultiple:Double = 0
        var endDays:Float = 0
        
        for id in self.simPrices.keys {
            if let sim = self.simPrices[id] {
                if id != "t00" && sim.paused == forPaused {
                    //累計
                    let roiTuple = sim.ROI()
                    if roiTuple.days != 0 {
                        simCount += 1
                        simROI   += roiTuple.roi
                        simDays  += roiTuple.days
                        maxMultiple += sim.maxMoneyMultiple
                    }
                    //目前
                    let endQtyInventory = (sim.getPriceEnd("qtyInventory") as? Double ?? 0)
                    let endQtySell      = (sim.getPriceEnd("qtySell") as? Double ?? 0)
                    if endQtyInventory > 0 || endQtySell > 0 {
                        let multiple = (sim.getPriceEnd("moneyMultiple") as? Double ?? 0)
                        endMultiple += multiple
                        let days = (sim.getPriceEnd("simDays") as? Float ?? 0)
                        endDays += days
                        if endQtySell > 0 {
                            endROI += (sim.getPriceEnd("simROI") as? Double ?? 0)
                        } else {
                            endROI += (sim.getPriceEnd("simUnitDiff") as? Double ?? 0)
                        }
                        endCount += 1
                    }
                }
            }
        }
        let eRoi:Double = (endCount > 0 ? endROI / Double(endCount) : 0)
        let eDays:Float = (endCount > 0 ? endDays / Float(endCount) : 0)
        let sRoi:Double = (simCount > 0 ? simROI / Double(simCount) : 0)
        let sDays:Float = (simCount > 0 ? simDays / Float(simCount) : 0)
        if short {  //目前持股的報酬率：給LINE日報用
            let summary:String = String(format:"\(endCount)支股平均 %.f天 %.1f%%",eDays,eRoi)
            return (summary,"")
        } else {    //全部股群的報酬率
            if self.simTesting {
                let summary1:String = String(format:"\(simCount)支股, 平均年報酬率:%.1f%%, 平均週期:%.f天",sRoi,sDays)
                return (summary1, "")
            } else {
                let summary1:String = String(format:"\(endCount)/\(simCount)支股, 平均年報酬率:%.1f%%/%.1f%%",eRoi,sRoi)
                let summary2:String = String(format:", 平均週期:%.f天/%.f天, 本金:x%.f/x%.f",eDays,sDays,endMultiple,maxMultiple)
                return (summary1, summary2)
            }
        }
    }


    func composeReport(isTest:Bool=false) -> String {
        var suggest:String = ""
        var suggestL:String = ""
        var suggestH:String = ""
        var dateReport:Date = Date.distantPast
        var isClosedReport:Bool = false
        var report:String = ""
        var sCount:Float = 0
        var sROI:Float = 0
        var sDays:Float = 0
        var header:String = ""
        
        //        func leftPadding(text:String ,toLength: Int, withPad character: Character) -> String {
        //            let newLength = text.count    //在固定長度的String左邊填空白
        //            if newLength < toLength {
        //                return String(repeatElement(character, count: toLength - newLength)) + text
        //            } else {
        //                return text
        //            }
        //        }

        for (id,name) in sortedStocks {
            if id != "t00" {
                if let sim = self.simPrices[id] {
                    let endDateTime = (sim.getPriceEnd("dateTime") as? Date ?? Date.distantPast)
                    if endDateTime.compare(twDateTime.time0900()) == .orderedDescending || isTest {
                        if endDateTime.compare(dateReport) == .orderedAscending || dateReport == Date.distantPast {
                            dateReport = endDateTime  //有可能某支股價格更新失敗，故取最早更新時間
                        }
                        isClosedReport = isTest || dateReport.compare(twDateTime.time1330(dateReport)) != .orderedAscending
                        let close:String = String(format:"%g",(sim.getPriceEnd("priceClose") as? Double ?? 0))
                        let time1220:Date = twDateTime.timeAtDate(hour: 12, minute: 20)
                        
                        //低買或高買建議
                        switch (sim.getPriceEnd("simRule") as? String ?? "") {
                        case "L":
                            if (endDateTime.compare(time1220) == .orderedDescending || isTest) {
                                suggestL += "　　" + name + " (" + close + ")\n"
                            }
                        case "H":
                            if (endDateTime.compare(time1220) == .orderedDescending || isTest) {
                                    suggestH += "　　" + name + " (" + close + ")\n"

                            }
                        default:
                            break
                        }
                    
                        //日報或月報
                        var action:String = " "
                        let endQtyBuy       = (sim.getPriceEnd("qtyBuy") as? Double ?? 0)
                        let endQtySell      = (sim.getPriceEnd("qtySell") as? Double ?? 0)
                        let endQtyInventory = (sim.getPriceEnd("qtyInventory") as? Double ?? 0)
                        if endQtyBuy > 0 && (endDateTime.compare(time1220) == .orderedDescending || isTest) {
                            action = "買"
                        } else if endQtySell > 0 {
                            action = "賣"
                        } else if endQtyInventory > 0 {
                            action = "" //為了日報文字不要多出空白，所以有「餘」時為空字串，而空白才是沒有狀況
                        }
                        if action != " " && (action != "" || isClosedReport) {
                            if report.count > 0 {
                                report += "\n"
                            }
                            let endSimDays = (sim.getPriceEnd("simDays") as? Float ?? 0)
                            let d = (endSimDays == 1 ? " 第" : "") + String(format:"%.f",endSimDays) + "天"
                            report += name + " (" + close + ") " + action + d
                            if action == "賣" {
                                let roi  = round(10 * (sim.getPriceEnd("simROI") as? Double ?? 0)) / 10
                                report += String(format:" %g%%",roi)
                                sROI += Float(roi)
                            } else if action == "" || endSimDays > 1 {
                                //餘，只會在isClosedReport即收盤後才輸出
                                //買，只有補買才輸出報酬率
                                let roi  = round(10 * (sim.getPriceEnd("simUnitDiff") as? Double ?? 0)) / 10
                                report += String(format:" %g%%",roi)
                                sROI += Float(roi)
                            }
                            sCount += 1
                            sDays  += endSimDays
                        }
                    
                    }
                }
            }
        }
        suggest = (suggestL.count > 0 ? "低買：\n" + suggestL : "") + (suggestH.count > 0 ? (suggestL.count > 0 ? "\n" : "") + "高買：\n" + suggestH : "") + (report.count > 0 ? "\n" : "")
        if report.count > 0 {
            if isClosedReport { //收盤後加列本輪平均報酬率
                report += "\n\n" + roiSummary(short: true).s1
            }
            if let lastReportTime = self.defaults.object(forKey: "timeReported") as? Date {
                if  twDateTime.startOfMonth(lastReportTime).compare(twDateTime.startOfMonth(dateReport)) != .orderedSame || isTest {
                    var dateFrom:Date = dateReport
                    var dateTo:Date   = dateReport
                    if let dt = twDateTime.calendar.date(byAdding: .month, value: -3, to: dateReport) {
                        dateFrom = twDateTime.startOfMonth(dt)
                    }
                    if let dt = twDateTime.calendar.date(byAdding: .month, value: -1, to: dateReport) {
                        dateTo = twDateTime.endOfMonth(dt)
                    }   //隔月加列3個月的逐月已實現損益
                    report += "\n\n\n" + csvMonthlyRoi(from: dateFrom, to: dateTo, withTitle: true)
                }
            }
        }
        if report.count > 0 || suggest.count > 0 {
            if isClosedReport {
                header = "小確幸日報 \(twDateTime.stringFromDate(dateReport))：\n\n"
            } else {
                header = "小確幸提醒你：\n\n"
            }
            self.defaults.set(dateReport, forKey: "timeReported")
        }
        return (header + suggest + report)
    }

    /*
    func selfTalk() -> String {
        let todayNow = Date()
        let weekday = twDateTime.calendar.component(.weekday, from: todayNow)
        var talkMessage:String = "小確幸祝福你。"

        let time0830:Date = twDateTime.timeAtDate(todayNow, hour:08, minute:30)
        let time0900:Date = twDateTime.timeAtDate(todayNow, hour:09, minute:0)
        let time0930:Date = twDateTime.timeAtDate(todayNow, hour:09, minute:30)
        let time1100:Date = twDateTime.timeAtDate(todayNow, hour:11, minute:0)
        let time1330:Date = twDateTime.timeAtDate(todayNow, hour:13, minute:30)
        let time1430:Date = twDateTime.timeAtDate(todayNow, hour:14, minute:30)
        let time1900:Date = twDateTime.timeAtDate(todayNow, hour:19, minute:00)
        let time2200:Date = twDateTime.timeAtDate(todayNow, hour:22, minute:00)

        if !self.todayIsNotWorkingDay && todayNow.compare(time0900) == .orderedDescending && todayNow.compare(time0930) == .orderedAscending && weekday > 1 {
            talkMessage = "開盤了!"
        } else if !self.todayIsNotWorkingDay && todayNow.compare(time0830) == .orderedDescending && todayNow.compare(time0900) == .orderedAscending && weekday > 1 && weekday < 7   {
            talkMessage = "快要開盤了？"
        } else if !self.todayIsNotWorkingDay && todayNow.compare(time1330) == .orderedDescending && todayNow.compare(time1430) == .orderedAscending {
            talkMessage = "收盤了。"
        } else if todayNow.compare(time1100) == .orderedAscending {
            talkMessage = "早安。"
            if self.todayIsNotWorkingDay {
                talkMessage += "今天休市了？"
            }
        } else {
            let toNight:Bool = time1900.timeIntervalSinceNow / 3600 < 0.5  && time1900.timeIntervalSinceNow / 3600 > -3
            if toNight {    //晚上七點前0.5hr之後3hr都是晚安
                talkMessage = "晚安。"
            } else if time2200.timeIntervalSinceNow < 0 {
                talkMessage = "該睡了，晚安。"
            }
        }


        return talkMessage
    }
    */





    func csvSummary() -> String {
        var sumROI:Double = 0
        var simDays:Float = 0
        var sCount:Int = 0
        var text = "順序,代號,簡稱,期間(年),平均年報酬率(%),平均週期(天),最高本金倍數,停損次數\n"

        for (id,name) in self.sortedStocks {
            if id != "t00" {
                if let sim = simPrices[id] {
                    let roiTuple = sim.ROI()
                    sumROI  += roiTuple.roi
                    simDays += roiTuple.days
                    sCount  += 1
                    let roi     = String(format: "%.2f", roiTuple.roi)
                    let days    = String(format: "%.f", roiTuple.days)
                    let years   = String(format: "%.1f", roiTuple.years)
                    let cumulCut = (sim.getPriceEnd("cumulCut") as? Float ?? 0)
                    let cut     = (cumulCut > 0 ? String(format:"%.f",cumulCut) : "")
                    let multiple = sim.maxMoneyMultiple
                    let money   = String(format:"x%.f",multiple)
                    text += "\(sCount),'\(id),\(name),\(years),\(roi),\(days),\(money),\(cut)\n"
                }
            }
        }
        let avgROI:Double = sumROI / Double(sCount)
        let avgDays:Float = simDays / Float(sCount)
        text += String(format:"%d支股平均年報酬率 %.1f%% (平均週期%.f天)\n",sCount,avgROI,avgDays)

        return text
    }


    func csvMonthlyRoi(from:Date?=nil,to:Date?=nil,withTitle:Bool=false) -> String {
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
        for (id, _) in sortedStocks {
            if id != "t00" {
                let txt = self.simPrices[id]!.exportMonthlyRoi(from: from, to:to)
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
            let title:String = (withTitle ? "逐月已實現損益(%)：\n" : "")
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
            var sumAll:Double = 0       //總和
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
                        sumAll += roi
                    }
                }
            }
            let txtSummary = "合計,," + (sumMonthly.map{String(format:"%.1f",$0)}).joined(separator: ", ") + ", " + String(format:"%.1f",sumAll)
            
            //把文字通通串起來
            let allHeader = allHeaderX2 + allHeader //冠上之前保存的前兩欄標題，即簡稱和本金
            let txtHeader = (allHeader.map{String($0)}).joined(separator: ", ") + "\n"
            text = "\(title)\(txtHeader)\(txtMonthly)\(txtSummary)\n" //最後空行可使版面周邊的留白對稱
        }

        return text
    }
    
    func csvImport(csv:String) -> Int { //0:匯入完畢 -1:不能匯入 1:匯入失敗
        let csvLines = csv.split(separator: "\n")
        if csvLines.count > 0 {
            let header = "日期,時間,代號,簡稱,收盤價,最高價,最低價,開盤價,成交量,來源,年"
            let line0 = csvLines[0]
            let hIndex = line0.index(line0.startIndex, offsetBy: header.count)
            if String(line0[..<hIndex]) != header || csvLines.count < 10 {
                return -1
            }
        } else {
            return -1
        }
        var prevId:String = ""
        let context = coreData.shared.getContext()
        for (index,csvline) in csvLines.enumerated() {
            if index > 0 {  //header要略過
                let attr = csvline.split(separator: ",")
                if let dt = twDateTime.dateFromString("\(attr[0]) \(attr[1])", format: "yyyy/MM/dd HH:mm:ss") {
                    let id:String = String(attr[2])
                    let name:String = String(attr[3])
                    if id != prevId {
                        if let sim = self.simPrices[id] {
                            sim.deletePrice(context)
                        } else {
                            let _ = self.addNewStock(id: id, name: name)
                        }
                        prevId = id
                    }
                    let close:Double    = Double(attr[4]) ?? 0
                    let high:Double     = Double(attr[5]) ?? 0
                    let low:Double      = Double(attr[6]) ?? 0
                    let open:Double     = Double(attr[7]) ?? 0
                    let vol:Double      = Double(attr[8]) ?? 0
                    let uby:String  = String(attr[9])
                    let year:String = String(attr[10])
                    let _ = coreData.shared.newPrice(context, source: uby, id: id, dateTime: dt, year: year, close: close, high: high, low: low, open: open, volume: vol)
                    let progress:Float = Float(index) / Float(csvLines.count)   //index缺1才不會100%
                    self.setProgress(id, progress: progress,message: (progress == 1 ? "稍候重算" : ""),solo:true)
                } else {
                    return 1
                }
            }
        }
        coreData.shared.saveContext(context)    //先存好才能讓setProgress為1去unlockUI和showPrice
        self.setProgress("", progress: 1,message: "稍候重算" ,solo:true)
        return 0
        
    }
    
    func csvExport(_ type:String, id:String="") -> String {  //匯出單股CSV或全股CSV，都是單檔
        var csv:String = ""
        var header:String = "日期,時間,代號,簡稱,收盤價,最高價,最低價,開盤價,成交量,來源,年"
        if type == "all" || type == "single" {
            header += ",最低差,60高差,60低差,250高差,250低差,量差分" +
            ",ma20,ma20差,ma20Min,ma20Max,ma20日,ma20低,ma20高" +
            ",ma60,ma60差,ma60差分,ma60Min,ma60Max,ma60日,ma60低,ma60高,ma60日差" +
            ",ma差,ma差Min,ma差Max,ma差日" +
            ",j,d,k,k差分,k20,k80,k升率" +
            ",osc,osc差分,oscL,oscH,oscMin,oscMax" +
            ",輪,規則,買,賣,餘,天數,成本價,成本價差,當時損益,加減碼,本金餘,本金倍" +
            ",累計天,累計損益,累計成本,年報酬率"
        }
        let fetched = coreData.shared.fetchPrice(sim:self.simPrices[id], dateOP: (type == "allInOne" ? "ALL" : nil), asc: true)
        for (index,price) in fetched.Prices.enumerated() {
            let name = simPrices[price.id]?.name ?? ""
            let d = twDateTime.stringFromDate(price.dateTime, format: "yyyy/MM/dd")
            let t = twDateTime.stringFromDate(price.dateTime, format: "HH:mm:ss")
            csv += "\(d),\(t),\(price.id),\(name),\(price.priceClose),\(price.priceHigh),\(price.priceLow),\(price.priceOpen),\(price.priceVolume),\(price.updatedBy),\(price.year)"
            if type == "allInOne" {
                csv += "\n"
            } else {
                let rules:[String] = ["L","M","N","H","I","J","S","S-"]
                let ruleLevel:String = (rules.contains(price.simRule) ? String(format:"%.f",price.simRuleLevel) : "")
                let simRule:String = price.simRuleBuy + (price.simRule.count > 0 ? "(" + price.simRule + ruleLevel + ")" : "")
                csv += ",\(price.priceLowDiff),\(price.price60HighDiff),\(price.price60LowDiff),\(price.price250HighDiff),\(price.price250LowDiff),\(price.priceVolumeZ)" + ",\(price.ma20),\(price.ma20Diff),\(price.ma20Min9d),\(price.ma20Max9d),\(price.ma20Days),\(price.ma20L),\(price.ma20H)" + ",\(price.ma60),\(price.ma60Diff),\(price.ma60Z),\(price.ma60Min9d),\(price.ma60Max9d),\(price.ma60Days),\(price.ma60L),\(price.ma60H),\(price.ma60Avg)" + ",\(price.maDiff),\(price.maMin9d),\(price.maMax9d),\(price.maDiffDays)" + ",\(price.kdJ),\(price.kdD),\(price.kdK),\(price.kdKZ),\(price.k20Base),\(price.k80Base),\(price.kGrowRate)" + ",\(price.macdOsc),\(price.macdOscZ),\(price.macdOscL),\(price.macdOscH),\(price.macdMin9d),\(price.macdMax9d)" + ",\(price.simRound),\(simRule),\(price.qtyBuy),\(price.qtySell),\(price.qtyInventory),\(price.simDays),\(price.simUnitCost),\(price.simUnitDiff),\(price.simROI),\(price.moneyRemark),\(price.simBalance),\(price.moneyMultiple)" + ",\(price.cumulDays),\(price.cumulProfit),\(price.cumulCost),\(price.cumulROI)\n"
            }
            let progress:Float = Float(index + 1) / Float(fetched.Prices.count)
            self.setProgress(price.id, progress: progress,solo: (type == "all" ? false : true))
        }
        csv = header + "\n" + csv
        return csv
    }


}

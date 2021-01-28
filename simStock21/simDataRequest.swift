//
//  simDataRequest.swift
//  simStock21
//
//  Created by peiyu on 2020/7/11.
//  Copyright © 2020 peiyu. All rights reserved.
//

import UIKit
import BackgroundTasks

class simDataRequest {
    private var timer:Timer?
    private var isOffDay:Bool = false
    private var timeTradesUpdated:Date
    private var timeLastTrade:Date = Date.distantPast
    private let requestInterval:TimeInterval = 120
    
    private var inMarketingTime:Bool {
        (twDateTime.inMarketingTime(timeLastTrade, forToday: true) || (twDateTime.inMarketingTime(timeTradesUpdated, forToday: true) && twDateTime.inMarketingTime(delay: 2, forToday: true))) && !isOffDay
    }
    
    private var realtime:Bool {
        inMarketingTime || (timeTradesUpdated > twDateTime.time1330(twDateTime.yesterday(), delayMinutes: 3) && twDateTime.inMarketingTime(delay: 3, forToday: true) && !isOffDay)
    }
    
    enum simTechnicalAction {
        case realtime       //下載了盤中價
        case newTrades      //下載了最近的歷史價
        case allTrades      //下載從頭開始的歷史價，只根據cnyes的下載範圍指定
        case tUpdateAll     //重算技術數值，也包含simResetAll的工作
        case simTesting     //模擬測試，也包含simResetAll的工作
        case simUpdateAll   //更新模擬，不清除反轉和加碼
        case simResetAll    //重算模擬，要清除反轉和加碼
        case TWSE
    }

    init() {
        timeTradesUpdated = UserDefaults.standard.object(forKey: "timeTradesUpdated") as? Date ?? Date.distantPast
    }
    
    func downloadStocks(doItNow:Bool = false) {
        if doItNow {
            twseDailyMI()
        } else if let timeStocksDownloaded = UserDefaults.standard.object(forKey: "timeStocksDownloaded") as? Date {
            let days:TimeInterval = (0 - timeStocksDownloaded.timeIntervalSinceNow) / 86400
            if days > 10 {    //10天更新一次
                twseDailyMI()
            } else {
                simLog.addLog("stocks 上次:\(twDateTime.stringFromDate(timeStocksDownloaded,format: "yyyy/MM/dd HH:mm:ss")), next in \(String(format:"%.1f",10 - days)) days")
            }
        } else {
            twseDailyMI()
        }
    }
        
    func downloadTrades(_ stocks: [Stock], requestAction:simTechnicalAction?=nil, allStocks:[Stock]?=nil) {
        if let action = requestAction {
            runRequest(stocks, action: action, allStocks: allStocks)
        } else {
            let last1332 = twDateTime.time1330(twDateTime.yesterday(), delayMinutes: 2)
            let time1332 = twDateTime.time1330(delayMinutes: 2)
            let time0900 = twDateTime.time0900(delayMinutes: -2)
            if (isOffDay && twDateTime.isDateInToday(timeTradesUpdated)) {
                simLog.addLog("休市日且今天已更新。")
            } else if timeTradesUpdated > last1332 && Date() < time0900 {
                simLog.addLog("今天還沒開盤且上次更新是昨收盤後。")
            } else if timeTradesUpdated > time1332 {
                simLog.addLog("上次更新是今天收盤之後。")
            } else {
                runRequest(allStocks ?? stocks, action: (realtime ? .realtime : .newTrades))
            }
        }
    }
    
    private let allGroup:DispatchGroup = DispatchGroup()  //這是stocks共用的group，等候全部的背景作業完成時通知主畫面
    private let twseGroup:DispatchGroup = DispatchGroup() //這是控制twse依序下載以避免同時多條連線被拒
    private var stockCount:Int = 0
    private var stockProgress:Int = 0
    private var stockAction:String = ""
    private func progressNotify(_ increase:Int = 0) {
        DispatchQueue.main.async {
            self.stockProgress += (self.stockProgress < self.stockCount ? increase : 0)
            let message:String = "\(self.stockAction)(\(self.stockProgress)/\(self.stockCount))"
            NotificationCenter.default.post(name: Notification.Name("requestRunning"), object: nil, userInfo: ["msg":message])  //通知股群清單計算的進度
        }
    }

    private func runRequest(_ stocks:[Stock], action:simTechnicalAction = .realtime, allStocks:[Stock]?=nil) {
        self.stockCount = stocks.count
        if action != .simTesting {
            simLog.addLog("\(action)(\(stocks.count)) " + twDateTime.stringFromDate(timeTradesUpdated, format: "上次：yyyy/MM/dd HH:mm:ss") + (isOffDay ? " 今天休市" : " \(self.inMarketingTime ? "盤中待續" : "已收盤")"))
            if self.stockProgress > 0 {
                simLog.addLog("\t前查價未完？？？(\(self.stockProgress)/\(self.stockCount))")
//                if self.realtime {
                    self.setupTimer(allStocks ?? stocks, timeInterval: 30)
//                }
                return
            }
            if netConnect.isNotOK() {
                simLog.addLog("暫停查價：網路未連線。")
                return
            }
        }
        self.twseCount = 0
        self.stockProgress = 1
        let q = OperationQueue()
        if action != .simTesting {
            q.maxConcurrentOperationCount = 1
        }
        if twDateTime.startOfDay(timeTradesUpdated) != twDateTime.startOfDay() {
            isOffDay = false
        }
        for stock in stocks {
            allGroup.enter()
            if action == .realtime && self.realtime {
                self.stockAction = (isOffDay ? "休市日" : "查詢盤中價")
                self.yahooRequest(stock) //, allGroup: allGroup, twseGroup: twseGroup)
            } else if action == .simUpdateAll || action == .simTesting {
                self.simTechnical(stock: stock, action: action)
                allGroup.leave()
            } else {    //newTrades, allTrades, tUpdateAll, simResetAll
                self.stockAction = "請等候股群完成歷史資料的計算"
//                if action != .newTrades {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("requestRunning"), object: nil, userInfo: ["msg":"請等候股群完成資料的下載..."])  //通知股群清單要更新了
                    }
//                }
                let cnyesGroup:DispatchGroup = DispatchGroup()  //這是個股專用的group，等候cnyes下載完成才統計技術數值
                let allTrades = self.cnyesPrice(stock: stock, cnyesGroup: cnyesGroup) //回傳是否需要從頭重算模擬
                let cnyesAction:simTechnicalAction = (allTrades ? .allTrades : action)
                q.addOperation {    //q是依序執行simTechnical以避免平行記憶體飆高crash
                    cnyesGroup.wait()
                    self.simTechnical(stock: stock, action: cnyesAction)
                    self.progressNotify(1)
                    self.yahooRequest(stock) //, allGroup: allGroup, twseGroup: twseGroup)
                }   //即使已經收盤後也需要yahoo，才收盤時cnyes未及把當日收盤價納入查詢結果
            }
        }
        allGroup.notify(queue: .main) {
            self.stockProgress = 0
            self.stockAction = ""
            if action != .simTesting {
                if  action != .realtime || twDateTime.inMarketingTime() || !self.inMarketingTime {
                    self.timeTradesUpdated = Date() //收盤後仍有可能是剛睡醒的收盤前價格？那就維持前timeTradesUpdated不能動
                }
                UserDefaults.standard.set(self.timeTradesUpdated, forKey: "timeTradesUpdated")
                simLog.addLog("\(self.isOffDay ? "休市日" : "完成") \(action)\(self.isOffDay ? "" : "(\(stocks.count))") \(twDateTime.stringFromDate(self.timeTradesUpdated, format: "HH:mm:ss")) \(self.inMarketingTime ? "盤中待續" : "已收盤")")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("requestRunning"), object: nil, userInfo: ["msg":""])  //解除UI「背景作業中」的提示
                }
                if self.realtime {
                    self.runP10(stocks)
                    self.setupTimer(allStocks ?? stocks)
                }
            }
        }
    }
    
    func setupTimer(_ stocks:[Stock], timeInterval:TimeInterval?=nil) {
        self.invalidateTimer()
        self.timer = Timer.scheduledTimer(withTimeInterval: (timeInterval ?? self.requestInterval), repeats: false) {_ in
            self.runRequest(stocks, action: .realtime)
        }
        if let t = self.timer, t.isValid {
            simLog.addLog("timer scheduled in " + String(format:"%.1fs",t.fireDate.timeIntervalSinceNow))
        }
    }
    
    func invalidateTimer() {
        if let t = self.timer, t.isValid {
            t.invalidate()
            self.timer = nil
            simLog.addLog("timer invalidated.")
        }
    }

    var countTWSE:Int? = nil
    var progressTWSE:Int? = nil
    var continueTWSE:Bool = true
    
    func reviseWithTWSE(_ stocks:[Stock], bgTask:BGTask?=nil) {
        self.countTWSE = stocks.count
        self.continueTWSE = true
        self.progressTWSE = 0
        var tasks = stocks
        
        var timeRemain:String {
            if bgTask != nil && UIApplication.shared.backgroundTimeRemaining < 500 {
                return String(format:"剩餘時間: %.3fs",UIApplication.shared.backgroundTimeRemaining)
            }
            return ""
        }

        if let task = bgTask {
            task.expirationHandler = {
                self.continueTWSE = false
                simLog.addLog("BGTask expired. \(timeRemain)")
                task.setTaskCompleted(success: false)
            }
        }
        
        func submitBGTask() {
            if UIApplication.shared.backgroundTimeRemaining < 500 {
                let request = BGProcessingTaskRequest(identifier: "com.mystock.simStock21.BGTask")
                request.earliestBeginDate = Date(timeIntervalSinceNow: 320) //背景預留時間
                request.requiresNetworkConnectivity = true
                try? BGTaskScheduler.shared.submit(request)
                simLog.addLog("BGTask submitted again.")
            }
        }
        
        func requestTWSE(_ requestStocks:[Stock], bgTask:BGTask?=nil) {
            var requests = requestStocks
            let stockGroup:DispatchGroup = DispatchGroup()
            if let stock = requests.first {
                if let dateStart = stock.dateRequestTWSE  {
                    stockGroup.enter()
                    let progress = self.progressTWSE ?? 0
                    let delay:Int = (progress % 5 == 0 ? 9 : 3) + (progress % 7 == 0 ? 3 : 0)
                    self.progressTWSE = tasks.count - requests.count + 1
                    DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(delay)) {
                        self.twseRequest(stock: stock, dateStart: dateStart, stockGroup: stockGroup)
                    }
                    if dateStart == twDateTime.yesterday() {
                        requests.append(stock)  //復驗是到昨天，可能只有1筆，就再多排一次
                        tasks.append(stock)
                    }
                } else {
//                    stockGroup.enter()
//                    stockGroup.leave()
                    simLog.addLog("TWSE \(stock.sId)\(stock.sName) 略。 繼續？\(self.continueTWSE)")
                }
            }
            stockGroup.wait()
            if self.continueTWSE {
                requests.removeFirst()
                if requests.count > 0 {
                    requestTWSE(requests, bgTask: bgTask)
                } else {
                    self.progressTWSE = nil
                    simLog.addLog("TWSE(\(requestStocks.count))完成。 \(timeRemain)")
                    if let task = bgTask {
                        task.setTaskCompleted(success: true)
                    }
                }
            } else {
                simLog.addLog("TWSE(\(self.progressTWSE ?? 0)/\(requestStocks.count))中斷！ \(timeRemain)")
                self.continueTWSE = true
                self.progressTWSE = nil
                if let task = bgTask {
                    task.setTaskCompleted(success: false)
                }
            }
        }
        
        requestTWSE(tasks)
    }
    
    
    
    /*
     action         | tUpdate | simUpdate | simReset
     ---------------+---------+-----------+----------
     realtime       |    v    |     v     |
     newTrades      |    v    |     v     |
     allTrades      |    v    |     v     |    v
     tUpdateAll     |    v    |     v     |    v
     simTesting     |         |     v     |    v
     simUpdateAll   |         |     v     |
     simResetAll    |    v    |     v     |    v
     */

    private func simTechnical(stock:Stock, action:simTechnicalAction) {
        let context = coreData.shared.context
        let trades = Trade.fetch(context, stock: stock, end: (action == .simTesting ? (twDateTime.calendar.date(byAdding: .year, value: 3, to: stock.dateStart) ?? Date.distantFuture) : nil), fetchLimit: (action == .realtime ? 256 : nil), asc:(action == .realtime ? false : true))
        if trades.count > 0 {
            if action == .realtime {
                let tr376:[Trade] = trades.reversed()
                tUpdate(tr376, index: trades.count - 1)
                simUpdate(tr376, index: trades.count - 1)
            } else {
                var tCount:Int = 0
                var sCount:Int = 0
                for (index,trade) in trades.enumerated() {
                    if action == .tUpdateAll || action == .simResetAll || action == .simTesting || action == .allTrades {
                        //simReset就是清除user的加碼和反轉買賣
                        trade.simReversed = ""
                        trade.simInvestByUser = 0
                    }
                    if trade.tUpdated == false || action == .tUpdateAll {
                        //tUpdated == false代表newTrades,allTrades。但newTrades不用從頭重算，怎麼排除呢？
                        self.tUpdate(trades, index: index)
                        tCount += 1
                        self.simUpdate(trades, index: index)
                        sCount += 1
                    } else if action != .newTrades {    //allTrades應重算模擬
                        self.simUpdate(trades, index: index)
                        sCount += 1
                    }
                }
                if action != .simTesting {
                    let progress = self.progressTWSE ?? self.stockProgress
                    let count = self.countTWSE ?? self.stockCount
                    simLog.addLog("(\(progress)/\(count))\(stock.sId)\(stock.sName) 歷史價\(trades.count)筆" + (tCount > 0 ? "/技術\(tCount)筆" : "") + (sCount > 0 ? "/模擬\(sCount)筆" : "") + " \(action)")
                }
            }
            if action != .simTesting {
                try? context.save()
                DispatchQueue.main.async {
                    stock.objectWillChange.send()
                }
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    //== 五檔價格試算建議 ==
    private func runP10(_ stocks:[Stock]) {
        DispatchQueue.global().async {
            let s = stocks.filter{$0.sId != "t00"}
            for stock in s {
                stock.p10 = self.p10(stock)
                if stock.p10.action != "" {
                    DispatchQueue.main.async {
                        simLog.addLog("P10:\(stock.sId)\(stock.sName):\(stock.p10.action)(L\(stock.p10.L.count),H\(stock.p10.H.count))")
                        stock.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    private func p10(_ stock:Stock) -> P10 {
        var p10:P10 = P10()
        if twDateTime.inMarketingTime() && !self.isOffDay {
            let context = coreData.shared.context
            let trades:[Trade] = Trade.fetch(context, stock: stock, fetchLimit: 376, asc:false).reversed()
            if trades.count > 0 {
                let trade = trades[trades.count - 1]
                let price = trade.priceClose
                let diff = priceDiff(price)
                p10.date = trade.date
                for i in 1...10 {
                    let d = Double(i > 5 ? i - 5 : i - 6) //-5到-1，1到5
                    trade.priceClose = price + (d * diff)
                    tUpdate(trades, index: trades.count - 1)
                    simUpdate(trades, index: trades.count - 1)
                    let simQty = trade.simQty
                    if simQty.action == "買" || simQty.action == "賣" {
                        if trade.priceClose < price {
                            p10.L.append((trade.priceClose, simQty.action, simQty.qty, simQty.roi))
                        } else {
                            p10.H.append((trade.priceClose, simQty.action, simQty.qty, simQty.roi))
                        }
                        if simQty.action == "買" && p10.rule == nil {
                            p10.rule = trade.simRuleBuy
                        }
                    }
                }
                if p10.L.count > 0 {
                    p10.action = p10.L[0].action
                } else if p10.H.count > 0 {
                    p10.action = p10.H[0].action
                }
                context.rollback()
            }
        }
        return p10
    }

    private func priceDiff(_ price:Double) -> Double {  //每檔差額
        switch price {
        case let p where p < 10:
            return 0.01
        case let p where p < 50:
            return 0.05
        case let p where p < 100:
            return 0.1
        case let p where p < 500:
            return 0.5
        case let p where p < 1000:
            return 1
        default:
            return 5    //1000元以上檔位
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    private func twseDailyMI() {
        if netConnect.isNotOK() {
            simLog.addLog("放棄代號更新：網路未連線。")
            return
        }
        //        let y = calendar.component(.Year, fromDate: qDate) - 1911
        //        let m = calendar.component(.Month, fromDate: qDate)
        //        let d = calendar.component(.Day, fromDate: qDate)
        //        let YYYMMDD = String(format: "%3d/%02d/%02d", y,m,d)
        //================================================================================
        //從當日收盤行情取股票代號名稱
        //2017-05-24因應TWSE網站改版變更查詢方式為URLRequest
        //http://www.twse.com.tw/exchangeReport/MI_INDEX?response=csv&date=20170523&type=ALLBUT0999

        let url = URL(string: "http://www.twse.com.tw/exchangeReport/MI_INDEX?response=csv&type=ALLBUT0999")
        let urlRequest = URLRequest(url: url!,timeoutInterval: 30)

        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: {(data, response, error) in
            if error == nil {
                let big5 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseTrad.rawValue))
                if let downloadedData = String(data:data!, encoding:String.Encoding(rawValue: big5)) {

                    /* csv檔案的內容是混合格式：
                     2016年07月19日大盤統計資訊
                     "指數","收盤指數","漲跌(+/-)","漲跌點數","漲跌百分比(%)"
                     寶島股價指數,10452.88,+,26.8,0.26
                     發行量加權股價指數,9034.87,+,26.66,0.3
                     "成交統計","成交金額(元)","成交股數(股)","成交筆數"
                     "1.一般股票","86290700501","2396982245","807880"
                     "2.台灣存託憑證","25070276","4935658","1405"
                     "證券代號","證券名稱","成交股數","成交筆數","成交金額","開盤價","最高價","最低價","收盤價","漲跌(+/-)","漲跌價差","最後揭示買價","最後揭示買量","最後揭示賣價","最後揭示賣量","本益比"
                     ="0050  ","元大台灣50      ","17045587","2165","1179010803","69.2","69.3","68.8","69.25","+","0.1","69.25","615","69.3","40","0.00"
                     "1101  ","台泥            ","10196350","5055","362488555","35.55","35.75","35.4","35.6","+","0.1","35.55","122","35.6","152","25.25"
                     "1102  ","亞泥            ","5021942","3083","144691768","28.7","29","28.55","28.9","+","0.2","28.85","106","28.9","147","27.01"

                     "說明："
                     */

                    //去掉千分位逗號和雙引號
                    var textString:String = ""
                    var quoteCount:Int=0
                    for e in downloadedData {
                        if e == "\r\n" {
                            quoteCount = 0
                        } else if e == "\"" {
                            quoteCount = quoteCount + 1
                        }
                        if e != "," || quoteCount % 2 == 0 {
                            textString.append(e)
                        }
                    }
                    textString = textString.replacingOccurrences(of: " ", with: "")   //去空白
                    textString = textString.replacingOccurrences(of: "\"", with: "")  //去雙引號
                    textString = textString.replacingOccurrences(of: "\r\n", with: "\n")  //去換行

                    let lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]
                    var stockListBegins:Bool = false
                    let context = coreData.shared.context
                    var allStockCount:Int = 0
                    for (index, lineText) in lines.enumerated() {
                        var line:String = lineText
                        if lineText.first == "=" {
                            stockListBegins = true
                        }
                        if lineText != "" && lineText.contains(",") && lineText.contains(".") && index > 2 && stockListBegins {
                            if lineText.first == "=" {
                                line = lineText.replacingOccurrences(of: "=", with: "")   //去首列等號
                            }

                            let sId = line.components(separatedBy: ",")[0]
                            let sName = line.components(separatedBy: ",")[1]
                            let _ = Stock.new(context, sId:sId, sName: sName)
                            allStockCount += 1
                        }   //if line != ""
                    } //for
                    try? context.save()
                    UserDefaults.standard.set(Date(), forKey: "timeStocksDownloaded")
                    simLog.addLog("twseDailyMI(ALLBUT0999): \(allStockCount)筆")
                }   //if let downloadedData
            } else {  //if error == nil
                UserDefaults.standard.removeObject(forKey: "timeStocksDownloaded")
                simLog.addLog("twseDailyMI(ALLBUT0999) error:\(String(describing: error))")
            }
        })
        task.resume()
    }

    
    /*
    var cnyesFailed:Bool = false
    private func cnyesRequest(_ stock:Stock, ymdStart:String, ymdEnd:String, cnyesGroup:DispatchGroup) {
        guard let s = twDateTime.dateFromString(ymdStart) else {return}
        guard let e = twDateTime.dateFromString(ymdEnd) else {return}
        let ymdS = String(format:"%.f",s.timeIntervalSince1970)
        let ymdE = String(format:"%.f",e.timeIntervalSince1970)
        let urls = "https://ws.api.cnyes.com/charting/api/v1/history?resolution=D&symbol=TWS:\(stock.sId):STOCK&from=\(ymdE)&to=\(ymdS)"
        guard let url = URL(string: urls) else {return}
        cnyesGroup.enter()
        if cnyesFailed {
            self.cnyesLegacy(stock, ymdStart: ymdStart, ymdEnd: ymdEnd, cnyesGroup: cnyesGroup)
            return
        }
        var urlRequest = URLRequest(url: url,timeoutInterval: 30)
        urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("https://invest.cnyes.com/twstock/tws/\(stock.sId)/history", forHTTPHeaderField: "Referer")
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: {(data, response, error) in
            do {
                guard let jsonData = data else { throw requestError.error(msg:"no data") }
                guard let jroot = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String:Any] else {throw requestError.error(msg: "invalid json root") }
                guard let message = jroot["message"] as? String else {throw requestError.error(msg:"no message") }
                if message != "OK" {
                    throw requestError.error(msg:"message is not OK! \(message)")
                }
                guard let jdata = jroot["data"] as? [String:Any] else {throw requestError.error(msg:"no prices")}

                /*
                 {"message":"OK","statusCode":200,"data":{"nextTime":null,
                 "t":[1586390400,1586304000,1586217600,1586131200,1585699200, ... ,1428451200,1428364800],
                 "c":[283,285,283,275.5,271.5,274,267.5,273,280,277,267.5,255,270,248,260, ... ,143,146],
                 "l":[282.5,283,280.5,270,271.5,269.5,262.5,273,275.5,274,266,252,256,235.5, ... ,143,145],
                 "h":[288,285.5,284,275.5,276.5,274,269,286,280,280,274,262.5,270,253,272.5, ... ,146,147.5],
                 "quote":null,
                 "v":[29276.43,38698.826000000001,48887.345999999998,59712.754000000001, ... ,400.697999999997],
                 "session":[[1606870800,1606887300]],
                 "s":"ok",
                 "o":[287.5,285,283.5,273,276.5,273,263.5,284,279.5,276.5,268,257,258.5, ... ,145.5,146.5]}}
                 */
                
                let t = jdata["t"] as? [Double] ?? []
                let c = jdata["c"] as? [Double] ?? []
                let l = jdata["l"] as? [Double] ?? []
                let h = jdata["h"] as? [Double] ?? []
                let o = jdata["o"] as? [Double] ?? []
                
                if t.count != c.count || t.count != l.count || t.count != h.count || t.count != o.count {
                    simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) cnyes \(ymdStart)~\(ymdEnd) 全部\(t.count)筆 筆數不符？ c=\(c.count) l=\(l.count) h=\(h.count) o=\(o.count)")
                } else {
                    let context = coreData.shared.context
                    var tradesCount:Int = 0
                    var firstDate:Date = Date.distantFuture
                    for (i,T) in t.enumerated() {
                        let d = Date(timeIntervalSince1970: TimeInterval(T))
                        let dt = twDateTime.time1330(d)
                        if c[i] > 0 {
                            tradesCount += 1
                            if dt < firstDate {
                                firstDate = dt
                            }
                            let trade = Trade.trade(context, stock: stock, date: dt)
                            trade.dateTime      = dt
                            trade.priceClose    = c[i]
                            trade.priceOpen     = o[i]
                            trade.priceHigh     = h[i]
                            trade.priceLow      = l[i]
                            trade.tSource       = "cnyes"
                            trade.tUpdated      = false
                        }
                    }
                    if tradesCount > 0 {
                        simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) cnyes \(ymdStart)~\(ymdEnd) 有效\(tradesCount)筆/全部\(t.count)筆")
                        try? context.save()
                        if twDateTime.stringFromDate(stock.dateFirst) == ymdStart && firstDate > stock.dateFirst {
                            stock.dateFirst = firstDate
                            if stock.dateStart <= stock.dateFirst {
                                stock.dateStart = twDateTime.calendar.date(byAdding: .day, value: 1, to: stock.dateFirst) ?? stock.dateFirst
                            }
                            stock.save()
                        }
                    } else {
                        simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) cnyes \(ymdStart)~\(ymdEnd) 全部\(t.count)筆，但無有效交易？")
                    }
                }
                cnyesGroup.leave()
            } catch {
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse \(error)")
                self.cnyesFailed = true
                self.cnyesLegacy(stock, ymdStart: ymdStart, ymdEnd: ymdEnd, cnyesGroup: cnyesGroup)
            }   //do
        })
        task.resume()
    }
    */

    
    
    
    
    private func cnyesLegacy(_ stock:Stock, ymdStart:String, ymdEnd:String, cnyesGroup:DispatchGroup) {
        cnyesGroup.enter()
        let url = URL(string: "http://www.cnyes.com/twstock/ps_historyPrice.aspx?code=\(stock.sId)&ctl00$ContentPlaceHolder1$startText=\(ymdStart)&ctl00$ContentPlaceHolder1$endText=\(ymdEnd)")
        let urlRequest = URLRequest(url: url!,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: {(data, response, error) in
            if error == nil {
                if let downloadedData = String(data:data!, encoding:.utf8) {

                    let leading     = "<tr class=\'thbtm2\'>\r\n    <th>日期</th>\r\n    <th>開盤</th>\r\n    <th>最高</th>\r\n    <th>最低</th>\r\n    <th>收盤</th>\r\n    <th>漲跌</th>\r\n    <th>漲%</th>\r\n    <th>成交量</th>\r\n    <th>成交金額</th>\r\n    <th>本益比</th>\r\n    </tr>\r\n    "
                    let trailing    = "\r\n</table>\r\n</div>\r\n  <!-- tab:end -->\r\n</div>\r\n<!-- bd3:end -->"
                    if let findRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                        let startIndex = downloadedData.index(findRange.lowerBound, offsetBy: leading.count)
                        let endIndex = downloadedData.index(findRange.upperBound, offsetBy: 0-trailing.count)
                        let textString = downloadedData[startIndex..<endIndex].replacingOccurrences(of: "</td></tr>", with: "\n").replacingOccurrences(of: "<tr><td class=\'cr\'>", with: "").replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "</td><td class=\'rt\'>", with: ",").replacingOccurrences(of: "</td><td class=\'rt r\'>", with: ",").replacingOccurrences(of: "</td><td class=\'rt g\'>", with: ",")
                        //日期,開盤,最高,最低,收盤,漲跌,漲%,成交量,交金額,本益比
                        //2017/06/22,217.00,218.00,216.50,218.00,2.50,1.16%,24228,5268473,15.83
                        //2017/06/21,216.00,217.00,214.50,215.50,-1.00,-0.46%,44826,9673307,15.65
                        //2017/06/20,215.00,218.00,214.50,216.50,3.50,1.64%,28684,6208332,15.72
                        var lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]
                        if lines.last == "" {
                            lines.removeLast()
                        }
                        let context = coreData.shared.context
                        var tradesCount:Int = 0
                        var firstDate:Date = Date.distantFuture
                        for line in lines.reversed() {
                            if let dt0 = twDateTime.dateFromString(line.components(separatedBy: ",")[0]) {
                                let dateTime = twDateTime.time1330(dt0)
                                if let close = Double(line.components(separatedBy: ",")[4]) {
                                    if close > 0 {
                                        if dt0 < firstDate {
                                            firstDate = dt0
                                        }
                                        let trade = Trade.trade(context, stock: stock, date: dt0)
                                        if trade.tSource != "TWSE" {
                                            trade.dateTime = dateTime
                                            trade.priceClose = close
                                            if let open = Double(line.components(separatedBy: ",")[1]) {
                                                trade.priceOpen = open
                                            }
                                            if let high = Double(line.components(separatedBy: ",")[2]) {
                                                trade.priceHigh = high
                                            }
                                            if let low  = Double(line.components(separatedBy: ",")[3]) {
                                                trade.priceLow = low
                                            }
                                            trade.tSource = "cnyes"
                                            trade.tUpdated  = false
                                            tradesCount += 1
                                        }
                                    }
                                }   //if let close
                            }   //if let dt0
                        }   //for
                        if tradesCount > 0 {
                            simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) cnyes \(ymdStart)~\(ymdEnd) 有效\(tradesCount)筆/全部\(lines.count)筆")
                            try? context.save()
                            if twDateTime.stringFromDate(stock.dateFirst) == ymdStart && firstDate > stock.dateFirst {
                                stock.dateFirst = firstDate
                                if stock.dateStart <= stock.dateFirst {
                                    stock.dateStart = twDateTime.calendar.date(byAdding: .day, value: 1, to: stock.dateFirst) ?? stock.dateFirst
                                }
                                stock.save()
                            }
                        } else {
                            simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) cnyes \(ymdStart)~\(ymdEnd) 全部\(lines.count)筆，但無有效交易？")
                        }
                    } else {  //if let findRange 有資料無交易故touch
                        simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) cnyes \(ymdStart)~\(ymdEnd) 解析無交易資料。")
                    }
                } else {  //if let downloadedData 下無資料故touch
                    simLog.addLog("(\(self.stockProgress)/\(self.stockCount))cnyes\(stock.sId)\(stock.sName) \(ymdStart)~\(ymdEnd) 下載無資料。")
                }
            } else {  //if error == nil 下載有失誤也要touch
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))cnyes\(stock.sId)\(stock.sName) \(ymdStart)~\(ymdEnd) 下載有誤 \(String(describing: error))")
            }
            cnyesGroup.leave()
        })
        task.resume()
     }
     
    private func cnyesRequest(_ stock:Stock, ymdStart:String, ymdEnd:String, cnyesGroup:DispatchGroup) {
        self.cnyesLegacy(stock, ymdStart: ymdStart, ymdEnd: ymdEnd, cnyesGroup: cnyesGroup)
        return
    }

    private func cnyesPrice(stock:Stock, cnyesGroup:DispatchGroup) -> Bool {
        var allTrades:Bool = false      //應重頭更新全部的技術值
        if stock.trades.count == 0 {    //資料庫是空的
            let ymdS = twDateTime.stringFromDate(stock.dateFirst)
            let ymdE = twDateTime.stringFromDate()  //今天
            cnyesRequest(stock, ymdStart: ymdS, ymdEnd: ymdE, cnyesGroup: cnyesGroup)
            allTrades = true
        } else {
            let context = coreData.shared.context
            if let firstTrade = stock.firstTrade(context) {
                if stock.dateFirst < twDateTime.startOfDay(firstTrade.dateTime)  {    //起日在首日之前
                    let ymdS = twDateTime.stringFromDate(stock.dateFirst)
                    let ymdE = twDateTime.stringFromDate(firstTrade.dateTime)
                    cnyesRequest(stock, ymdStart: ymdS, ymdEnd: ymdE, cnyesGroup: cnyesGroup)
                    allTrades = true
                }
            }
            if let lastTrade = stock.lastTrade(context) {
                if lastTrade.dateTime < twDateTime.startOfDay()  {    //末日在今天之前
                    let ymdS = twDateTime.stringFromDate(lastTrade.dateTime)
                    let ymdE = twDateTime.stringFromDate(twDateTime.startOfDay())
                    cnyesRequest(stock, ymdStart: ymdS, ymdEnd: ymdE, cnyesGroup: cnyesGroup)
                }
            }
        }
        return allTrades
    }
    
    func twseRequest(stock:Stock, dateStart:Date, stockGroup:DispatchGroup) {
        let ymdStart = twDateTime.stringFromDate(dateStart, format: "yyyyMMdd")
        guard let url = URL(string: "http://www.twse.com.tw/exchangeReport/STOCK_DAY?&date=\(ymdStart)&stockNo=\(stock.sId)") else {return}
        let request = URLRequest(url: url,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
            do {
                guard let jsonData = data else { throw requestError.error(msg:"no data") }
                guard let jroot = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String:Any] else {throw requestError.error(msg: "invalid jroot") }
                guard let stat = jroot["stat"] as? String else {throw requestError.error(msg:"no rtmessage") }
                if stat != "OK" {
                    throw requestError.error(msg:"stat is not OK")
                }
                guard let jdata = jroot["data"] as? [[String]] else {throw requestError.warning(msg:"沒有交易資料？")}

                /*
                 "date": "20201210"
                 "title": "109年12月 2330 台積電           各日成交資訊"
                 "data": [[109/12/01, 38,341,265, 18,719,729,411, 489.50, 490.00, 483.50, 490.00, +9.50, 24,827], [109/12/02, 60,208,035, 29,970,556,095, 499.50, 500.00, 493.50, 499.00, +9.00, 35,624],
                 ..... [109/12/10, 43,991,133, 22,516,917,355, 511.00, 515.00, 510.00, 512.00, -8.00, 49,079]]
                 "stat": "OK"
                 "notes": ["符號說明:+/-/X表示漲/跌/不比價", "當日統計資訊含一般、零股、盤後定價、鉅額交易，不含拍賣、標購。", "ETF證券代號第六碼為K、M、S、C者，表示該ETF以外幣交易。"]
                 "fields": [日期,成交股數,成交金額,開盤價,最高價,最低價,收盤價,漲跌價差,成交筆數]
                 */
                
                var count:Int = 0
                let context = coreData.shared.context
                for element in jdata {
                    if let dt0 = twDateTime.dateFromString(element[0]) {
                        if let dt = twDateTime.calendar.date(byAdding: .year, value: 1911, to: dt0) {
                            if let close = Double(element[6].replacingOccurrences(of: ",", with: "")), close > 0 {
                                let trade = Trade.trade(context, stock: stock, date: dt)
                                if trade.tSource == "TWSE" {
                                    continue
                                }
                                trade.dateTime = twDateTime.time1330(dt)
                                trade.priceClose = close

                                trade.priceOpen = Double(element[3].replacingOccurrences(of: ",", with: "")) ?? 0
                                trade.priceHigh = Double(element[4].replacingOccurrences(of: ",", with: "")) ?? 0
                                trade.priceLow  = Double(element[5].replacingOccurrences(of: ",", with: "")) ?? 0
                                trade.tSource   = "TWSE"
                                trade.tUpdated  = false
                                count += 1
                                try? context.save()
                                if stock.dateFirst > dt {
                                    stock.dateFirst = dt
                                    if stock.dateStart <= stock.dateFirst {
                                        stock.dateStart = twDateTime.calendar.date(byAdding: .day, value: 1, to: stock.dateFirst) ?? stock.dateFirst
                                    }
                                    stock.save()
                                }
                            }   //if let close
                        }   //if let dt
                    }   //if let dt0
                }   //for
                simLog.addLog("\(stock.sId)\(stock.sName) TWSE \(twDateTime.stringFromDate(dateStart)) \(count)筆")
                if count > 0 {
                    self.simTechnical(stock: stock, action: .newTrades)
                }
            } catch requestError.warning(let msg) {
                simLog.addLog("\(stock.sId)\(stock.sName) TWSE \(twDateTime.stringFromDate(dateStart)) \(msg)")
            } catch requestError.error(let msg) {
                simLog.addLog("\(stock.sId)\(stock.sName) TWSE \(twDateTime.stringFromDate(dateStart)) \(msg)")
            } catch {
                simLog.addLog("\(stock.sId)\(stock.sName) TWSE \(twDateTime.stringFromDate(dateStart)) \(error)")
                self.continueTWSE = false
            }
            stockGroup.leave()
        })
        task.resume()
    }
    
    /*
    func twseCsv(stock:Stock, dateStart:Date, stockGroup:DispatchGroup) {
        let ymdStart = twDateTime.stringFromDate(dateStart, format: "yyyyMMdd")
        guard let url = URL(string: "http://www.twse.com.tw/exchangeReport/STOCK_DAY?response=csv&date=\(ymdStart)&stockNo=\(stock.sId)") else {return}
        stockGroup.enter()
        let request = URLRequest(url: url,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
            do {
                guard let d = data else {throw requestError.error(msg:"data is nil") }
                let big5 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseTrad.rawValue))
                guard let downloadedData = String(data:d, encoding:String.Encoding(rawValue: big5)) else { throw requestError.error(msg:"invalid data") }

                    /* csv檔案的內容：
                     "104年03月 0050 元大台灣50       各日成交資訊(元,股)"
                     日期,成交股數,成交金額,開盤價,最高價,最低價,收盤價,漲跌價差,成交筆數
                     104/03/02,"6,589,376","461,349,421",70.30,70.55,69.75,70.00,-0.30,"1,449"
                     104/03/03,"5,067,933","353,130,410",70.05,70.10,69.50,69.90,-0.10,"1,071"
                     104/03/04,"6,414,710","448,582,000",69.55,70.05,69.50,69.95,+0.05,"1,053"

                     201608之後變成股票代號和名稱中間沒有空格

                     105年08月 0050元大台灣50      各日成交資訊(元，股)
                     "日期","成交股數","成交金額","開盤價","最高價","最低價","收盤價","漲跌價差","成交筆數"
                     "105/08/01","10,407,371","720,963,537","68.80","69.45","68.80","69.30","+0.75","1,682",

                     */

                    //去掉千分位逗號和雙引號
                var textString:String = ""
                var quoteCount:Int=0
                for e in downloadedData {
                    if e == "\r\n" {
                        quoteCount = 0
                    } else if e == "\"" {
                        quoteCount = quoteCount + 1
                    }
                    if e != "," || quoteCount % 2 == 0 {
                        textString.append(e)
                    }
                }
                textString = textString.replacingOccurrences(of: " ", with: "")   //去空白
                textString = textString.replacingOccurrences(of: "\"", with: "")
                textString = textString.replacingOccurrences(of: "\r\n", with: "\n")  //去換行

                let lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]

                if lines.count > 2 {
                    var count:Int = 0
                    let context = coreData.shared.context
                    for (index, line) in lines.enumerated() {
                        if line == "" || !line.contains(",") || line.first == "日" || index < 2 {
                            continue
                        }
                        if let dt0 = twDateTime.dateFromString(line.components(separatedBy: ",")[0]) {
                            if let dt = twDateTime.calendar.date(byAdding: .year, value: 1911, to: dt0) {
                                if let close = Double(line.components(separatedBy: ",")[6]), close > 0 {
                                    let trade = Trade.trade(context, stock: stock, date: dt)
                                    if trade.tSource == "TWSE" {
                                        continue
                                    }
                                    trade.dateTime = twDateTime.time1330(dt)
                                    trade.priceClose = close

                                    trade.priceOpen = Double(line.components(separatedBy: ",")[3]) ?? 0
                                    trade.priceHigh = Double(line.components(separatedBy: ",")[4]) ?? 0
                                    trade.priceLow  = Double(line.components(separatedBy: ",")[5]) ?? 0
                                    trade.tSource   = "TWSE"
                                    trade.tUpdated  = false
                                    count += 1
                                    try? context.save()
                                    if stock.dateFirst > dt {
                                        stock.dateFirst = dt
                                        if stock.dateStart <= stock.dateFirst {
                                            stock.dateStart = twDateTime.calendar.date(byAdding: .day, value: 1, to: stock.dateFirst) ?? stock.dateFirst
                                        }
                                        stock.save()
                                    }
                                }   //if let close
                            }   //if let dt
                        }   //if let dt0
                    }   //for
                    simLog.addLog("\(stock.sId)\(stock.sName) twse \(twDateTime.stringFromDate(dateStart)) \(count)筆")
                    if count > 0 {
                        self.simTechnical(stock: stock, action: .newTrades)
                    }
                } else {  //if lines.count > 2
                    simLog.addLog("\(stock.sId)\(stock.sName) twse \(twDateTime.stringFromDate(dateStart)) no data")
                }
            } catch requestError.warning(let msg) {
                simLog.addLog("\(stock.sId)\(stock.sName) twse \(ymdStart) \(msg)")
            } catch {
                simLog.addLog("\(stock.sId)\(stock.sName) twse \(ymdStart) error:\n\(error)")
                self.continueTWSE = false
            }
            stockGroup.leave()
        })
        task.resume()
    }
    */
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    private func yahooRequest(_ stock:Stock) { //, allGroup:DispatchGroup, twseGroup:DispatchGroup) {
        if self.isOffDay {
            allGroup.leave()
            return
        }
        let url = URL(string: "https://tw.stock.yahoo.com/q/q?s=" + stock.sId)
        let urlRequest = URLRequest(url: url!,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: {(data, response, error) in
            if error == nil {
                let big5 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseTrad.rawValue))
                if let downloadedData = String(data:data!, encoding:String.Encoding(rawValue: big5)) {

                    /* sample data
                     <td width=160 align=right><font color=#3333FF class=tt>　資料日期: 106/04/25</font></td>\n\t</tr>\n    </table>\n<table border=0 cellSpacing=0 cellpadding=\"0\" width=\"750\">\n  <tr>\n    <td>\n      <table border=2 width=\"750\">\n        <tr bgcolor=#fff0c1>\n          <th align=center >股票<br>代號</th>\n          <th align=center width=\"55\">時間</th>\n          <th align=center width=\"55\">成交</th>\n\n          <th align=center width=\"55\">買進</th>\n          <th align=center width=\"55\">賣出</th>\n          <th align=center width=\"55\">漲跌</th>\n          <th align=center width=\"55\">張數</th>\n          <th align=center width=\"55\">昨收</th>\n          <th align=center width=\"55\">開盤</th>\n\n          <th align=center width=\"55\">最高</th>\n          <th align=center width=\"55\">最低</th>\n          <th align=center>個股資料</th>\n        </tr>\n        <tr>\n          <td align=center width=105><a\n\t  href=\"/q/bc?s=2330\">2330台積電</a><br><a href=\"/pf/pfsel?stocklist=2330;\"><font size=-1>加到投資組合</font><br></a></td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>13:11</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap><b>191.0</b></td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>190.5</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>191.0</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap><font color=#ff0000>△1.0\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>23,282</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>190.0</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>190.5</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>191.0</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>189.5</td>\n          <td align=center width=137 class=\"tt\">
                     */

                    //取日期 -> yDate
                    let leading = "<td width=160 align=right><font color=#3333FF class=tt>　資料日期: "
                    let trailing = "</font></td>\n\t</tr>\n    </table>\n<table border=0 cellSpacing=0 cellpadding=\"0\" width=\"750\">\n  <tr>\n    <td>\n      <table border=2 width=\"750\">\n        <tr bgcolor=#fff0c1>\n          <th align=center >股票<br>代號</th>"
                    if let yDateRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                        let startIndex = downloadedData.index(yDateRange.lowerBound, offsetBy: leading.count)
                        let endIndex = downloadedData.index(yDateRange.upperBound, offsetBy: 0-trailing.count)
                        let yDate = downloadedData[startIndex..<endIndex]

                        let leading = "<td align=\"center\" bgcolor=\"#FFFfff\" nowrap>"
                        let trailing = "</td>"
                        let yColumn:[String] = self.matches(for: leading, with: trailing, in: downloadedData)
                        if yColumn.count >= 9 {
                            let yTime = yColumn[0]
                            if let dt =  twDateTime.dateFromString(yDate+" "+yTime, format: "yyyy/MM/dd HH:mm") {
                                if let dt1 = twDateTime.calendar.date(byAdding: .year, value: 1911, to: dt) {
                                    //5分鐘給Yahoo!延遲開盤資料
                                    let time0905 = twDateTime.time0900(delayMinutes: 5)
                                    if (!twDateTime.isDateInToday(dt1)) && Date() > time0905 {
                                        self.isOffDay = true
                                        simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) yahoo 休市日")
                                        //不是今天價格，現在又已過今天的開盤時間，那今天就是休市日
                                    } else {
                                        self.isOffDay = false
                                        func  yNumber(_ yColumn:String) -> Double {
                                            let yString = yColumn.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "").replacingOccurrences(of: ",", with: "")
                                            if let dNumber = Double(yString), dNumber != Double.nan {
                                                return dNumber
                                            }
                                            return 0
                                        }
                                        
                                        let close = yNumber(yColumn[1])
                                        if close > 0 {
                                            let context = coreData.shared.context
                                            let trade = Trade.trade(context, stock: stock, date: dt1)
                                            if (dt1 > trade.dateTime || trade.priceClose != close) && trade.tSource != "TWSE" {
                                                self.timeLastTrade = dt1
                                                trade.dateTime = dt1
                                                trade.priceClose = close
                                                trade.priceOpen = yNumber(yColumn[6])
                                                trade.priceHigh = yNumber(yColumn[7])
                                                trade.priceLow  = yNumber(yColumn[8])
                                                trade.tSource   = "yahoo"
                                                trade.tUpdated  = false
                                                try? context.save() //由simTechnical執行trade.objectWillChange.send()
                                                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) yahoo 成交價 \(String(format:"%.2f ",close))" + twDateTime.stringFromDate(dt1, format: "HH:mm:ss"))
                                                self.simTechnical(stock: stock, action: .realtime)
                                            } else {
                                                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) yahoo 未更新 \(String(format:"%.2f",close))")
                                            }
                                        }
                                    }
                                }   //if let dt0
                            }   //if let dt
                        }   //if yColumn.count >= 9
                    } else {  //取quoteTime: if let yDateRange
                        simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) yahoo：解析無交易資料。")
                    }
                }  else { //if let downloadedData =
                    simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) yahoo：下載無資料。")
                }   //if let downloadedData
            } else {
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) yahoo：下載有誤 \(String(describing: error))")
            }   //if error == nil
            //== 下載twse的限制 ==
            //* 連續下載完成後，下一批次須間隔??分鐘
            //* 連續下載每??股須間隔??秒
            var twseCooled:Bool {
                Date().timeIntervalSince(self.timeTradesUpdated) >= self.requestInterval
            }
            let twseGo:Bool = twDateTime.inMarketingTime(delay: 2, forToday: true) && !self.isOffDay && twseCooled
            if twseGo {
                let delay:Int = (self.twseCount / 9) * 3
                self.twseCount += 1
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(delay)) {
                    self.twseGroup.wait()
                    self.twseGroup.enter()
                    if twseCooled {
                        self.twseRealtime(stock) //, allGroup: allGroup, twseGroup: twseGroup)
                    } else {
                        self.progressNotify(self.stockAction == "查詢盤中價" ? 1 : 0)
                        self.twseGroup.leave()
                        self.allGroup.leave()
                    }
                }
            } else {
                self.progressNotify(self.stockAction == "查詢盤中價" ? 1 : 0)
                self.allGroup.leave()
            }
        })  //let task =
        task.resume()
    }
    
    private func matches(for leading: String, with trailing: String, in text: String) -> [String] {
        do {    //依頭尾正規式切割欄位
            let regex = try NSRegularExpression(pattern: leading+"(.*)"+trailing)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            return results.map {nsString.substring(with: $0.range).replacingOccurrences(of: leading, with: "").replacingOccurrences(of: trailing, with: "")}
        } catch let error {
            simLog.addLog("(\(self.stockProgress)/\(self.stockCount))yahoo matches：正規式切割欄位失敗 \( error.localizedDescription)\n\(leading)\n\(trailing)\n\(text)")
            return []
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    enum requestError: Error {
        case error(msg:String)
        case warning(msg:String)
    }

    private var twseCount:Int = 0    
    private func twseRealtime (_ stock:Stock) { //, allGroup:DispatchGroup, twseGroup:DispatchGroup) {
        if self.isOffDay {
            twseGroup.leave()
            allGroup.leave()
            return
        }
        let now = String(format:"%.f",Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "http://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_\(stock.sId).tw&json=1&delay=0&_=\(now)") else {return}
        let urlRequest = URLRequest(url: url,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: {(data, response, error) in
            do {
                guard let jdata = data else { throw requestError.error(msg:"no data") }
                guard let jroot = try JSONSerialization.jsonObject(with: jdata, options: .allowFragments) as? [String:Any] else {throw requestError.error(msg: "invalid jroot") }
                guard let rtmessage = jroot["rtmessage"] as? String else {throw requestError.error(msg:"no rtmessage") }
                if rtmessage != "OK" {
                    throw requestError.error(msg:"invalid rtmessage")
                }
                guard let msgArray = jroot["msgArray"] as? [[String:Any]] else {throw requestError.error(msg:"no msgArray")}

                /*
                 {
                 "msgArray":[
                 {
                 "ts":"0",
                 "tk0":"2330.tw_tse_20170116_B_9999925914",
                 "tk1":"2330.tw_tse_20170116_B_9999925580",
                 "tlong":"1484528728000",                     //目前時間
                 "f":"217_1784_1144_1788_1190_",            //五檔賣量
                 "ex":"tse",                                //tse:上市 otc:上櫃
                 "g":"2165_1133_3126_1611_1962_",           //五檔買量
                 "d":"20170116",                            //日期 <<
                 "it":"12",
                 "b":"179.00_178.50_178.00_177.50_177.00_", //五檔賣價
                 "c":"2330",
                 "mt":"549353",
                 "a":"179.50_180.00_180.50_181.00_181.50_", //五檔賣價
                 "n":"台積電",
                 "o":"180.00",  //開盤價    <<
                 "l":"179.00",  //最低成交價 <<
                 "h":"180.50",  //最高成交價 <<
                 "ip":"0",      //1:趨跌,2:趨漲,4:暫緩收盤,5:暫緩開盤
                 "i":"24",
                 "w":"163.50",  //跌停價
                 "v":"6359",    //累積成交量，未含盤後交易
                 "u":"199.50",  //漲停價
                 "t":"09:05:28",//揭示時間 <<
                 "s":"34",      //當盤成交量
                 "pz":"180.00",
                 "tv":"34",     //當盤成交量
                 "p":"0",
                 "nf":"台灣積體電路製造股份有限公司",
                 "ch":"2330.tw",
                 "z":"179.50",  //最近成交價 <<
                 "y":"181.50",  //昨日成交價 <<
                 "ps":"2459"    //試算參考成交量
                 }
                 ],
                 "userDelay":...
                 ...
                 },
                 "rtcode":"0000"
                 }
                 */

                guard let stockInfo = msgArray.first else {throw requestError.error(msg:"no msgArray.first")}
                let o = Double(stockInfo["o"] as? String ?? "0") ?? 0   //開盤價
                guard o != Double.nan && o != 0 else {throw  requestError.error(msg:"invalid open price")}
                let d = stockInfo["d"] as? String ?? ""   //日期 "20170116"
                let t = stockInfo["t"] as? String ?? ""   //時間 "09:05:28"
                guard let dateTime = twDateTime.dateFromString(d+t, format: "yyyyMMddHH:mm:ss") else {throw requestError.error(msg:"invalid dateTime")}
                
                if (!twDateTime.isDateInToday(dateTime)) && Date() > twDateTime.time0900(delayMinutes: 5) {
                    self.isOffDay = true    //不是今天價格，現在又已過今天的開盤時間，那今天就是休市日
                    simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse 休市日")
                } else {
                    self.isOffDay = false
                    let h = Double(stockInfo["h"] as? String ?? "0") ?? 0    //最高
                    let l = Double(stockInfo["l"] as? String ?? "0") ?? 0    //最低
                    let z = Double(stockInfo["z"] as? String ?? "0") ?? 0    //最新
                    let context = coreData.shared.context
                    let trade = Trade.trade(context, stock: stock, date: dateTime)
                    trade.dateTime = dateTime
                    trade.priceOpen = o
                    trade.priceHigh = h
                    trade.priceLow = l
                    trade.tSource = "twse"
                    if z > 0 {
                        if z != trade.priceClose {
                            self.timeLastTrade = dateTime
                            trade.dateTime = dateTime
                            trade.priceClose = z
                            trade.priceOpen = o
                            trade.priceHigh = h
                            trade.priceLow = l
                            trade.tSource = "twse"
                            try? context.save() //由simTechnical執行trade.objectWillChange.send()
                            self.simTechnical(stock: stock, action: .realtime)
                            simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse 成交價 \(String(format:"%.2f ",z))" + twDateTime.stringFromDate(dateTime, format: "HH:mm:ss"))
                        } else {
                            simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse 未更新 \(String(format:"%.2f",z))")
                        }
                    } else {
                        simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse 無交易")
                    }
                }   //self.isOffDay = false
                    
            } catch requestError.error(let msg) {   //error就放棄結束
                if twDateTime.inMarketingTime() {
                    self.timeTradesUpdated = Date() //讓後面排隊的twseRequest不足冷卻時間而先放棄
                }
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse timeout? \(msg)")
                //可能是被TWSE拒絕連線而逾時
            } catch requestError.warning(let msg) {    //warn可能只是cookie失敗，重試
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse warning: \(msg)")
            } catch {
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))\(stock.sId)\(stock.sName) twse error: \(error)")
            }   //do
            self.progressNotify(self.stockAction == "查詢盤中價" ? 1 : 0)
            self.twseGroup.leave()
            self.allGroup.leave()
        })
        task.resume()
    }

    private func twseCookie() {
        //1.先取得cookie
        guard let url = URL(string: "http://mis.twse.com.tw/stock/fibest.jsp?lang=zh_tw") else {return}
        let request = URLRequest(url: url,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
            guard error == nil else {
                simLog.addLog("(\(self.stockProgress)/\(self.stockCount))twse cookie error? \(String(describing: error))\n")
                return
            }
            //2.再抓指數過場
            let now = String(format:"%.f",Date().timeIntervalSince1970 * 1000)
            let uString = "http://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_t00.tw%7cotc_o00.tw%7ctse_FRMSA.tw&json=1&delay=0&_=\(now)"
            guard let url = URL(string: uString) else {return}
            let request = URLRequest(url: url,timeoutInterval: 30)
            URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                guard error == nil else {
                    simLog.addLog("(\(self.stockProgress)/\(self.stockCount))twse cookie error? \(String(describing: error))\n")
                    return
                }
            }).resume()
        })
        task.resume()
    }


    
    
    
    
    
    
    
    
    
    
    


    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    private func tUpdate(_ trades:[Trade], index:Int) {
        let trade = trades[index]
        let demandIndex:Double = (trade.priceHigh + trade.priceLow + (trade.priceClose * 2)) / 4    //算macd用的
        if index > 0 {
            let prev = trades[index - 1]
            let d9  = tradeIndex(9, index:index)
            let d20 = tradeIndex(20, index:index)
            let d60 = tradeIndex(60, index:index)
            //250天約是1年，375是1年半，125天是半年
            let d125 = tradeIndex(125, index: index)
            let d250 = tradeIndex(250, index: index)

            let maxDouble:Double = Double.greatestFiniteMagnitude
            let minDouble:Double = Double.leastNormalMagnitude
            
            var sum60:Double = 0
            var sum20:Double = 0
            //9天最高價最低價  <-- 要先提供9天高低價計算RSV，然後才能算K,D,J
            var highMax9:Double = -1    //minDouble
            var lowMin9:Double = maxDouble
            var ma60Sum:Double = 0
            for (i,t) in trades[d60.thisIndex...index].enumerated() {
                sum60 += t.priceClose
                if i + d60.thisIndex >= d20.thisIndex {
                    sum20 += t.priceClose
                }
                if i + d60.thisIndex >= d9.thisIndex {
                    if highMax9 < t.priceHigh {
                        highMax9 = t.priceHigh
                    }
                    if lowMin9 > t.priceLow {
                        lowMin9 = t.priceLow
                    }
                }
                ma60Sum += t.tMa60Diff  //但是自己的ma60Diff還是0
            }
            //最高價差、最低價差
            let nextLow  = 100 * (prev.priceClose - trade.priceLow + priceDiff(trade.priceLow)) / prev.priceClose
            let nextHigh = 100 * (trade.priceHigh + priceDiff(trade.priceHigh) - prev.priceClose) / prev.priceClose
            trade.tLowDiff  = (nextLow > 10 ? 10 : 100 * (prev.priceClose - trade.priceLow) / prev.priceClose)
            trade.tHighDiff = (nextHigh > 10 ? 10 : 100 * (trade.priceHigh - prev.priceClose) / prev.priceClose)

            //ma60,ma20
            trade.tMa60 = sum60 / d60.thisCount
            trade.tMa20 = sum20 / d20.thisCount
            trade.tMa60Diff    = round(10000 * (trade.priceClose - trade.tMa60) / trade.priceClose) / 100
            trade.tMa20Diff    = round(10000 * (trade.priceClose - trade.tMa20) / trade.priceClose) / 100
            
            //9天最高價最低價  <-- 要先提供9天高低價計算RSV，然後才能算K,D,J
            var kdRSV:Double = 50
            if highMax9 != lowMin9 {
                kdRSV = 100 * (trade.priceClose - lowMin9) / (highMax9 - lowMin9)
            }

            //k, d, j
            trade.tKdK = ((2 * prev.tKdK / 3) + (kdRSV / 3))
            trade.tKdD = ((2 * prev.tKdD / 3) + (trade.tKdK / 3))
            trade.tKdJ = ((3 * trade.tKdK) - (2 * trade.tKdD))
            
            //MACD
            let doubleDI:Double = 2 * demandIndex
            trade.tOscEma12 = ((11 * prev.tOscEma12) + doubleDI) / 13
            trade.tOscEma26 = ((25 * prev.tOscEma26) + doubleDI) / 27
            let dif:Double = trade.tOscEma12 - trade.tOscEma26
            let doubleDif:Double = 2 * dif
            trade.tOscMacd9 = ((8 * prev.tOscMacd9) + doubleDif) / 10
            trade.tOsc = dif - trade.tOscMacd9
            
            trade.tMa20DiffMax9 = trade.tMa20Diff
            trade.tMa20DiffMin9 = trade.tMa20Diff
            trade.tMa60DiffMax9 = trade.tMa60Diff
            trade.tMa60DiffMin9 = trade.tMa60Diff
            trade.tOscMax9 = trade.tOsc
            trade.tOscMin9 = trade.tOsc
            trade.tKdKMax9 = trade.tKdK
            trade.tKdKMin9 = trade.tKdK
            for t in trades[d9.thisIndex...index] {
                //9天最高最低
                if t.tMa20Diff > trade.tMa20DiffMax9 {
                    trade.tMa20DiffMax9 = t.tMa20Diff
                }
                if t.tMa20Diff < trade.tMa20DiffMin9 {
                    trade.tMa20DiffMin9 = t.tMa20Diff
                }
                if t.tMa60Diff > trade.tMa60DiffMax9 {
                    trade.tMa60DiffMax9 = t.tMa60Diff
                }
                if t.tMa60Diff < trade.tMa60DiffMin9 {
                    trade.tMa60DiffMin9 = t.tMa60Diff
                }
                if t.tOsc > trade.tOscMax9 {
                    trade.tOscMax9 = t.tOsc
                }
                if t.tOsc < trade.tOscMin9 {
                    trade.tOscMin9 = t.tOsc
                }
                if t.tKdK > trade.tKdKMax9 {
                    trade.tKdKMax9 = t.tKdK
                }
                if t.tKdK < trade.tKdKMin9 {
                    trade.tKdKMin9 = t.tKdK
                }
            }

            //半年、1年、1年半內的最高價、最低價到今天跌或漲了多少
            func priceHighAndLow (_ dIndex:(prevIndex:Int,prevCount:Double,thisIndex:Int,thisCount:Double)) -> (highDiff:Double, lowDiff:Double) {
                var high:Double = minDouble
                var low:Double = maxDouble
                for t in trades[dIndex.thisIndex...index] {
                    if t.priceHigh > high {
                        high = t.priceHigh
                    }
                    if t.priceLow < low {
                        low = t.priceLow
                    }
                }
                let highDiff:Double = 100 * (trade.priceClose - high) / high
                let lowDiff:Double  = 100 * (trade.priceClose - low) / low
                return (highDiff,lowDiff)
            }
            let pDiff125  = priceHighAndLow(d125)
            let pDiff250  = priceHighAndLow(d250)
            trade.tHighDiff125 = pDiff125.highDiff
            trade.tHighDiff250 = pDiff250.highDiff
            trade.tLowDiff125  = pDiff125.lowDiff
            trade.tLowDiff250  = pDiff250.lowDiff

            //ma60,Osc,K在半年、1年、1年半內的標準分數
            func standardDeviationZ(_ key:String, dIndex:(prevIndex:Int,prevCount:Double,thisIndex:Int,thisCount:Double)) -> Double {
                var sum:Double = 0
                for t in trades[dIndex.thisIndex...index] {
                    sum += (t.value(forKey: key) as? Double ?? 0)   //總計
                }
                let avg = sum / dIndex.thisCount  //平均值
                var vsum:Double = 0
                for t in trades[dIndex.thisIndex...index] {
                    let variance = pow(((t.value(forKey: key) as? Double ?? 0) - avg),2)  //偏差值
                    vsum += variance
                }
                let sd = sqrt(vsum / dIndex.thisCount) //標準差
                let zScore = ((trade.value(forKey: key) as? Double ?? 0) - avg) / sd     //標準分數
                return zScore
            }
            trade.tKdKZ125  = standardDeviationZ("tKdK", dIndex:d125)
            trade.tKdKZ250  = standardDeviationZ("tKdK", dIndex:d250)
            trade.tKdDZ125  = standardDeviationZ("tKdD", dIndex:d125)
            trade.tKdDZ250  = standardDeviationZ("tKdD", dIndex:d250)
            trade.tKdJZ125  = standardDeviationZ("tKdJ", dIndex:d125)
            trade.tKdJZ250  = standardDeviationZ("tKdJ", dIndex:d250)
            trade.tOscZ125  = standardDeviationZ("tOsc", dIndex:d125)
            trade.tOscZ250  = standardDeviationZ("tOsc", dIndex:d250)
            trade.tMa20DiffZ125 = standardDeviationZ("tMa20Diff", dIndex:d125)
            trade.tMa20DiffZ250 = standardDeviationZ("tMa20Diff", dIndex:d250)
            trade.tMa60DiffZ125 = standardDeviationZ("tMa60Diff", dIndex:d125)
            trade.tMa60DiffZ250 = standardDeviationZ("tMa60Diff", dIndex:d250)

            var ma20DaysBefore: Double = 0
            if prev.tMa20Days < 0 && prev.tMa20Days > -5 && index >= Int(0 - prev.tMa20Days + 1) {
                ma20DaysBefore = trades[index - Int(0 - prev.tMa20Days + 1)].tMa20Days
            } else if prev.tMa20Days > 0 && prev.tMa20Days < 5 && index > Int(prev.tMa20Days + 1) {
                ma20DaysBefore = trades[index - Int(prev.tMa20Days + 1)].tMa20Days
            }
            if trade.tMa20 > prev.tMa20 {
                if prev.tMa20Days < 0  {
                    if prev.tMa20Days > -5 && ma20DaysBefore > 0 {
                        trade.tMa20Days = ma20DaysBefore + 1
                    } else {
                        trade.tMa20Days = 1
                    }
                } else {
                    trade.tMa20Days = prev.tMa20Days + 1
                }
            } else if trade.tMa20 < prev.tMa20 {
                if prev.tMa20Days > 0  {
                    if prev.tMa20Days < 5 && ma20DaysBefore < 0 {
                        trade.tMa20Days = ma20DaysBefore - 1
                    } else {
                        trade.tMa20Days = -1
                    }
                } else {
                    trade.tMa20Days = prev.tMa20Days - 1
                }
            } else {
                if prev.tMa20Days > 0 {
                    trade.tMa20Days = prev.tMa20Days + 1
                } else if prev.tMa20Days < 0 {
                    trade.tMa20Days = prev.tMa20Days - 1
                } else {
                    trade.tMa20Days = 0
                }
            }


            var ma60DaysBefore: Double = 0
            if prev.tMa60Days < 0 && prev.tMa60Days > -5 && index >= Int(0 - prev.tMa60Days + 1) {
                ma60DaysBefore = trades[index - Int(0 - prev.tMa60Days + 1)].tMa60Days
            } else if prev.tMa60Days > 0 && prev.tMa60Days < 5 && index >= Int(prev.tMa60Days + 1) {
                ma60DaysBefore = trades[index - Int(prev.tMa60Days + 1)].tMa60Days
            }
            if trade.tMa60 > prev.tMa60 {
                if prev.tMa60Days < 0  {
                    if prev.tMa60Days > -5 && ma60DaysBefore > 0 {
                        trade.tMa60Days = ma60DaysBefore + 1
                    } else {
                        trade.tMa60Days = 1
                    }
                } else {
                    trade.tMa60Days = prev.tMa60Days + 1
                }
            } else if trade.tMa60 < prev.tMa60 {
                if prev.tMa60Days > 0  {
                    if prev.tMa60Days < 5 && ma60DaysBefore < 0 {
                        trade.tMa60Days = ma60DaysBefore - 1
                    } else {
                        trade.tMa60Days = -1
                    }
                } else {
                    trade.tMa60Days = prev.tMa60Days - 1
                }
            } else {
                if prev.tMa60Days > 0 {
                    trade.tMa60Days = prev.tMa60Days + 1
                } else if prev.tMa60Days < 0 {
                    trade.tMa60Days = prev.tMa60Days - 1
                } else {
                    trade.tMa60Days = 0
                }
            }
            if d250.thisCount >= 250 {
                trade.tUpdated = true
            } else {
                trade.tUpdated = false
            }
        } else {
            trade.tKdK = 50
            trade.tKdD = 50
            trade.tKdJ = 50
            trade.tOscEma12 = demandIndex
            trade.tOscEma26 = demandIndex
            trade.tUpdated = false
        }

    }
    
    func tradeIndex(_ count:Double, index:Int) ->  (prevIndex:Int,prevCount:Double,thisIndex:Int,thisCount:Double) {
        let cnt:Double = (count < 1 ? 1 : round(count)) //count最小是1
        var prevIndex:Int = 0       //前第幾筆的Index不包含自己
        var prevCount:Double = 0    //前第幾筆的總筆數不包含自己
        var thisIndex:Int = 0       //前第幾筆的Index有包含自己
        var thisCount:Double = 0    //前第幾筆的總筆數有包含自己
        if index >= Int(cnt) {
            prevCount = cnt //前1天那筆開始算往前有幾筆用來平均ma60，含前1天自己
            prevIndex = index - Int(cnt)   //是自第幾筆起算
            thisCount = cnt
            thisIndex = prevIndex + 1
        } else {
            prevCount = Double(index)
            thisCount = prevCount + 1
            thisIndex = 0
            prevIndex = 0
        }
        return (prevIndex,prevCount,thisIndex,thisCount)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    private func simUpdate(_ trades:[Trade], index:Int) {
        let trade = trades[index]
        if index == 0 || trade.date < trade.stock.dateStart {
            trade.setDefaultValues()
            trade.simRule = "_"
            return
        }
        let prev = trades[index - 1]
        trade.resetSimValues()
        trade.rollDays = prev.rollDays
        //cost,profit,roi:等最後面更新才有效，但grade會參考到，故...
        trade.rollAmtCost = prev.rollAmtCost
        trade.rollAmtProfit = prev.rollAmtProfit
        trade.rollAmtRoi = prev.rollAmtRoi
        //cost,profit,roi:需跟著上一筆更動，期間變動重算模擬時，判斷條件才會一致
        trade.simAmtBalance = (prev.simRule == "_" ? trade.stock.simMoneyBase * 10000 : prev.simAmtBalance)
        trade.simInvestTimes = prev.simInvestTimes
        trade.rollRounds = prev.rollRounds
        var rollAmtCost = prev.rollAmtCost * prev.rollDays
        if prev.simQtyInventory > 0 { //前筆有庫存，更新結餘
            trade.simAmtCost = prev.simAmtCost
            trade.simQtyInventory = prev.simQtyInventory
            trade.simUnitCost = prev.simUnitCost
            trade.simUnitRoi = 100 * (trade.priceClose - trade.simUnitCost) / trade.simUnitCost
            let intervalDays = round(Double(trade.date.timeIntervalSince(prev.date)) / 86400)
            trade.simDays = prev.simDays + intervalDays
            trade.rollDays += intervalDays
            trade.simRuleBuy = prev.simRuleBuy
            rollAmtCost -= (prev.simAmtCost * prev.simDays)
        } else { //前筆沒有庫存，就沒有成本什麼的
            if prev.simQtySell > 0 {
                trade.simInvestByUser = 0
                if trade.simInvestTimes > 1 {
                    trade.simInvestAdded = 1 - trade.simInvestTimes
                } else {
                    trade.simInvestAdded = 0                    
                }
            } else if trade.simInvestTimes == 0 {
                trade.simInvestTimes = 1
            }
        }

//        if twDateTime.stringFromDate(trade.dateTime) == "2020/08/31" && trade.stock.sId == "1515" {
//            NSLog("\(trade.stock.sId)\(trade.stock.sName) tracking... ")
//        }
        
        let ma20d = trade.tMa20DiffMax9 - trade.tMa20DiffMin9
        let ma60d = trade.tMa60DiffMax9 - trade.tMa60DiffMin9

        //*** Z=P? ***
        //0.84=0.7995 0.85=0.8023 1=0.8413 1.04=0.8508 1.3=0.9032 1.45=0.9265 1.5=0.9332
        //1.55=0.9394 1.65=0.9505 2=0.9772 3=0.9987 3.5=0.9998
        //-0.84=0.2005 -0.85=0.1977 -0.67=0.2514 -0.68=0.2483
        
        //== 高買 ==================================================
        var wantH:Double = 0
        wantH += (trade.tMa60DiffZ125 > (trade.grade > .weak ? 0.75 : 0.85) && trade.tMa60DiffZ125 < (trade.grade <= .low ? 2 : 2.5) ? 1 : 0)
        wantH += (trade.tMa20Diff - trade.tMa60Diff > 1 && trade.tMa20Days > 0 ? 1 : 0)
        wantH += ((trade.tMa60Diff > (trade.grade <= .weak ? -0.5 : 0) && trade.tMa20Diff > (trade.grade <= .weak ? -0.5 : 0)) || trade.grade == .damn ? 1 : 0)
        wantH += (trade.tMa60DiffMax9 > 30 && trade.grade <= .fine  ? 1 : 0)
        wantH += (trade.tMa20DiffMax9 > 35 && trade.grade <= .none  ? 1 : 0)    //只有某年1次有效？
//        wantH += (trade.tMa20DiffMin9 > 0 && trade.tMa60DiffMin9 > 0 && trade.grade <= .weak ? 1 : 0)

        wantH += (trade.tKdKZ125 < -0.8 ? -1 : 0)
        wantH += (trade.tOscZ125 < -0.5 ? -1 : 0)
        wantH += (trade.tKdJZ125 > 2 ? -1 : 0)
        wantH += (trade.tHighDiff125 < -20 ? -1 : 0)
        wantH += (trade.tMa60DiffZ125 < -2 || trade.tMa20DiffZ125 > 3 ? -1 : 0) //Ma60過低, Ma20過高
        wantH += (trade.tLowDiff125 - trade.tHighDiff125 < 15 ? -1 : 0)
        wantH += (trade.tMa60Diff == trade.tMa60DiffMax9 && trade.tMa20Diff == trade.tMa20DiffMax9 && trade.tMa20DiffZ125 > 2.5 ? -1 : 0)
        wantH += ((trade.tMa60Diff == trade.tMa60DiffMin9 || trade.tMa20Diff == trade.tMa20DiffMin9 || trade.tOsc == trade.tOscMin9 || trade.tKdK == trade.tKdKMin9) && trade.grade >= .low ? -1 : 0)
        wantH += (trade.grade <= .weak && (ma20d > 6 || ma60d > 7) ? -1 : 0)
        wantH += (trade.grade == .damn && (ma20d > 6 || ma60d > 7) ? -1 : 0)
        wantH += (trade.tMa20DiffZ125 > 1.6 && trade.grade <= .damn ? -1 : 0)
        wantH += (trade.tMa20Diff > 0 && (trade.tMa20DiffMax9 - trade.tMa20Diff) < (trade.grade <= .weak ? 1.5 : 2) && (trade.tMa20DiffZ125 > 1.5 && trade.tMa60DiffZ125 > 1.5) && (trade.grade >= .weak && trade.grade <= .none) ? -1 : 0)

        if wantH >= 1 {
            if (trade.grade <= .weak && prev.priceClose < trade.priceClose) && (prev.simRule == "H" || prev.simRule == "I") {
                trade.simRule = "I"
            } else {
                trade.simRule = "H"
            }
        }
        if trade.simRule == "" {
            //== 低買 ==================================================
            var wantL:Double = 0
            wantL += (trade.tKdJ < -1 ? 1 : 0)
            wantL += (trade.tKdJ < -7 ? 1 : 0)
            wantL += (trade.tKdK < 9 ? 1 : 0)
            wantL += (trade.tKdKZ125 < -0.9 && trade.tKdKZ250 < -0.9 ? 1 : 0)
            wantL += (trade.tOscZ125 < -0.9 && trade.tOscZ250 < -0.9 ? 1 : 0)
            wantL += (trade.tKdDZ125 < -0.9 && trade.tKdDZ250 < -0.9 ? 1 : 0)
            wantL += (trade.tKdD - trade.tKdK > 20 && trade.tKdK < 40 && trade.grade <= .weak ? 1 : 0)
//            wantL += (trade.tOscMin9 < (trade.grade <= .low ? 0.5 : 0) && trade.tOsc > trade.tOscMin9 && trade.grade <= .none ? 1 : 0)

            wantL += (trade.tMa20Days < -30 ? -1 : 0)
            wantL += (trade.tLowDiff >= (trade.grade <= .none ? 9 : 8) && trade.grade >= .weak ? -1 : 0) //或是 >= .low
            wantL += (trade.tMa60Diff == trade.tMa60DiffMin9 && trade.tMa20Diff == trade.tMa20DiffMin9 && trade.tOsc == trade.tOscMin9 && (trade.grade <= .damn || trade.grade >= .wow) ? -1 : 0)   //&& trade.tKdK == trade.tKdKMin9

            if wantL >= 5 {
                trade.simRule = "L"
            }
        }
        
        if trade.simQtyInventory > 0 {
            //== 賣出 ==================================================
            var wantS:Double = 0
            wantS += (trade.tKdJ > 101 ? 1 : 0)
            wantS += (trade.tKdJZ125 > 1.0 && trade.tKdJZ250 > 1.0 ? 1 : 0)
            wantS += (trade.tKdKZ125 > 0.9 && trade.tKdKZ250 > 0.9 ? 1 : 0)
            wantS += (trade.tKdDZ125 > 0.9 && trade.tKdDZ250 > 0.9 ? 1 : 0)
            wantS += (trade.tOscZ125 > 0.9 && trade.tOscZ250 > 0.9 ? 1 : 0)
            wantS += (trade.tHighDiff >= (trade.grade <= .none ? 9 : 7.5) ? -1 : 0)
//            wantS += (trade.tHighDiff == 10 && trade.grade >= .weak ? -1 : 0)
//            wantS += ((trade.tOsc == trade.tOscMin9 ? 1 : 0) + (trade.tKdK == trade.tKdKMin9 ? 1 : 0) + (trade.tMa20Diff == trade.tMa20DiffMin9 ? 1 : 0) + (trade.tMa60Diff == trade.tMa60DiffMin9 ? 1 : 0) >= 3 && trade.tMa60DiffZ125 < -1.5 ? 1 : 0)
            let topWantS:Double = 5

            let weekendDays:Double = (twDateTime.calendar.component(.weekday, from: trade.dateTime) <= 2 ? 2 : 0)
            let sRoi19 = trade.simUnitRoi > (trade.grade > .weak ? 21.5 : 19.5) && trade.simDays < (trade.tMa60DiffZ250 > 0 ? 30 : 90)
            let forRoiH = trade.tMa60DiffZ250 > 0
            let sRoi15 = trade.simUnitRoi > (forRoiH ? 15.5 : 11.5) && trade.simDays < 30
            let sRoi13 = trade.simUnitRoi > (forRoiH ? 13.5 : 9.5) && trade.simDays < 20
            let sRoi09 = trade.simUnitRoi > (forRoiH ? 9.5 : 7.5) && trade.simDays < 10
            let sRoi03 = trade.simUnitRoi > 3.5 && (trade.tKdKZ125 > 1.5 || trade.tOscZ125 > 1.5)
            let sRoi02 = trade.simUnitRoi > (trade.grade <= .weak ? 1.5 : 2.5)
            let sRoi00 = trade.simUnitRoi > 0.45 && trade.simDays > (1 + weekendDays)
            let sBase5 = wantS >= topWantS && sRoi00 && trade.grade <= .weak
            let sBase4 = wantS >= (topWantS - 1) && sRoi02
            let sBase3 = wantS >= (topWantS - 2) && sRoi00 && trade.simDays > 75
            let sBase2 = wantS >= (topWantS - 3) && (sRoi15 || sRoi13 || sRoi09 || sRoi03)
            
            var noInvested60:Bool = true
            var noInvested45:Bool = true
            let d60 = tradeIndex(60, index: index)
            for (i,t) in trades[d60.prevIndex...(index - 1)].reversed().enumerated() {
                if t.invested == 1 {
                    if i < 45 {
                        noInvested45 = false
                    }
                    noInvested60 = false
                } else if t.simDays <= 1 {
                    break
                }
            }
            let cut1a = trade.tLowDiff125 - trade.tHighDiff125 < 30 && trade.simDays > 200
            let cut1b = trade.simUnitRoi > -15 && (trade.grade > .weak)
            let cut1c = trade.simUnitRoi > -20 && (trade.simDays > 300 || trade.grade <= .weak)
            let cut1  = cut1a && (cut1b || cut1c)
            let cut2 = trade.simDays > 400 && trade.simUnitRoi > (trade.grade <= .weak ? -20 : -15)
            let sCut = wantS >= (topWantS - (trade.simDays > 400 ? 4 : 3)) && (cut1 || cut2) && noInvested60

            var sell:Bool = sBase5 || sBase4 || sBase3 || sBase2 || sCut || sRoi19
            
            //== 反轉賣 ==
            if sell && trade.simReversed == "S-" {
                sell = false
            } else if sell == false && trade.simReversed == "S+" {
                sell = true
            } else if trade.simReversed != "B+" && trade.simReversed != "B-" {
                trade.simReversed = ""
            }
            
			//不管賣不賣得成，要算好損益含稅費？？？
            if sell {
                trade.simQtySell = trade.simQtyInventory
                trade.simQtyInventory = 0
            } else {
                //== 加碼 ==================================================
                var aWant:Double = 0
                let z125a = (trade.tMa20DiffZ125 < -1 ? 1 : 0) + (trade.tMa60DiffZ125 < -1 ? 1 : 0) + (trade.tKdKZ125 < -1 ? 1 : 0) + (trade.tKdDZ125 < -1 ? 1 : 0) + (trade.tKdJZ125 < -1 ? 1 : 0) + (trade.tOscZ125 < -1 ? 1 :0)
                aWant += (z125a >= 2 || trade.grade <= .weak ? 1 : 0)
                aWant += (trade.simUnitRoi < -35 ? 1 : 0)
                aWant += (trade.tHighDiff125 < -35 ? 1 : 0)
                aWant += (trade.tMa20Diff < -20 || trade.tMa60Diff < -20 ? 1 : 0)
                aWant += (trade.tMa20Diff < -8 && trade.tMa60Diff < -8 ? 1 : 0)
                aWant += (trade.tMa60Diff == trade.tMa60DiffMin9 && trade.tMa20Diff == trade.tMa20DiffMin9 ? 1 : 0)
                aWant += (trade.simRule == "L" && trade.simUnitRoi < -25 ? 1 : 0)
                aWant += (trade.grade >= .none ? -2 : 0)    //已測試必須none以上減兩分，不能weak/none/fine交錯各減1分
                aWant += (trade.tLowDiff >= 8.5 && trade.grade <= .low ? -1 : 0)
                
                let aRoi30 = trade.simUnitRoi < -30
                let aRoi25 = trade.simUnitRoi < -25 && (trade.simDays < 180 || trade.simDays > 360)
                let aRoi15 = trade.simUnitRoi < -15 && trade.simDays >= 180 && trade.simRule == "L"
                let addInvest = (aRoi30 || aRoi25 || aRoi15) && aWant > 3
                
                if addInvest {
                    trade.simRuleInvest = "A"
                }
                if trade.simRuleInvest == "A" {
                    if trade.stock.simAutoInvest > 9 || trade.simInvestTimes <= trade.stock.simAutoInvest  { //自動加碼
                        if noInvested45 || (trade.simUnitRoi < -50 && trade.grade >= .fine) {
                            trade.simInvestAdded = 1
                        }
                    }
                } else {
                    trade.simInvestAdded = 0
                    trade.simInvestByUser = 0
                }
            }
        }
        if trade.invested != 0 {  //若前筆賣股則這裡抽回加碼本金，或這裡加碼則增加本金
            trade.simInvestTimes += trade.invested
            trade.simAmtBalance += (trade.invested * trade.stock.simMoneyBase * 10000)
        }

        var buyIt:Bool = false
        if trade.simAmtBalance > 0 && trade.simQtySell == 0 {    //有可能之前賠超過1個本金而不夠買
            if trade.simRuleBuy == "" && (trade.simRule == "H" || trade.simRule == "L") {
                trade.simRuleBuy = trade.simRule
                buyIt = true
            } else if trade.invested > 0 {
                buyIt = true
            }
            //== 考慮延後買的情況 ==
//            let d3 = tradeIndex(3, index: index)
//            for t in trades[d3.prevIndex...index - 1] {
//                if t.simQtySell > 0 && t.simReversed == "" {
//                    trade.simRuleBuy = ""
//                    buyIt = false
//                    break
//                }
//            }
            if prev.simQtySell > 0 && prev.simReversed == "" {
                buyIt = false
                trade.simRuleBuy = ""
            }
        }
        
        let oneFee  = round(trade.priceClose * 1.425)    //1張的手續費
        let oneCost = (trade.priceClose * 1000) + (oneFee > 20 ? oneFee : 20)  //只買1張的成本
        if buyIt && trade.simAmtBalance < oneCost {
           //錢不夠先清除buyRule以簡化後面反轉的判斷規則
            buyIt = false
        }

        //== 反轉買 ==
        if buyIt && trade.simQtyInventory == 0 && trade.simReversed == "B-" {
            buyIt = false
        } else if buyIt == false && trade.simQtyInventory == 0 && trade.simReversed == "B+" {
            buyIt = true
            trade.simRuleBuy = "R"
        } else if trade.simReversed != "S+" && trade.simReversed != "S-" {
            if trade.simQtyInventory == 0 { //都不是就不要改simReverse因為可能真的反轉「賣」「不賣」
                trade.simReversed = ""
            }
        }

        
        if buyIt {
  
            var money:Double = (trade.simInvestTimes * trade.stock.simMoneyBase * 10000) - trade.simAmtCost
            //反轉買錢又不夠時，會維持預設本金即給足1個本金的額度
            if money > trade.simAmtBalance && (trade.simReversed == "" || trade.simAmtBalance > oneCost) {
                money = trade.simAmtBalance //否則即使餘額賠剩足以買1張，就只用賠後餘額繼續買
            }
            let unitCost:Double = trade.priceClose * 1000 * 1.001425 //每張含手續費的成本
            var estimateQty = floor(money / unitCost)             //則可以買這麼多張
            let feeQty:Double = ceil(20 / (trade.priceClose * 1.425))   //20元的手續費可買這麼多張
            //手續費最少20元，買不到feeQty張數則手續費要算20元
            if estimateQty < feeQty {
                estimateQty = floor((money - 20) / (trade.priceClose * 1000))
            }
            trade.simQtyBuy = estimateQty

            if trade.simQtyBuy == 0 && money > oneCost {
                trade.simQtyBuy = 1    //剩餘資金剛好只夠購買1張，就買咩
            }
            if trade.simQtyBuy > 0 {
                if trade.simQtyInventory == 0 { //首次買入
                    trade.simDays = 1
                    trade.rollRounds += 1
                    trade.rollDays += 1
                }
                var cost = round(trade.priceClose * trade.simQtyBuy * 1000)
                var fee = round(trade.priceClose * trade.simQtyBuy * 1000 * 0.001425)
                if fee < 20 {
                    fee = 20
                }
                cost += fee
                trade.simAmtBalance -= cost
                trade.simAmtCost += cost
                trade.simQtyInventory += trade.simQtyBuy
            }
        }
        if trade.simQtyInventory > 0 || trade.simQtySell > 0 {  //不管有沒有買賣，因為收盤價變了就需要重算報酬率
            let qty = trade.simQtyInventory > 0 ? trade.simQtyInventory : trade.simQtySell
            var fee = round(trade.priceClose * qty * 1000 * 0.001425)
            if fee < 20 {   //這是賣時的手續費
                fee = 20
            }
            let tax = round(trade.priceClose * qty * 1000 * 0.003)
            trade.simAmtProfit = (trade.priceClose * qty * 1000) - trade.simAmtCost - fee - tax
            trade.simAmtRoi = 100 * trade.simAmtProfit / trade.simAmtCost
            trade.simUnitCost = trade.simAmtCost / (1000 * qty) //就是除以1000股然後四捨五入到小數2位
            trade.simUnitRoi = 100 * (trade.priceClose - trade.simUnitCost) / trade.simUnitCost
            if trade.simQtySell > 0 {
                trade.simAmtBalance += (trade.priceClose * trade.simQtySell * 1000) - fee - tax
            }
        }
        
        //== 更新累計數值 ==
//        if twDateTime.stringFromDate(trade.dateTime) == "2020/05/28" && trade.stock.sId == "1476" {
//            NSLog("\(trade.stock.sId)\(trade.stock.sName) debug ... ")
//        }
        if trade.rollDays > 0 {
            trade.rollAmtCost = (rollAmtCost + (trade.simAmtCost * trade.simDays)) / trade.rollDays
        }
        if trade.rollAmtCost > 0 {  
			//即使simQtyInventory是0也可能是剛賣出，所以還是要重算累計損益
			//剛賣時損益已計入simAmtBalance故不要重複計算
			//算rollAmtProfit是先加總現值再扣本金，故需計入simAmtCost
            trade.rollAmtProfit = (trade.simQtyInventory == 0 ? 0 : (trade.simAmtProfit + trade.simAmtCost)) + trade.simAmtBalance - (trade.simInvestTimes * trade.stock.simMoneyBase * 10000)
            trade.rollAmtRoi = 100 * trade.rollAmtProfit / trade.rollAmtCost
        }
    }
}

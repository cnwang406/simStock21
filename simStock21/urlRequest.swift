//
//  urlRequest.swift
//  simStock21
//
//  Created by peiyu on 2020/7/11.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation

class urlRequest {
    let defaults = UserDefaults.standard
    var isOffDay:Bool = false
    var timer:Timer?
    var timeTradesDownloaded:Date
    
    func tradesUpdated(time:Date) {
        timeTradesDownloaded = time
        defaults.set(time, forKey: "timeTradesDownloaded")
    }


    init() {
        timeTradesDownloaded = defaults.object(forKey: "timeTradesDownloaded") as? Date ?? Date.distantPast
    }
    
    func runRequest(stocks:[Stock], all:Bool=true) {
        let realtime:Bool = twDateTime.isDateInToday(timeTradesDownloaded) && twDateTime.inMarketingTime(timeTradesDownloaded, delay: 2)
        NSLog((realtime && !all ? "下載盤中交易..." : "下載歷史交易...") + (realtime ? "timer scheduled." : "timer invalidated."))
        for stock in stocks {
            if realtime && !all {
                self.yahooRequest(stock)
            } else {
                let requestGroup:DispatchGroup = DispatchGroup()
                cnyesPrice(stock: stock, dGroup: requestGroup)
                requestGroup.notify(queue: .global()) {
                    self.simTechnical(stock: stock)
                    if realtime {
                        self.yahooRequest(stock)
                    }
                }
            }
        }
        if realtime {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1 * 60, repeats: false) {_ in
                    self.runRequest(stocks: stocks, all: false)
            }
        } else {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    func twseDailyMI() {
        //        let y = calendar.component(.Year, fromDate: qDate) - 1911
        //        let m = calendar.component(.Month, fromDate: qDate)
        //        let d = calendar.component(.Day, fromDate: qDate)
        //        let YYYMMDD = String(format: "%3d/%02d/%02d", y,m,d)
        //================================================================================
        //從當日收盤行情取股票代號名稱
        //2017-05-24因應TWSE網站改版變更查詢方式為URLRequest
        //http://www.twse.com.tw/exchangeReport/MI_INDEX?response=csv&date=20170523&type=ALLBUT0999

        let url = URL(string: "http://www.twse.com.tw/exchangeReport/MI_INDEX?response=csv&type=ALLBUT0999")
        let request = URLRequest(url: url!,timeoutInterval: 30)

        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
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
//                            let progress:Float = Float(index+1) / Float(lines.count)
//                            OperationQueue.main.addOperation {
//                                self.uiProgress.setProgress(progress, animated: true)
//                            }

                        }   //if line != ""
                    } //for
                    try? context.save()
                    self.defaults.set(Date(), forKey: "timeStocksDownloaded")
                    NSLog("twseDailyMI(ALLBUT0999): \(allStockCount)筆")
                }   //if let downloadedData
            } else {  //if error == nil
                self.defaults.removeObject(forKey: "timeStocksDownloaded")
                NSLog("twseDailyMI(ALLBUT0999) error:\(String(describing: error))")
            }
        })
        task.resume()
    }


    func cnyesRequest(_ stock:Stock, ymdStart:String, ymdEnd:String, dGroup:DispatchGroup) {
        dGroup.enter()
        let url = URL(string: "http://www.cnyes.com/archive/twstock/ps_historyprice.aspx?code=\(stock.sId)&ctl00$ContentPlaceHolder1$startText=\(ymdStart)&ctl00$ContentPlaceHolder1$endText=\(ymdEnd)")
        let request = URLRequest(url: url!,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
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
                        for line in lines {
                            if let dt0 = twDateTime.dateFromString(line.components(separatedBy: ",")[0]) {
                                let dateTime = twDateTime.time1330(dt0)
                                if let close = Double(line.components(separatedBy: ",")[4]) {
                                    if close > 0 {
                                        tradesCount += 1
                                        if dt0 < firstDate {
                                            firstDate = dt0
                                        }
                                        var trade:Trade
                                        if let lastTrade = stock.lastTrade(context), lastTrade.date == dt0 {
                                            trade = lastTrade
                                            NSLog("\(stock.sId)\(stock.sName)\t更新\(trade.dateTime)")
                                        } else {
                                            trade = Trade(context: context)
                                            if let s = Stock.fetch(context, sId:[stock.sId]).first {
                                                trade.stock = s
                                            }

                                        }
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
//                                            if let volume  = Double(line.components(separatedBy: ",")[7]) {
//                                            }
                                        trade.tSource = "cnyes"
                                        trade.objectWillChange.send()
                                    }
                                }   //if let close
                            }   //if let dt0
                        }   //for
                        if tradesCount > 0 {
                            try? context.save()
                            NSLog("\(stock.sId)\(stock.sName)\tcnyes \(ymdStart)~\(ymdEnd) 有效\(tradesCount)筆/全部\(lines.count)筆")
                            if twDateTime.stringFromDate(stock.dateFirst) == ymdStart && firstDate > stock.dateFirst {
                                stock.dateFirst = firstDate
                                stock.save()
                            }
                         } else {
                            NSLog("\(stock.sId)\(stock.sName)\tcnyes \(ymdStart)~\(ymdEnd) 全部\(lines.count)筆，但無有效交易？")
                        }
                    } else {  //if let findRange 有資料無交易故touch
                        NSLog("\(stock.sId)\(stock.sName)\tcnyes \(ymdStart)~\(ymdEnd) 解析無交易資料。")
                    }
                } else {  //if let downloadedData 下無資料故touch
                    NSLog("\(stock.sId)\(stock.sName)\tcnyes \(ymdStart)~\(ymdEnd) 下載無資料。")
                }
                self.tradesUpdated(time: Date())
            } else {  //if error == nil 下載有失誤也要touch
                NSLog("\(stock.sId)\(stock.sName)\tcnyes \(ymdStart)~\(ymdEnd) 下載有誤 \(String(describing: error))")
            }
            dGroup.leave()
        })
        task.resume()
    }


    func cnyesPrice(stock:Stock, dGroup:DispatchGroup) {
        if stock.trades.count == 0 {  //資料庫是空的
            let ymdS = twDateTime.stringFromDate(stock.dateFirst)
            let ymdE = twDateTime.stringFromDate()  //今天
            cnyesRequest(stock, ymdStart: ymdS, ymdEnd: ymdE, dGroup: dGroup)
        } else {
            if let firstTrade = stock.firstTrade(stock.context) {
                if stock.dateFirst < twDateTime.startOfDay(firstTrade.dateTime)  {    //起日在首日之前
                    let ymdS = twDateTime.stringFromDate(stock.dateFirst)
                    let ymdE = twDateTime.stringFromDate(firstTrade.dateTime)
                    cnyesRequest(stock, ymdStart: ymdS, ymdEnd: ymdE, dGroup: dGroup)
                }
            }
            if let lastTrade = stock.lastTrade(stock.context) {
                if lastTrade.dateTime < twDateTime.startOfDay()  {    //末日在今天之前
                    let ymdS = twDateTime.stringFromDate(lastTrade.dateTime)
                    let ymdE = twDateTime.stringFromDate(twDateTime.startOfDay())
                    cnyesRequest(stock, ymdStart: ymdS, ymdEnd: ymdE, dGroup: dGroup)
                }
            }
        }
    }
    
    func yahooRequest(_ stock:Stock) {
        let url = URL(string: "https://tw.stock.yahoo.com/q/q?s=" + stock.sId)
        let request = URLRequest(url: url!,timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
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
                                            var trade:Trade
                                            let dt0 = twDateTime.startOfDay(dt1)
                                            if let lastTrade = stock.lastTrade(context), lastTrade.date == dt0 {
                                                trade = lastTrade
//                                                NSLog("\(stock.sId)\(stock.sName)\tyahoo取代\(trade.dateTime)")
                                            } else {
                                                trade = Trade(context: context)
                                                if let s = Stock.fetch(context, sId:[stock.sId]).first {
                                                    trade.stock = s
                                                }
//                                                NSLog("\(stock.sId)\(stock.sName)\tyahoo新增\(trade.dateTime)")
                                            }
                                            trade.dateTime = dt1
                                            trade.priceClose = close
                                            trade.priceOpen = yNumber(yColumn[6])
                                            trade.priceHigh = yNumber(yColumn[7])
                                            trade.priceLow = yNumber(yColumn[8])
    //                                        let volume = yNumber(yColumn[5])
                                            trade.tSource = "yahoo"
                                            trade.objectWillChange.send()
                                            try? context.save()
                                            self.simTechnical(stock: stock, realtime: true)
                                            NSLog("\(stock.sId)\(stock.sName)\tyahoo " + twDateTime.stringFromDate(dt1, format: "HH:mm:ss") + String(format:" %.2f",close))
                                            
                                        }
                                    }
                                }   //if let dt0
                            }   //if let dt
                        }   //if yColumn.count >= 9
                    } else {  //取quoteTime: if let yDateRange
                        NSLog("\(stock.sId)\(stock.sName)\tyahoo：解析無交易資料。")
                    }
                }  else { //if let downloadedData =
                    NSLog("\(stock.sId)\(stock.sName)\tyahoo：下載無資料。")
                }   //if let downloadedData
                self.tradesUpdated(time: Date())
            } else {
                NSLog("\(stock.sId)\(stock.sName)\tyahoo：下載有誤 \(String(describing: error))")
            }   //if error == nil
        })  //let task =
        task.resume()
    }
    
    func matches(for leading: String, with trailing: String, in text: String) -> [String] {
        //依頭尾正規式切割欄位
        do {
            let regex = try NSRegularExpression(pattern: leading+"(.*)"+trailing)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            return results.map {nsString.substring(with: $0.range).replacingOccurrences(of: leading, with: "").replacingOccurrences(of: trailing, with: "")}
        } catch let error {
            NSLog("matches：正規式切割欄位失敗 \( error.localizedDescription)")
            return []
        }
    }

    func simTechnical(stock:Stock, realtime:Bool=false) {
        let context = coreData.shared.context
        let trades = Trade.fetch(context, stock: stock, asc:true)
        if trades.count > 0 {
            if realtime {
                tUpdate(trades, index: trades.count - 1)
            } else {
                for (index,trade) in trades.enumerated() {
                    if trade.tUpdated == false {
                        tUpdate(trades, index:index)
                    }
                }
            }
            try? context.save()
        }
    }
    
    func tUpdate(_ trades:[Trade], index:Int) {
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
            let d375 = tradeIndex(375, index: index)

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



        } else {
            trade.tKdK = 50
            trade.tKdD = 50
            trade.tKdJ = 50
            trade.tOscEma12 = demandIndex
            trade.tOscEma26 = demandIndex
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

}

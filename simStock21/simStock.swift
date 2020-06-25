//
//  simStock.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import Foundation
struct simStock {
        
    var stocks:[Stock] = coreData.shared.fetchStock().stocks
    var searchText:[String]? = nil {
        didSet {
            if let txt = searchText {
                stocks = coreData.shared.fetchStock(sId: txt, sName: txt).stocks
            }
        }
    }

    init() {
        if defaults.object(forKey: "timeDownloadedStocks") as? Date == nil {
            twseDailyMI()
        }
    }
    
    let defaults:UserDefaults = UserDefaults.standard

        
    mutating func newStock(stocks:[(sId:String,sName:String)], group:String?=nil) {
        let context = coreData.shared.getContext()
        for stock in stocks {
            let _ = coreData.shared.newStock(context, sId:stock.sId, sName:stock.sName, group: group)
        }
        coreData.shared.saveContext(context)
        self.stocks = coreData.shared.fetchStock().stocks
        NSLog("new stocks added: \(stocks)")
    }
    
    mutating func removeStockFromGroup (sId:String) {
        let updated = coreData.shared.updateStock(sId: sId, group: "")
        coreData.shared.saveContext(updated.context)
        self.stocks = coreData.shared.fetchStock().stocks
    }
    
    
//    var stocksJSON: Data? { try? JSONEncoder().encode(stocks) }
    
//    init?(stocksJSON: Data?) {
//        if let json = stocksJSON, let s = try? JSONDecoder().decode(Array<Stock>.self, from: json) {
//            stocks = s
//        } else {
//            stocks = []
//        }
//    }

    
    private func twseDailyMI() {
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
                    let theContext = coreData.shared.getContext()
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
//                            var sectionName:String
//                            if self.simPrices.keys.contains(id) {
//                                sectionName = (self.simPrices[id]!.paused ? coreData.shared.sectionWasPaused : coreData.shared.sectionInList)
//                            } else {
//                                sectionName = coreData.shared.sectionBySearch
//                            }
                            
                            let _ = coreData.shared.updateStock(theContext, sId:sId, sName: sName)
                            allStockCount += 1
//                            let progress:Float = Float(index+1) / Float(lines.count)
//                            OperationQueue.main.addOperation {
//                                self.uiProgress.setProgress(progress, animated: true)
//                            }

                        }   //if line != ""
                    } //for
                    coreData.shared.saveContext(theContext)    //self.saveContext()
                    let timeDownloadedStocks = Date()
                    self.defaults.set(timeDownloadedStocks, forKey: "timeDownloadedStocks")
                    NSLog("twseDailyMI(ALLBUT0999): \(twDateTime.stringFromDate(timeDownloadedStocks, format: "yyyy/MM/dd HH:mm:ss")) \(allStockCount)筆")
                }   //if let downloadedData
            } else {  //if error == nil
                NSLog("twsePrices error:\(String(describing: error))")
            }
        })
        task.resume()
    }
    
}


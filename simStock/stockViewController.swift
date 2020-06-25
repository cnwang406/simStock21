//
//  StockIdViewController.swift
//  simStock
//
//  Created by peiyu on 2016/6/26.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit
import CoreData


protocol stockViewDelegate:class {
    func addSearchedToList(_ cell:stockListCell)
}


class stockViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, NSFetchedResultsControllerDelegate, stockViewDelegate {


    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var uiProgress: UIProgressView!
    @IBOutlet weak var uiNavigationItem: UINavigationItem!
    @IBOutlet weak var uiBarAction: UIBarButtonItem!
    
    var searchString:String = ""
    var dateStockListDownloaded:Date = Date.distantPast
    var defaultId:String = {
        if let defaultId = UserDefaults.standard.string(forKey: "defaultId") {
            return defaultId
        } else {
            return "2330"
        }
    }()
    let waitForImportFromInternet:DispatchGroup = DispatchGroup()
    var isNotEditingList:Bool = true
    var importingFromInternet:Bool = false
    var simPrices:[String:simPrice] = [:]
    var stockIdCopy:String = ""
    var addedStock:String = ""
    var foundStock:String = ""
    var masterUI:masterUIDelegate?

    var stockListVersion:String = ""
    var version:String = ""
    var isPad:Bool = false
    var isLandScape = UIDevice.current.orientation.isLandscape
    let defaults:UserDefaults = UserDefaults.standard

    @IBAction func uiBarExport(_ sender: UIBarButtonItem) {
            let textMessage = "選擇範圍和內容？"
            let alert = UIAlertController(title: "匯出股群CSV文字", message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "代號和名稱", style: .default, handler: { action in
                self.exportAllId("ID")
            }))
            alert.addAction(UIAlertAction(title: "股群彙總", style: .default, handler: { action in
                self.exportAllId("SUMMARY")
            }))
            alert.addAction(UIAlertAction(title: "逐月已實現損益", style: .default, handler: { action in
                self.exportAllId("ROI")
            }))
            self.present(alert, animated: true, completion: nil)

    }
    
    func exportAllId (_ contents:String) {
        var exportString:String = ""
        switch contents {
        case "SUMMARY":
            if let s = self.masterUI?.getStock() {
                exportString = s.csvSummary()
            }
        case "ROI":
            if let s = self.masterUI?.getStock() {
                exportString = s.csvMonthlyRoi()
            }
        default:    //匯出ID和名稱
            if let stocks = self.masterUI?.getStock().sortedStocks {
                for s in stocks {
                    if s.id != "t00" {
                        if exportString == "" {
                            exportString += s.id + " " + s.name
                        } else {
                            exportString += ", " + s.id + " " + s.name
                        }
                    }
                }
            }
        }
        if exportString.count > 0 {
            let activityViewController : UIActivityViewController = UIActivityViewController(activityItems: [exportString], applicationActivities: nil)
            activityViewController.excludedActivityTypes = [    //標為註解以排除可用的，留下不要的
                .addToReadingList,
                .airDrop,
                .assignToContact,
//                .copyToPasteboard,
//                .mail,
//                .markupAsPDF,   //iOS11之後才有
//                .message,
                .openInIBooks,
                .postToFacebook,
                .postToFlickr,
                .postToTencentWeibo,
                .postToTwitter,
                .postToVimeo,
                .postToWeibo,
                .print,
                .saveToCameraRoll]
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = self.view.bounds
                popover.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
            }
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    // *********************************
    // ***** ===== Core Data ===== *****
    // *********************************

    var _fetchedResultsController:NSFetchedResultsController<NSFetchRequestResult>?

    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        let searchKey:[String] = searchString.components(separatedBy: " ")
        let fetchRequest = coreData.shared.fetchRequestStock(id:searchKey,name:searchKey) as! NSFetchRequest<NSFetchRequestResult>
        _fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchRequest, managedObjectContext: coreData.shared.mainContext, sectionNameKeyPath: "list", cacheName: nil)
        _fetchedResultsController!.delegate = self
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            self.masterUI?.nsLog("stockView fetch error\n\(error)\n")
        }
        return _fetchedResultsController!

    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch(type) {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            break
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch (type) {
        case .update:
            if let indexPath = indexPath {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .move:
            if let indexPath = indexPath {
                if let newIndexPath = newIndexPath {
                        tableView.deleteRows(at: [indexPath], with: .fade)
                        tableView.insertRows(at: [newIndexPath], with: .fade)
                }
            }
        @unknown default:
//            <#fatalError()#>
            break
        }
    }
    







    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(stockViewController.reloadAllStock), for: UIControl.Event.valueChanged)

        return refreshControl
    }()

    @objc func reloadAllStock() {
        self.refreshControl.endRefreshing()
        self.importFromInternet()
    }


















    override func viewDidLoad() {
        super.viewDidLoad()
        self.masterUI?.nsLog("=== stockList viewDidLoad ===")
        if (traitCollection.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
            isPad = true
        }
//        if UIDevice.current.orientation.isLandscape {
//            isLandScape = true
//        } else {
//            isLandScape = false
//        }
        if let sims = masterUI?.getStock().simPrices {
            simPrices = sims
        }

        self.clearNoDataElement ()
        self.uiProgress.setProgress(0, animated: false)
        self.tableView.addSubview(self.refreshControl)


        if let dt = defaults.object(forKey: "dateStockListDownloaded"){
            self.dateStockListDownloaded = (dt as! Date)
            self.masterUI?.nsLog("twseDailyMI:\(twDateTime.stringFromDate(dateStockListDownloaded, format: "yyyy/MM/dd HH:mm:ss"))")

            let bySearch1 = coreData.shared.fetchStock(list:[coreData.shared.sectionBySearch], fetchLimit: 1)
            if bySearch1.Stocks.count == 0 {
                importFromInternet()
            } else {
                if let f = fetchedResultsController.fetchedObjects {
                    if simPrices.count != f.count {
                        self.masterUI?.nsLog("fetchedObjects(\(f.count)) != simPrices(\(simPrices.count))")
                        self.importFromDictionary()
                    }
                }
            }
        } else {
            importFromInternet()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if UIDevice.current.orientation.isLandscape {
            isLandScape = true
        } else {
            isLandScape = false
        }
        self.tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if UIDevice.current.orientation.isLandscape {
            isLandScape = true
        } else {
            isLandScape = false
        }
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.masterUI?.nsLog("== stockList viewWillDisappear ==\n")

        clearNoDataElement()

    }




    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.masterUI?.nsLog(">>>>> stockList didReceiveMemoryWarning <<<<<\n")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.masterUI?.nsLog("=== stockList viewWillAppear ===")
        reloadTable ()
    }


    
    


    func importFromInternet () {
        lockUI()
        OperationQueue().addOperation {
            coreData.shared.deleteStock(list:["ALL"])
            self.importFromDictionary()
            self.twseDailyMI()
        }
    }
    
    func importFromDictionary (_ context:NSManagedObjectContext?=nil) {
        //從stockNames新增
        if let simStock = masterUI?.getStock() {
            let theContext = coreData.shared.getContext(context)
            let _ = coreData.shared.updateStock(theContext, id:"t00", name: "*加權指", list: coreData.shared.sectionBySearch)
            let sortedStocks = simStock.sortStocks(includePaused: true)
            for s in sortedStocks {
                if self.simPrices[s.id]!.paused {
                    let _ = coreData.shared.updateStock(theContext, id:s.id, name: s.name, list: coreData.shared.sectionWasPaused)
                } else {
                    let updated = coreData.shared.updateStock(theContext, id:s.id, name: s.name, list: coreData.shared.sectionInList)
                    print("importFromDictionary \(updated.stock.name):\(updated.stock.list)")
                }
            }
            coreData.shared.saveContext(theContext) 

        }
    }

    func lockUI() {
        addedStock = ""
        foundStock = ""
        searchString = ""
        uiSearchBar.text = ""
        uiSearchBar.isUserInteractionEnabled = false
        importingFromInternet = true
        uiNavigationItem.hidesBackButton = true
        UIApplication.shared.isIdleTimerDisabled = true  //更新資料時，防止睡著
    }

    func unlockUI() {
        OperationQueue.main.addOperation {
            self.uiProgress.setProgress(1, animated: true)
            self.uiProgress.setProgress(0, animated: false)
            self.reloadTable()
            UIApplication.shared.isIdleTimerDisabled = false  //更新資料完畢允許睡眠
            self.importingFromInternet = false
            self.tableView.isUserInteractionEnabled = true
            self.uiSearchBar.isUserInteractionEnabled = true
            self.uiNavigationItem.hidesBackButton = false
        }
    }


    var allStockCount:Int = 0
    func twseDailyMI(_ context:NSManagedObjectContext?=nil) {
        //        let y = calendar.component(.Year, fromDate: qDate) - 1911
        //        let m = calendar.component(.Month, fromDate: qDate)
        //        let d = calendar.component(.Day, fromDate: qDate)
        //        let YYYMMDD = String(format: "%3d/%02d/%02d", y,m,d)
        //================================================================================
        allStockCount = 0
        //從當日收盤行情取股票代號名稱

        self.waitForImportFromInternet.enter()

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
                    let theContext = coreData.shared.getContext(context)
                    for (index, lineText) in lines.enumerated() {
                        var line:String = lineText
                        if lineText.first == "=" {
                            stockListBegins = true
                        }
                        if lineText != "" && lineText.contains(",") && lineText.contains(".") && index > 2 && stockListBegins {
                            if lineText.first == "=" {
                                line = lineText.replacingOccurrences(of: "=", with: "")   //去首列等號
                            }

                            let id = line.components(separatedBy: ",")[0]
                            let name = line.components(separatedBy: ",")[1]
                            var sectionName:String
                            if self.simPrices.keys.contains(id) {
                                sectionName = (self.simPrices[id]!.paused ? coreData.shared.sectionWasPaused : coreData.shared.sectionInList)
                            } else {
                                sectionName = coreData.shared.sectionBySearch
                            }
                            
                            let _ = coreData.shared.updateStock(theContext, id:id, name: name, list: sectionName)
                            self.allStockCount += 1
                            let progress:Float = Float(index+1) / Float(lines.count)
                            OperationQueue.main.addOperation {
                                self.uiProgress.setProgress(progress, animated: true)
                            }

                        }   //if line != ""
                    } //for
                    coreData.shared.saveContext(theContext)    //self.saveContext()
                    self.dateStockListDownloaded = Date()
                    self.defaults.set(self.dateStockListDownloaded, forKey: "dateStockListDownloaded")
                    self.masterUI?.nsLog("twseDailyMI(ALLBUT0999): \(twDateTime.stringFromDate(self.dateStockListDownloaded, format: "yyyy/MM/dd HH:mm:ss")) \(self.allStockCount)筆")
                }   //if let downloadedData
            } else {  //if error == nil
                self.masterUI?.nsLog("twsePrices error:\(String(describing: error))")
            }
            self.unlockUI()
            self.waitForImportFromInternet.leave()
        })
        task.resume()
    }


    







    // MARK: - Table view data source
    //=========================================================================

    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects

    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let stock   = fetchedResultsController.object(at: indexPath) as! Stock
        let cell    = tableView.dequeueReusableCell(withIdentifier: "cellStockList", for: indexPath) as! stockListCell 
        cell.stockView = self

        //股票代號和名稱是iPhone,iPad,paused等股群和搜尋結果都需要
        cell.uiId.text    = stock.id
        cell.uiName.text  = stock.name
        //其他欄位先清空隱藏，後面需要再顯示
        cell.uiCellPriceClose.text  = ""
        cell.uiCellPriceUpward.text = ""
        cell.uiCellAction.text      = ""
        cell.uiCellQty.text         = ""
        cell.uiDays.text            = ""
        cell.uiYears.text           = ""
        cell.uiMissed.text          = ""
        cell.uiMultiple.text        = ""
        cell.uiROI.text             = ""
        
        cell.uiCellPriceClose.isHidden  = true
        cell.uiCellPriceUpward.isHidden = true
        cell.uiCellAction.isHidden      = true
        cell.uiCellQty.isHidden         = true
        cell.uiDays.isHidden            = true
        cell.uiYears.isHidden           = true
        cell.uiMissed.isHidden          = true
        cell.uiMultiple.isHidden        = true
        cell.uiROI.isHidden             = true
        
        cell.uiCellPriceClose.gestureRecognizers = nil
        cell.uiCellPriceUpward.gestureRecognizers = nil
        cell.uiCellAction.gestureRecognizers = nil
        cell.uiCellQty.gestureRecognizers = nil
        cell.uiDays.gestureRecognizers = nil
        cell.uiYears.gestureRecognizers = nil
        cell.uiMissed.gestureRecognizers = nil
        cell.uiMultiple.gestureRecognizers = nil
        cell.uiROI.gestureRecognizers = nil



        if stock.list == coreData.shared.sectionBySearch {
            cell.uiButtonWidth.constant = 44
            cell.uiId.textColor = UIColor(red:128/255, green:120/255, blue:0, alpha:1)
            cell.uiName.textColor = UIColor(red:128/255, green:120/255, blue:0, alpha:1)
            if stock.name == coreData.shared.NoData || importingFromInternet {
                cell.uiButtonAdd.isHidden = true
            } else {
                cell.uiButtonAdd.isHidden = false
            }
        } else {
            cell.uiButtonWidth.constant = 8
            cell.uiButtonAdd.isHidden = true
            
            if let simPrice = simPrices[stock.id] {
                let roiTuple = simPrice.ROI()
                //年間是iPhone,iPad,paused都需要
                cell.uiYears.isHidden = false
                cell.uiYears.text = String(format:"%.1f年",roiTuple.years)
                cell.uiYears.textColor = UIColor.darkGray
                if !simPrice.paused {
                    let tapRecognizer6:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                    tapRecognizer6.message = String(format:"模擬期間%.1f年",roiTuple.years)
                    cell.uiYears.gestureRecognizers = [tapRecognizer6]           //tag=6
                }

                if !simPrice.paused { //iPhone股群，iPad股群也有
                    //股群的代號名稱會根據Rank的顏色標示
                    if simPrice.paused {
                        cell.uiId.textColor = UIColor.lightGray
                    } else {
                        let endRank = (simPrice.getPriceEnd("ma60Rank") as? String ?? "")
                        switch endRank {
                        case "A":
                            cell.uiId.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
                        case "B":
                            cell.uiId.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                        case "C+":
                            cell.uiId.textColor = UIColor(red: 96/255, green:0, blue:0, alpha:1)
                        case "C":
                            cell.uiId.textColor = UIColor.darkGray
                        case "C-":
                            cell.uiId.textColor = UIColor(red: 0, green:64/255, blue:0, alpha:1)
                        case "D":
                            cell.uiId.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
                        case "E":
                            cell.uiId.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
                        default:
                            cell.uiId.textColor = UIColor.darkGray
                        }
                    }
                    cell.uiName.textColor = cell.uiId.textColor

                    //週期天、缺天數、本金倍、ROI
                    cell.uiDays.isHidden        = false
                    cell.uiMissed.isHidden      = false
                    cell.uiMultiple.isHidden    = false
                    cell.uiROI.isHidden         = false

                    let tapRecognizer5:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                    var cutCount:String = ""
                    let cumulCut = (simPrice.getPriceEnd("cumulCut") as? Float ?? 0)
                    if cumulCut > 0 {
                        cutCount = String(format:"(%.f)",cumulCut)
                        tapRecognizer5.message = String(format:"\n曾停損%.f次",cumulCut)
                        tapRecognizer5.height  = 60
                    }
                    let endSimDays = (simPrice.getPriceEnd("simDays") as? Float ?? 0)
                    if roiTuple.days > 0 {
                        if endSimDays > 0 && (isPad || isLandScape) {
                            cell.uiDays.text = String(format:"%.f/%.f天",endSimDays,roiTuple.days) + cutCount
                            tapRecognizer5.message = String(format:"本輪持股第%.f天\n平均週期%.f天",endSimDays,roiTuple.days) + tapRecognizer5.message
                            tapRecognizer5.delay = 3
                        } else {
                            cell.uiDays.text = String(format:"%.f天",roiTuple.days) + cutCount
                            tapRecognizer5.message = String(format:"平均持股週期%.f天",roiTuple.days)  + tapRecognizer5.message
                            tapRecognizer5.height  = 44
                        }
                        cell.uiDays.gestureRecognizers = [tapRecognizer5]           //tag=5
                    }

                    if roiTuple.days > 200 {
                        cell.uiDays.textColor = UIColor(red:0, green:116/255, blue:0, alpha:1)
                    } else if roiTuple.days > 150 {
                        cell.uiDays.textColor = UIColor(red:0, green:96/255, blue:0, alpha:1)
                    } else if roiTuple.days > 75 {
                        cell.uiDays.textColor = UIColor(red:0, green:64/255, blue:0, alpha:1)
                    } else if roiTuple.days > 50 {
                        cell.uiDays.textColor = UIColor.darkGray
                    } else {
                        cell.uiDays.textColor = UIColor(red:192/255, green:0, blue:0, alpha:1)
                    }
                    
                    if simPrice.missed.count > 0 {
                        cell.uiMissed.text = String(format:"缺(%d)",simPrice.missed.count)
                        cell.uiMissed.textColor = UIColor.darkGray
                        let tapRecognizer7:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                        tapRecognizer7.message = String(format:"有%d天缺漏\n或暫停交易",simPrice.missed.count)
                        cell.uiMissed.gestureRecognizers = [tapRecognizer7]           //tag=7
                    }
                    
                    let maxMultiple = simPrice.maxMoneyMultiple
                    let endMultiple = (simPrice.getPriceEnd("moneyMultiple") as? Double ?? 0)
                    let endQtyInventory = (simPrice.getPriceEnd("qtyInventory") as? Double ?? 0)
                    let endMs:String = (endQtyInventory > 0 && (isPad || isLandScape) ? String(format:"x%.f",endMultiple) : "")
                    let maxMs:String  = (roiTuple.days > 0 && maxMultiple > 0 ? String(format:(endMs == "" ? "x" : "") + "%.f",maxMultiple) : "")
                    let msSep:String = (endMs == "" || maxMs == "" ? "" : "/")
                    if (endMs != "" || maxMs != "")  {
                        cell.uiMultiple.textColor = UIColor.darkGray
                        cell.uiMultiple.text = endMs + msSep + maxMs
                        let tapRecognizer8:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                        tapRecognizer8.message = (endMs.count > 0 ? String(format:"本輪使用%.f倍本金",endMultiple) : "") + (msSep == "/" ? "\n" : "") + (maxMs.count > 0 ? String(format:(endMs.count > 0 ? "模擬期間" : "") + "最高%.f倍" + (endMs.count > 0 ? "" : "本金"),maxMultiple) : "")
                        tapRecognizer8.delay = (endMs.count > 0 ? 3 : 2)
                        cell.uiMultiple.gestureRecognizers = [tapRecognizer8]           //tag=8
                    } else {
                        cell.uiMultiple.text = ""
                        cell.uiMultiple.gestureRecognizers = nil
                    }
                    if roiTuple.days > 0 {
                        let tapRecognizer9:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                        let cumuROI = round(10 * roiTuple.roi) / 10
                        let endQtySell = (simPrice.getPriceEnd("qtySell") as? Double ?? 0)
                        if endQtyInventory ==  0 || (!isPad && !isLandScape) {
                            cell.uiROI.text = String(format:"%.1f%%",cumuROI)
                            tapRecognizer9.message = String(format:"平均年報酬率%.1f%%\n",cumuROI)
                        } else if endQtySell > 0 && (isPad || isLandScape) {
                            let simROI  = round(10 * (simPrice.getPriceEnd("simROI") as? Double ?? 0)) / 10
                            cell.uiROI.text = String(format:"%.1f/%.1f%%",simROI,cumuROI)
                            tapRecognizer9.message = String(format:"本輪已實現%.1f%%\n平均年報酬率%.1f%%",simROI,cumuROI)
                        } else if endQtyInventory > 0 && (isPad || isLandScape) {
                            let simROI  = round(10 * (simPrice.getPriceEnd("simUnitDiff") as? Double ?? 0)) / 10
                            cell.uiROI.text = String(format:"%.1f/%.1f%%",simROI,cumuROI)
                            tapRecognizer9.message = String(format:"本輪未實現%.1f%%\n平均年報酬率%.1f%%",simROI,cumuROI)
                            tapRecognizer9.delay = 3
                        }
                        tapRecognizer9.width = 165
                        if simPrice.simReversed {
                            cell.uiROI.textColor = self.view.tintColor
                            tapRecognizer9.message += "\n有反轉買賣行動"
                            tapRecognizer9.height   = 60
                        } else if cumuROI < -10 {
                            cell.uiROI.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
                        } else if cumuROI < 0 {
                            cell.uiROI.textColor = UIColor(red: 0, green:72/255, blue:0, alpha:1)
                        } else if cumuROI > 20 {
                            cell.uiROI.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
                        } else if cumuROI > 10 {
                            cell.uiROI.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                        } else {
                            cell.uiROI.textColor = UIColor.darkGray
                        }
                        cell.uiROI.gestureRecognizers = [tapRecognizer9]           //tag=9
                    }


                    
                }
                if (isPad || isLandScape) && !simPrice.paused { //iPad股群獨有而且不是paused的
                    //價、升、買賣、量
                    cell.uiCellPriceClose.isHidden  = false
                    cell.uiCellPriceUpward.isHidden = false
                    cell.uiCellAction.isHidden      = false
                    cell.uiCellQty.isHidden         = false

                    let dateTime:Date = (simPrice.getPriceEnd("dateTime") as? Date ?? Date.distantPast)
                    let endPriceClose = (simPrice.getPriceEnd("priceClose") as? Double ?? 0)
                    let endSimRule    = (simPrice.getPriceEnd("simRule") as? String ?? "")
                    if let p10 = self.masterUI?.masterSelf().price10Message(id: stock.id, dateTime: dateTime) {
                        let tapRecognizerClose:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                        tapRecognizerClose.message = p10.message
                        tapRecognizerClose.width   = p10.width
                        tapRecognizerClose.height  = p10.height
                        tapRecognizerClose.delay   = p10.delay
                        cell.uiCellPriceClose.gestureRecognizers = [tapRecognizerClose]
                        cell.uiCellPriceClose.text = String(format:"[%.2f]",endPriceClose)
                    } else {
                        cell.uiCellPriceClose.text = String(format:"%.2f ",endPriceClose)   //(twDateTime.marketingTime(dateTime) ? "・" : "") +
                    }
                    cell.uiCellPriceClose.textColor = self.masterUI?.simRuleColor(endSimRule) //與主畫面的收盤價同顏色

                    let tapRecognizer2:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                    let endPriceUpward = (simPrice.getPriceEnd("priceUpward") as? String ?? "")
                    cell.uiCellPriceUpward.text = endPriceUpward
                    switch endPriceUpward {
                    case "▲":
                        tapRecognizer2.message = "9天內最高價"
                        cell.uiCellPriceUpward.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
                    case "▵","up":
                        tapRecognizer2.message = "較前日上漲"
                        cell.uiCellPriceUpward.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                    case "▿","down":
                        tapRecognizer2.message = "較前日下跌"
                        cell.uiCellPriceUpward.textColor = UIColor(red: 0, green:72/255, blue:0, alpha:1)
                    case "▼":
                        tapRecognizer2.message = "9天內最低價"
                        cell.uiCellPriceUpward.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
                    default:
                        cell.uiCellPriceUpward.textColor = UIColor.darkGray
                    }
                    if endPriceUpward != "" {
                        tapRecognizer2.width = 120
                        cell.uiCellPriceUpward.gestureRecognizers = [tapRecognizer2] //tag=2
                    }

                    let tapRecognizer4:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
                    let endQtyBuy       = (simPrice.getPriceEnd("qtyBuy") as? Double ?? 0)
                    let endQtySell      = (simPrice.getPriceEnd("qtySell") as? Double ?? 0)
                    let endQtyInventory = (simPrice.getPriceEnd("qtyInventory") as? Double ?? 0)
                    if endQtyBuy > 0 {
                        cell.uiCellAction.text = "買"
                        cell.uiCellAction.textColor = UIColor.red
                        cell.uiCellQty.text = String(format:"%.f",endQtyBuy)
                        cell.uiCellQty.textColor = UIColor.red
                        tapRecognizer4.message = String(format:"買入%.f張",endQtyBuy)
                    } else if endQtySell > 0 {
                        cell.uiCellAction.text = "賣"
                        cell.uiCellAction.textColor = UIColor.blue
                        cell.uiCellQty.text = String(format:"%.f",endQtySell)
                        cell.uiCellQty.textColor = UIColor.blue
                        tapRecognizer4.message = String(format:"賣出%.f張",endQtySell)
                    } else if endQtyInventory > 0 {
                        cell.uiCellAction.text = "餘"
                        cell.uiCellAction.textColor = UIColor.brown
                        cell.uiCellQty.text = String(format:"%.f",endQtyInventory)
                        cell.uiCellQty.textColor = UIColor.brown
                        tapRecognizer4.message = String(format:"庫存%.f張",endQtyInventory)
                    }
                    tapRecognizer4.width = 120
                    cell.uiCellQty.gestureRecognizers = [tapRecognizer4] //tag=4
                    
                } else if simPrice.paused { //暫停模擬
                    //年間
                    cell.uiYears.isHidden = false

                    cell.uiId.textColor = UIColor.lightGray
                    cell.uiName.textColor = UIColor.lightGray
                    cell.uiYears.text = String(format:"%.1f年",roiTuple.years)
                    cell.uiYears.textColor = UIColor.lightGray
                }

            } else {    //剛新增還沒數值的股票 if let simPrice = simPrices[stock.id]
                cell.uiId.textColor = UIColor.brown
                cell.uiName.textColor = UIColor.brown
            }   //if let simPrice = simPrices[stock.id]
        
        }   //if stock.list == coreData.shared.sectionBySearch
        
        return cell
    }
    
    @objc func TapPopover(sender:TapGesture) {
        if let sView = sender.view {
            if let pc = self.storyboard?.instantiateViewController(withIdentifier: "popoverMessage") as? popoverMessage {
                pc.modalPresentationStyle = .popover
                if let popover = pc.popoverPresentationController {
                    popover.delegate = pc.self
                    popover.sourceView = sView
                    popover.permittedArrowDirections = [.up, .down]
                    pc.delay = sender.delay
                    present(pc, animated: true, completion: nil)
                    pc.uiPopoverText.text = sender.message
                    pc.preferredContentSize = CGSize(width: sender.width, height: sender.height)
                }
            }
        }
    }


    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let sections = fetchedResultsController.sections {
            var text:String = ""
            let currentSection = sections[section]
            
            if self.importingFromInternet {
                text = "正在下載股票名單，請稍候。\n"
            } else {
                if addedStock != "" {
                    text = "已新增 " + addedStock + " 到股群清單。\n\n"
                }
                if foundStock != "" {
                    text = foundStock + " 已經在股群內。\n\n"
                }
                switch currentSection.name {
                case coreData.shared.sectionBySearch:
                    text = text + currentSection.name + "：已在股群內或是上櫃者不會列出。"
                case coreData.shared.sectionInList:
                    text = text + currentSection.name + "：從搜尋結果加入，或手勢左滑刪除。"
                case coreData.shared.sectionWasPaused:
                    text = text + currentSection.name + "：手勢左滑以重啟模擬或刪除。"
                default:
                    text = currentSection.name
                }
            }
            return text
        }
        return ""
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let sections = fetchedResultsController.sections {
            if sections[section].name == coreData.shared.sectionInList && sections[section].numberOfObjects > 1 {
                let isPaused:Bool = sections[section].name == coreData.shared.sectionWasPaused
                if let rois = masterUI?.getStock().roiSummary(forPaused: isPaused) {
                    if isPad || isLandScape {
                        return rois.s1 + rois.s2    //s1是全部股群的報酬率，s2是目前持股的本金
                    } else {
                        return rois.s1
                    }
                }
            }
        }
        return nil
    }


    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        let title = UILabel()
        if self.isPad {
            title.font = UIFont.systemFont(ofSize: 16.0)
        } else {
            title.font = UIFont.systemFont(ofSize: 14.0)
        }

        if self.importingFromInternet {
            title.textColor = UIColor.orange
        } else if let sections = fetchedResultsController.sections {
            if sections[section].name == coreData.shared.sectionBySearch {
                title.textColor = UIColor.brown
            } else {
                title.textColor = UIColor.darkGray
            }
        }

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font=title.font
        header.textLabel?.textColor=title.textColor
    }

    //新增代號
    func addSearchedToList(_ cell:stockListCell) {
        let maxStocks:Int = 1000
        if let simStock = masterUI?.getStock() {
            if simPrices.count < maxStocks {
                if isNotEditingList {
                    isNotEditingList = false
                    if let indexPath = tableView.indexPath(for: cell) {
                        let stock = fetchedResultsController.object(at: indexPath) as! Stock
                        stock.list = coreData.shared.sectionInList
                        self.addedStock = stock.id + " " + stock.name    //顯示於section header
                        self.simPrices = simStock.addNewStock(id:stock.id,name:stock.name) //重刷tableView前必須備妥新代號
                        coreData.shared.saveContext()
                        self.reloadTable()  //才能於section header顯示訊息
                        self.isNotEditingList = true
                    }
                }
            } else {
                let textMessage = "最多\n只能保存\(maxStocks)支股票。"
                let alert = UIAlertController(title: "Warning", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "知道了", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)

            }
        }


    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions:[UITableViewRowAction] = []
        let stock = self.fetchedResultsController.object(at: indexPath) as! Stock
        let id = stock.id
        if let simPrice = self.simPrices[id] {
            if let simStock = self.masterUI?.getStock() {
                if simStock.sortedStocks.count > 1 || simPrice.paused {
                    let pause = UITableViewRowAction(style: .default, title: (simPrice.paused ? "重啟模擬" : "暫停模擬")) { action, index in
                        self.clearNoDataElement()
                        self.isNotEditingList = false
                        self.stockIdCopy = ""
                        OperationQueue.main.addOperation {
                            self.simPrices = simStock.pausePriceSwitch(id)
                            if self.simPrices[id]!.paused { //改名使簡稱排序在前 --> 還有其他地方要改
                                stock.list = coreData.shared.sectionWasPaused
                            } else {
                                stock.list = coreData.shared.sectionInList
                            }
                            coreData.shared.saveContext()
                            self.reloadTable()
                            self.isNotEditingList = true
                        }
                    }
                    actions.append(pause)
                }
            }
        }
        let delete = UITableViewRowAction(style: (actions.count > 0 ? .normal : .default), title: "刪除") { action, index in
            self.clearNoDataElement()
            self.isNotEditingList = false
            self.stockIdCopy = ""
            OperationQueue.main.addOperation {
                stock.list = coreData.shared.sectionBySearch
                coreData.shared.saveContext()
                if let simStock = self.masterUI?.getStock() {
                    self.simPrices = simStock.removeStock(id)
                    if self.simPrices.count == 1 {
                        self.importFromDictionary()  //把預設的台積電加回來
                        self.reloadTable()
                    }
                }
                self.isNotEditingList = true
            }
        }
        actions.append(delete)
        
 
        return actions
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if self.importingFromInternet {
            return false
        }
        let stock = fetchedResultsController.object(at: indexPath) as! Stock
        if stock.list != coreData.shared.sectionBySearch && isNotEditingList && (self.simPrices.count > 1 || stock.id != defaultId) {
            return true
        } else {
            return false
        }
    }

    //刪除代號
//    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//        self.clearNoDataElement()
//        if (editingStyle == UITableViewCell.EditingStyle.delete) {
//            isNotEditingList = false
//            self.stockIdCopy = ""
//            let stock = self.fetchedResultsController.object(at: indexPath) as! Stock
//            let id = stock.id
//            OperationQueue.main.addOperation {
//                stock.list = self.sectionBySearch
//                self.saveContext()
//                if let sims = self.masterUI?.getStock().removeStock(id) {  //等tableView重刷完畢才能移除
//                    self.simPrices = sims
//                }
//                if self.simPrices.count == 1 {
//                    self.importFromDictionary()  //把預設的台積電加回來
//                    self.reloadTable()
//                }
//                self.isNotEditingList = true
//            }
//
//
//        }
//    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        view.endEditing(true)
        let stock = fetchedResultsController.object(at: indexPath) as! Stock
        if stock.list == coreData.shared.sectionInList {
            //選到的股在回主畫面時切換到該股
            if let prevId = masterUI?.getStock().setSimId(newId:stock.id) {
                if stockIdCopy == "" {
                    stockIdCopy = prevId
                }
            }
        } else {
            //選到搜尋股則取消選取
            if stock.list == coreData.shared.sectionBySearch {  //但暫停股不要取消選取才看得出來是哪一筆
                tableView.deselectRow(at: indexPath, animated: true)
            }
            if stockIdCopy != "" {  //避免回主畫面時此選定Id無效以stockIdCopy還原前選定股
                let _ = masterUI?.getStock().setSimId(newId:stockIdCopy)
                stockIdCopy = ""
            }
        }
    }













    func reloadTable() {
        _fetchedResultsController = nil
        if let _ = self.fetchedResultsController.fetchedObjects {   ////這會觸動performFetch
            self.tableView.reloadData()
        }
    }




    //========== Search Bar Delegate ==========
    @IBOutlet weak var uiSearchBar: UISearchBar!

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.clearNoDataElement()

    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if importingFromInternet {
            return
        }
        if searchOrDownload () == true {
            self.importFromInternet()   //去下載完整的名單，然後再查詢一次
            self.waitForImportFromInternet.notify(queue: DispatchQueue.main, execute: {
                _ = self.searchOrDownload ()
            })
        }


    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if importingFromInternet {
            return
        }
        self.searchString = searchText.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ")
        if searchText == "" {
            self.clearNoDataElement()
        }

    }

    func searchOrDownload () -> Bool {  //true if need download
        addedStock = ""
        foundStock = ""
        self.reloadTable()  //有關鍵字了，重查詢table
        var scrollToIndex:IndexPath = IndexPath(row: 0, section: 0) //捲到頂
        var noSearched:Bool = true
        if let sections = fetchedResultsController.sections {
            for s in sections {
                if s.name == coreData.shared.sectionBySearch {
                    noSearched = false
                    break
                }
            }
        }
        if noSearched || dateStockListDownloaded.compare(Date.distantPast) == ComparisonResult.orderedSame {   //只有已建檔代號，沒有搜尋來的代號，或還沒下載股票代號名稱 --> 可能沒找到或是還沒下載
            let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
            if calendar.isDateInToday(dateStockListDownloaded) {
                //已經下載過 --> 確定沒有搜尋結果，且今天剛下載不用更新，那結論就是找不到了
                let stocks:[Stock] = fetchedResultsController.fetchedObjects as! [Stock]
                for stock in stocks {
                    if stock.id == searchString || stock.name == searchString {
                        foundStock = stock.id + " " + stock.name    //稍後顯示於section header
                        uiSearchBar.text = ""
                        searchString = ""
                        tableView.reloadData()  //只是為了清搜尋列和重排tableview的相對位置
                        //已經在股群內就捲到那一列
                        if let indexPath = fetchedResultsController.indexPath(forObject: stock) {
                            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableView.ScrollPosition.middle)
                            scrollToIndex = indexPath
                            tableView(tableView, didSelectRowAt: indexPath)    //還要在回主畫面時切換到該股
                        }
                        break
                    }
                }
                if foundStock == "" {   //新增"沒有符合的股票。"
//                    _ = self.updateStockList("",name: self.NoData,list: self.sectionBySearch, isNew:true)
//                    self.saveContext()
                    let updated = coreData.shared.updateStock(id:"", name: coreData.shared.NoData, list: coreData.shared.sectionBySearch)
                    coreData.shared.saveContext(updated.context)
                }
            } else {
                return true     //還沒下載過 --> 等下要去下載，然後再來 searchOrDownload ()
            }
        }
        //有搜尋到，而且只有1筆，就自動加入股群
        if let sections = fetchedResultsController.sections {
            if sections[0].name == coreData.shared.sectionBySearch && sections[0].numberOfObjects == 1 {
                if let stock = sections[0].objects?.first as? Stock {
                    if stock.name != coreData.shared.NoData {
                        uiSearchBar.text = ""
                        searchString = ""
                        addedStock = stock.id + " " + stock.name    //顯示於section header
                        stock.list = coreData.shared.sectionInList
                        coreData.shared.saveContext()
                        if let sims = masterUI?.getStock().addNewStock(id:stock.id,name:stock.name) {
                            self.simPrices = sims
                        }
                        self.tableView.scrollToRow(at: scrollToIndex, at: .middle, animated: true)
                        return false    //就不要endEditing
                    }
                }
            }
        }
        self.view.endEditing(true)
        self.tableView.scrollToRow(at: scrollToIndex, at: .middle, animated: true)
        return false    //有東西，不用下載

    }



    func clearNoDataElement () {
        if importingFromInternet {
            return
        }
        addedStock = ""
        foundStock = ""
        searchString = ""
        self.uiSearchBar.text = ""
        OperationQueue().addOperation{
            coreData.shared.deleteStock(name: [coreData.shared.NoData])   //self.fetchNoDataElement()
            OperationQueue.main.addOperation() {
                self.reloadTable()
            }
        }
    }



}

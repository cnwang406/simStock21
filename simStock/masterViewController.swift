//
//  ViewController.swift
//  simStock
//
//  Created by peiyu on 2016/3/27.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit
import Intents
import CoreData
import CoreSpotlight
import ZipArchive   //v2.13
import AVFoundation
import MobileCoreServices


protocol masterUIDelegate:class {
    func masterSelf() -> masterViewController
    func isExtVersion() -> Bool
    func serialQueue() -> OperationQueue
    func systemSound(_ soundId:SystemSoundID)
    func getStock() -> simStock
    func nsLog(_ logText:String)
    
    func lockUI(_ message:String, solo:Bool)
    func unlockUI(_ message:String)
    func setIdleTimer(timeInterval:TimeInterval)
    func messageWithTimer(_ text:String,seconds:Int)
    func simRuleColor(_ simRule:String) -> UIColor
    func setProgress(_ progress:Float, message:String)
    func setSegment()
    func showPrice(_ Id:String?)
}


class masterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, UIDocumentPickerDelegate, priceCellDelegate, UIPopoverPresentationControllerDelegate, masterUIDelegate  {
    
    var extVersion:Bool     = false     //擴充欄位 = false  匯出時及價格cell展開時，是否顯示擴充欄位？
    var lineReport:Bool     = false     //要不要在Line顯示日報訊息
    var lineLog:Bool        = false     //要不要在Line顯示沒有remark的Log
    var debugRun:Bool       = false     //是不是在Xcode之下Run，是的話不管lineLog為何，都會顯示Log
    var isLandScape         = UIDevice.current.orientation.isLandscape
    var isPad:Bool          = false

    let defaults:UserDefaults = UserDefaults.standard
    let serialOperation:OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
//    let dispatchGroup:DispatchGroup = DispatchGroup()
    let stock:simStock = simStock()
    var bot:lineBot?

    func nsLog(_ logText:String) {
        let inDetail:Bool = true
        if self.debugRun {
            if let f = logText.first {
                if let l = logText.last {
                    if (f == "=" || (!self.stock.simTesting && (inDetail || l == "*"))) {
                        NSLog(logText)
                    }
                }
            }
        }
    }
//    var lineMsg:String = ""
//    func masterLog(_ msg:String) {
//        let logLine:Bool = msg.first == "!"         //只用於抓蟲測試時強制輸出訊息到LINE
//        if self.lineLog || logLine || self.debugRun {
//            let notHideToLine:Bool = msg.first != "*"    //在LINE隱藏不發
//            let testReport:Bool = (msg.first == "=" || !stock.simTesting)   //有接Xcode就要發
//            if self.debugRun && testReport {
//                self.nsLog(msg)
//            }
//            if (self.lineLog || logLine) && notHideToLine && lineReport {
//                lineMsg += "\n" + msg
//                if (lineMsg.count > 1000 || msg.contains("\n") || logLine) {
//                    if let _ = bot?.userProfile {
//                        bot!.pushTextMessage(message:lineMsg)
//                        lineMsg = ""
//                    } else {
//                        lineMsg += "LINE is not ready.\n"
//                    }
//
//                }
//            }
//        }
//    }
    
    //vvvvv masterUIDelegate vvvvv
    func isExtVersion() -> Bool {
        return extVersion
    }
    
    func serialQueue() -> OperationQueue {
        return serialOperation
    }

    func systemSound(_ soundId:SystemSoundID) {
        AudioServicesPlaySystemSound(soundId)
    }

    func getStock() -> simStock {
        return stock
    }
    
    func masterSelf() -> masterViewController {
        return self
    }
    //^^^^^ masterUIDelegate ^^^^^
    
    

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var uiProgress: UIProgressView!
    @IBOutlet weak var uiMessage: UILabel!
    @IBOutlet weak var uiSetting: UIButton!
    @IBOutlet weak var uiSegment: UISegmentedControl!
    @IBOutlet weak var uiFooter: UILabel!
    @IBOutlet weak var uiFooterHeight: NSLayoutConstraint!
    @IBOutlet weak var uiScrollView: UIScrollView!
    

    @IBOutlet weak var uiLeftButton: UIButton!
    @IBOutlet weak var uiRightButton: UIButton!
    @IBOutlet weak var uiStockName: UIButton!
    @IBOutlet weak var uiProfitLoss: UILabel!
    @IBOutlet weak var uiMoneyChanged: UIButton!
    @IBOutlet weak var uiSimReversed: UIButton!

    @IBOutlet weak var uiBarRefresh: UIBarButtonItem!
    @IBOutlet weak var uiBarAction: UIBarButtonItem!
    @IBOutlet weak var uiBarAdd: UIBarButtonItem!
    @IBOutlet weak var uiInformation: UIButton!

    @IBAction func uiShiftLeft(_ sender: UIButton) {
        if stock.shiftLeft() {
            self.showPrice()
        }
    }

    @IBAction func uiShiftRight(_ sender: UIButton) {
        if stock.shiftRight() {
            self.showPrice()
        }
    }


    @IBAction func uiRefresh(_ sender: UIBarButtonItem) {
        if let sim = self.stock.simPrices[stock.simId] {
            if self.stock.priceTimer.isValid {
                self.stock.priceTimer.invalidate()
            }
            let textMessage = "刪除 " + stock.simId + " " + stock.simName + " 的歷史股價\n並重新下載？"
            let alert = UIAlertController(title: "重新下載或重算", message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "刪最後1個月", style: .destructive, handler: { action in
                self.lockUI("刪最後1個月")
                OperationQueue().addOperation {
                    sim.deletePrice(dateStart: twDateTime.startOfMonth(sim.dateRange().last), progress: true, solo:true)
                    DispatchQueue.main.async {
                        self.stock.timePriceDownloaded = Date.distantPast
                        self.stock.defaults.removeObject(forKey: "timePriceDownloaded")
                        self.stock.setupPriceTimer(self.stock.simId, mode: "all")
                    }
                }
            }))
            if sim.missed.count > 0 {
                alert.addAction(UIAlertAction(title: "刪缺漏之前的", style: .destructive, handler: { action in
                    self.lockUI("刪缺漏之前的")
                    OperationQueue().addOperation {
                        sim.deletePrice(dateEnd: sim.missed[0], progress: true, solo:true)
                        DispatchQueue.main.async {
                            self.stock.timePriceDownloaded = Date.distantPast
                            self.stock.defaults.removeObject(forKey: "timePriceDownloaded")
                            self.stock.setupPriceTimer(self.stock.simId, mode: "all")
                        }
                    }
                }))
            }
            alert.addAction(UIAlertAction(title: "全部刪除重算", style: .destructive, handler: { action in
                self.lockUI("全部刪除")
                OperationQueue().addOperation {
                    sim.deletePrice(progress: true, solo:true)
                    DispatchQueue.main.async {
                        self.stock.timePriceDownloaded = Date.distantPast
                        self.stock.defaults.removeObject(forKey: "timePriceDownloaded")
                        self.stock.setupPriceTimer(self.stock.simId, mode: "all")
                    }
                }

            }))
            alert.addAction(UIAlertAction(title: "不刪除只重算", style: .default, handler: { action in
                self.lockUI("重算模擬")
                OperationQueue().addOperation {
                    sim.resetSimUpdated(solo: true)
                    DispatchQueue.main.async {
                        self.stock.timePriceDownloaded = Date.distantPast
                        self.stock.defaults.removeObject(forKey: "timePriceDownloaded")
                        self.stock.setupPriceTimer(self.stock.simId, mode: "all")
                    }
                }
            }))
           self.present(alert, animated: true, completion: nil)
        }


    }

    @IBAction func uiExportCsv(_ sender: UIBarButtonItem) {
        saveAndExport()
    }

    @IBAction func uiNextMoneyChanged(_ sender: UIButton) {
        goNextMoneyChange()
    }

    @IBAction func uiNextSimReversed(_ sender: UIButton) {
        goNextSimReverse()
    }

    @IBAction func uiInfo(_ sender: UIButton) {
        func openUrl (_ url:String) {
            if let URL = URL(string: url) {
                if UIApplication.shared.canOpenURL(URL) {
                    UIApplication.shared.open(URL, options:[:], completionHandler: nil)
                } else {
                    let alert = UIAlertController(title: "simStock \(stock.versionNow)", message: "不知為何無法開啟頁面。", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "知道了", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        let textMessage = "查看網站說明或設定？" 
        let alert = UIAlertController(title: "simStock \(stock.versionNow)", message: textMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "不用了", style: .cancel, handler: nil))

//        alert.addAction(UIAlertAction(title: "主畫面", style: .default, handler: { action in
//            openUrl("https://sites.google.com/site/appsimStock/zhu-hua-mian")
//        }))
        alert.addAction(UIAlertAction(title: "練習方法", style: .default, handler: { action in
            openUrl("https://sites.google.com/site/appsimstock/ce-luee-yu-fang-fa/lian-xi-fang-fa")
        }))
//        alert.addAction(UIAlertAction(title: "常見問題", style: .default, handler: { action in
//            openUrl("https://sites.google.com/site/appsimStock/chang-jian-wen-ti")
//        }))
        alert.addAction(UIAlertAction(title: "版本說明", style: .default, handler: { action in
            openUrl("https://sites.google.com/site/appsimStock/ban-ben-shuo-ming")
        }))
        alert.addAction(UIAlertAction(title: "Yahoo!", style: .default, handler: { action in
            openUrl("https://tw.stock.yahoo.com/q/ta?s="+self.stock.simId)
        }))
        alert.addAction(UIAlertAction(title: "＊設定＊", style: .default, handler: { action in
            openUrl(UIApplication.openSettingsURLString)
        }))
        self.present(alert, animated: true, completion: nil)
    }


    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(masterViewController.updateRealtimeByPull), for: UIControl.Event.valueChanged)

        return refreshControl
    }()

    @objc func updateRealtimeByPull() {
        if stock.isUpdatingPrice && stock.priceTimer.isValid == false {
            refreshControl.endRefreshing()
        } else {
            self.stock.timePriceDownloaded = Date.distantPast
            self.defaults.removeObject(forKey: "timePriceDownloaded")
            self.stock.setupPriceTimer()
        }
    }
    
    @available(iOS 12.0, *)
    func donatePriceTimer() {
        let activity = NSUserActivity(activityType: "getPrices")
        let title = "更新成交價"
        activity.title = title
        activity.userInfo = ["mode": "all"]
        activity.suggestedInvocationPhrase = title
        activity.isEligibleForPrediction = true
        activity.isEligibleForSearch = true
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier("getPrices")
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributes.contentDescription = title
        activity.contentAttributeSet = attributes

        self.userActivity = activity

    }
    
//    @available(iOS 13.0, *)
//    func donatePushMessage() {
//        let intent = LinePushIntent()
//        intent.suggestedInvocationPhrase = "賴訊息"
//        intent.to = .team0
//        intent.message = "嗨。"
//        let interaction = INInteraction(intent: intent, response: nil)
//        interaction.donate { (error) in
//            if let error = error as NSError? {
//                self.nsLog("Interaction donation failed: \(error.description)")
//            } else {
//                self.nsLog("donated:賴訊息")
//            }
//        }
//
//    }


// *********************************
// ***** ===== Core Data ===== *****
// *********************************


    var _fetchedResultsController:NSFetchedResultsController<NSFetchRequestResult>?

    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        let fetchRequest = coreData.shared.fetchRequestPrice(sim:stock.simPrices[stock.simId]!, asc: false) as! NSFetchRequest<NSFetchRequestResult>
        _fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: coreData.shared.mainContext, sectionNameKeyPath: "year", cacheName: nil)
        _fetchedResultsController!.delegate = self
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            self.nsLog("masterView fetch error:\n\(error)\n")
        }
        return _fetchedResultsController!
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch(type) {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
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


















// ***********************************
// ***** ===== Master View ===== *****
// ***********************************

    override func viewDidLoad() {
        super.viewDidLoad()
        debugRun = defaults.bool(forKey: "debugRun")    //在edit scheme run argument 加入 "-debugRun YES"
        if (traitCollection.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
            isPad = true
        }

        stock.connectMasterUI(self) // <----- 起始參數 -----
        if gotDevelopPref == false { //iOSversion < "11" {
            getDevelopPref()    //iOS11和ApplicationDidBecomeActive重複?
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.willResignActiveNotification, object: nil)

        tableView.addSubview(self.refreshControl)

        UIDevice.current.isBatteryMonitoringEnabled = true

        uiMessage.adjustsFontSizeToFitWidth = true
        uiProfitLoss.adjustsFontSizeToFitWidth = true
        uiSetting.titleLabel?.adjustsFontSizeToFitWidth = true
        uiStockName.titleLabel?.adjustsFontSizeToFitWidth = true

        showPrice()

        self.nsLog("=== viewDidLoad \(stock.versionNow) ===")
        
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        let comfirmAlert = UIAlertController(title: "警告", message: "收到iOS說記憶體問題的警告了。", preferredStyle: .alert)
        comfirmAlert.addAction(UIAlertAction(title: "喔", style: .default, handler: nil))
        DispatchQueue.main.async {
            self.present(comfirmAlert, animated: true, completion: nil)
        }
        self.nsLog(">>> didReceiveMemoryWarning <<<\n")
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.nsLog("=== viewWillAppear ===")
        if idleTimerWasDisabled {   //如果之前有停止休眠
            if self.stock.isUpdatingPrice {
                self.setIdleTimer(timeInterval: -2)  //-2立即停止休眠
            } else if self.stock.needPriceTimer() {
                self.setIdleTimer(timeInterval: -1)  //-1有插電則停止休眠，否則120秒後恢復休眠
            } else {
                 self.setIdleTimer(timeInterval: 60)
            }
        }
        //檢查sortedStocksCopy是否有改動，以決定是否需要setupPriceTimer
        self.setProgress(0)
        if let _ = self.sortedStocksCopy {     //有沒有改動股群清單，或刪除又新增而使willUpdateAllSim為true？
            var eq:Bool = true
            for s in stock.sortedStocks {  //刪除的不用理，新增的或willUpdateAllSim才要更新
                if !self.sortedStocksCopy!.contains(where: {$0.id == s.id}) || stock.simPrices[s.id]!.willUpdateAllSim {
                    eq = false
                    if s.id == stock.simId {
                        showPrice()     //主畫面先切換到新代號
                    }
                    break
                }
            }

            if eq == false {    //改動了要去抓價格
                stock.setupPriceTimer() //(mode: "all")
            } else {
                if self.simIdCopy != "" && self.simIdCopy != stock.simId {
                    showPrice()
                }
            }


            self.sortedStocksCopy = nil
            self.simIdCopy = ""
        }
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.nsLog ("=== viewDidAppear ===\n")
        if UIDevice.current.orientation.isLandscape {
            isLandScape = true
        } else {
            isLandScape = false
        }
    }

    var idleTimerWasDisabled:Bool = false
    override func viewWillDisappear(_ animated: Bool) {
        self.nsLog("=== viewWillDisappear ===")
        idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
        if idleTimerWasDisabled {   //如果現在是停止休眠
            disableIdleTimer(false) //則離開前應立即恢復休眠排程
        }

    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if UIDevice.current.orientation.isLandscape {
            isLandScape = true
        } else {
            isLandScape = false
        }
        self.setSegment()   //iPad橫置時即時切換，最多可顯示25個首字分段按鈕
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setSegment()
    }



    @objc func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            self.nsLog ("=== appDidBecomeActive ===")
            if gotDevelopPref == false {
                let refreshTime:Bool = stock.timePriceDownloaded.compare(twDateTime.time1330()) == .orderedAscending && !stock.isTodayOffDay()  //不是休市日
                if defaults.bool(forKey: "removeStocks") || defaults.bool(forKey: "willAddStocks") || refreshTime {
                    navigationController?.popToRootViewController(animated: true)
                }
                getDevelopPref()
            }

        case UIApplication.willResignActiveNotification:
            self.nsLog ("=== appWillResignActive ===\n")
            if self.stock.priceTimer.isValid {
                self.stock.priceTimer.invalidate()
            }
            self.gotDevelopPref = false
            if !self.stock.simTesting {
                self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
            }
            idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
            if idleTimerWasDisabled {   //如果現在是停止休眠
                disableIdleTimer(false) //則離開前應立即恢復休眠排程
            }
            guard let url = URL(string: "http://mis.twse.com.tw/stock/fibest.jsp?lang=zh_tw") else {return}
            let storage = HTTPCookieStorage.shared
            if let cookies = storage.cookies(for: url) {
                for cookie in cookies {
                    storage.deleteCookie(cookie)
                }
            }
            
        default:
            break
        }

    }


















    var gotDevelopPref:Bool = false
    func getDevelopPref() {     //開發測試的選項及下載股價
        gotDevelopPref = true
        
        extVersion = defaults.bool(forKey: "extsionMode")
        lineLog    = defaults.bool(forKey: "lineLog")       //是否輸出除錯訊息
        lineReport = defaults.bool(forKey: "lineReport")    //是否輸出LINE日報
        if self.stock.priceTimer.isValid {
            self.stock.priceTimer.invalidate()
        }
        if bot == nil {
            bot = lineBot()
        }
        if lineReport {
            bot!.verifyToken()
        } else {
            bot!.logout()
            bot = nil
        }
        let twseRealtime = defaults.bool(forKey: "realtimeSource")
        if  twseRealtime {
            stock.realtimeSource = "twse"
        } else {
            stock.realtimeSource = "yahoo"
        }

        let twseMain = defaults.bool(forKey: "mainSource")
        if  twseMain {
            stock.mainSource = "twse"
        } else {
            stock.mainSource = "cnyes"
        }


        let locked = defaults.bool(forKey: "locked")
        if locked && stock.isUpdatingPrice == false {
            self.nsLog("locked? -> continue.")
        }

        uiMessageClear()
        simSettingChangedCopy  = nil

        if !twDateTime.isDateInToday(stock.timePriceDownloaded) {
            stock.todayIsNotWorkingDay = false
        }

        if stock.simTesting {
            func launchTesting(fromYears:Int, forYears:Int, loop:Bool) {
                let simFirst:simPrice =  self.stock.simPrices[self.stock.sortedStocks[0].id]!
                let dtStart:String =  twDateTime.stringFromDate(simFirst.defaultDates(fromYears:fromYears).dateStart, format: "yyyy/MM/dd")
                var idList:String = ""
                for s in self.stock.sortedStocks {
                    if s.id != "t00" {
                        if idList == "" {
                            idList += s.id + " " + s.name
                        } else {
                            idList += ", " + s.id + " " + s.name
                        }
                    }
                }
                self.nsLog("== runSimTesting \(fromYears)年 \(dtStart)起 \(loop ? "每" : "單")輪\(forYears)年 ==\n\n\(idList)\n")
                self.stock.runSimTesting(fromYears: fromYears, forYears: forYears, loop: loop)
            }
            if stock.justTestIt {
                launchTesting(fromYears:13, forYears:3, loop:true)
            } else {
                let textMessage = "執行幾年模擬測試？"
                let alert = UIAlertController(title: "模擬測試", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: {action in
                    self.stocksPref()
                }))
                alert.addAction(UIAlertAction(title: "13年起每輪3年", style: .default, handler: {action in
                    launchTesting(fromYears:13, forYears:3, loop:true)
                }))
                alert.addAction(UIAlertAction(title: "13年起每輪2年", style: .default, handler: {action in
                    launchTesting(fromYears:13, forYears:2, loop:true)
                }))
                alert.addAction(UIAlertAction(title: "13年內重算MA", style: .default, handler: {action in
                    launchTesting(fromYears:13, forYears:13, loop:false)
                }))
                alert.addAction(UIAlertAction(title: "10年起每輪2年", style: .default, handler: {action in
                    launchTesting(fromYears:10, forYears:2, loop:true)
                }))
                alert.addAction(UIAlertAction(title: "10年起每輪3年", style: .default, handler: {action in
                    launchTesting(fromYears:10, forYears:3, loop:true)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            stocksPref()
        }

    }

    func stocksPref() {
        stock.resetSimTesting()

        if let t = defaults.object(forKey: "timeReported") {
            timeReported = t as! Date
        }
        let dt_updated  = twDateTime.stringFromDate(stock.timePriceDownloaded, format:"yyyy/MM/dd HH:mm:ss.SSS")
        let dt_reported = twDateTime.stringFromDate(timeReported, format:"yyyy/MM/dd HH:mm:ss.SSS")
        self.nsLog("updated:  \(dt_updated)")
        self.nsLog("reported: \(dt_reported)")

        if !NetConnection.isConnectedToNetwork() {
            messageWithTimer("沒有網路",seconds: 7)
            self.nsLog("沒有網路。")
        }

        askToRemoveStocks()

    }

    @objc func askToRemoveStocks() {
        
        func removeStocksAction(_ action:String) {
            self.lockUI(action)
            DispatchQueue.global().async {
                for sim in Array(self.stock.simPrices.values) {   //暫停模擬的股不處理
                    switch action {
                    case "移除全部股群":  //移除中股群數會變動，這還不知道要怎樣計算進度？
                        let _ = self.stock.removeStock(sim.id)
                    case "刪除全部股價":
                        sim.deletePrice(progress:true)
                    case "刪最後1個月股價":
                        if !sim.paused {
                            let dt = sim.dateRange()
                            let dtS = twDateTime.startOfMonth(dt.last)
                            let dtE = twDateTime.endOfMonth(dt.last)
                            sim.deletePrice(dateStart: dtS, dateEnd: dtE, progress: true)
                        }
                    case "重算統計數值":
                        sim.resetSimUpdated()
                    default:
                        break
                    }
                    self.nsLog("\(action)\t\(sim.id)\(sim.name)")
                }
                if action == "刪最後1個月股價" {
                    let fetched = coreData.shared.fetchTimeline(fetchLimit:1, asc: false)
                    if let t = fetched.Timelines.first {
                        let dtE = twDateTime.startOfMonth(t.date)
                        coreData.shared.deleteTimeline(fetched.context, dateOP:">=", date: dtE)
                    }
                } else {
                    coreData.shared.deleteTimeline()
                }
                if action == "重算統計數值" {
                    self.unlockUI()
                }
                self.stock.timePriceDownloaded = Date.distantPast
                self.defaults.removeObject(forKey: "timePriceDownloaded")
                DispatchQueue.main.async {
                    self.askToAddTestStocks()
                }
            }
        }
        //移除或刪除股群的選單
        if defaults.bool(forKey: "resetStocks") {
            let textMessage = "重算數值或刪除股群及價格？\n（移除股群時會保留\(self.stock.defaultName)喔）"
            let alert = UIAlertController(title: "重算或刪除股群", message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { action in
                self.askToAddTestStocks()
                self.unlockUI()
            }))
            if stock.simPrices.count > 1 {
                alert.addAction(UIAlertAction(title: "移除全部股群", style: .destructive, handler: { action in
                    removeStocksAction("移除全部股群")
                }))
            }
            alert.addAction(UIAlertAction(title: "刪除全部股價", style: .destructive, handler: { action in
                removeStocksAction("刪除全部股價")
            }))
            alert.addAction(UIAlertAction(title: "刪最後1個月股價", style: .destructive, handler: { action in
                removeStocksAction("刪最後1個月股價")
            }))
            alert.addAction(UIAlertAction(title: "重算統計數值", style: .default, handler: { action in
                removeStocksAction("重算統計數值")
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            askToAddTestStocks()
        }
    }
    
    

    @objc func askToAddTestStocks() {
        self.defaults.set(false, forKey: "resetStocks") //到這裡就是之前已經完成刪除股群及價格或重算數值的作業了
        if self.defaults.bool(forKey: "willAddStocks") { //self.willLoadSims.count > 0 {
            let textMessage = "要載入哪類股群？\n（50股要下載好一會兒喔）"
            let alert = UIAlertController(title: "載入或匯入股群", message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { action in
                self.stock.setupPriceTimer()    //(mode:"all")
            }))
            alert.addAction(UIAlertAction(title: "CSV匯入資料庫", style: .destructive, handler: { action in
                let types: [String] = [kUTTypeText as String]
                let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
                documentPicker.delegate = self
                documentPicker.modalPresentationStyle = .formSheet
                self.present(documentPicker, animated: true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: "測試10股群", style: .default, handler: { action in
                self.addTestStocks("Test10")
            }))
            alert.addAction(UIAlertAction(title: "*台灣加權指數", style: .default, handler: { action in
                self.addTestStocks("t00")
            }))
            self.present(alert, animated: true, completion: {
                self.defaults.set(false, forKey: "willAddStocks")
            })
        } else {
            if self.stock.needPriceTimer() {
                //==================== setupPriceTimer ====================
                //事先都沒有指定什麼，就可以開始排程下載新股價
                var timeDelay:TimeInterval = 0
                let timerMode = self.stock.whichMode()
                if self.stock.timePriceDownloaded.timeIntervalSinceNow > (0 - self.stock.realtimeInterval) && timerMode == "realtime" {
                    timeDelay = self.stock.realtimeInterval + self.stock.timePriceDownloaded.timeIntervalSinceNow
                }
                self.stock.setupPriceTimer(mode:timerMode, delay:timeDelay)
            } else {
                self.nsLog("no priceTimer.\n")
                self.showPrice()
            }
        }
    }



    func addTestStocks(_ group:String) {
        
        if self.stock.isUpdatingPrice == false {
            self.nsLog("addTestStocks: \(group)")
            self.stock.addTestStocks(group)
            self.defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期以強制importFromDictionary()
            self.stock.setupPriceTimer()    //(mode:"all")
        } else {
            self.nsLog("delay: addTestStocks: \(group)")
            let noRemove = UIAlertController(title: "暫停載入股群", message: "等網路作業結束一會兒，\n會再詢問是否要載入。", preferredStyle: UIAlertController.Style.alert)
            noRemove.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
                Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(masterViewController.askToAddTestStocks), userInfo: nil, repeats: false)
                self.nsLog ("Timer for askToAddTestStocks in 7s.")
                
            }))
            self.present(noRemove, animated: true, completion: nil)
        }

    }

    //匯入CSV到Coredata
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let csvURL = urls.first else {
              return
        }
        var result:Int = -1  //0:匯入完畢 -1:不能匯入 1:匯入失敗
        DispatchQueue.global().async {
            do {
                let csvFile = try String(contentsOf: csvURL, encoding: .utf8)
                self.lockUI("匯入CSV", solo: true)
                result = self.stock.csvImport(csv: csvFile)
                if result != 0 {
                    throw NSError()
                }
            } catch {
                let comfirmAlert = UIAlertController(title: "CSV匯入資料庫", message: "無法匯入。這個檔案可能不是simStock原生CSV？", preferredStyle: .alert)
                comfirmAlert.addAction(UIAlertAction(title: "知道了", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(comfirmAlert, animated: true, completion: nil)
                    self.unlockUI()
                }
                self.nsLog("documentPicker error")
            }
            if result >= 0 {
                self.stock.setupPriceTimer()    //(mode: "all", delay: 0)
            }
        }

    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        unlockUI()
    }

    




























    @IBAction func uiSwipeLeft(_ sender: UISwipeGestureRecognizer) {
        if self.stock.isUpdatingPrice == false {
            if sender.direction == UISwipeGestureRecognizer.Direction.left {
                if stock.shiftRight() {
                    showPrice()
                }
            } else if sender.direction == UISwipeGestureRecognizer.Direction.right {
                if stock.shiftLeft() {
                    showPrice()
                }
            }
        }
    }


    var PanX:Int = 0
    @IBAction func uiPanGesture(_ sender: UIPanGestureRecognizer) {
        if stock.isUpdatingPrice == false {
            switch sender.state {
            case .began:
                PanX = 0
            case .changed:
                let theOldX = PanX
                let theNewX = Int(round(sender.translation(in: view).x / 40))
                if theOldX != theNewX {
                    let movedX = theNewX - theOldX
                    if movedX > 0 { //向右拖曳
                        if stock.shiftLeft() {
                            showPrice()
                        }
                    } else {
                        if stock.shiftRight() {
                            showPrice()
                        }
                    }
                    PanX = theNewX
                }
            default:
                if PanX != 0 {
                    tableView.isUserInteractionEnabled = true
                }
            }
        }
    }


    @IBAction func uiSegmentChanged(_ sender: UISegmentedControl) {
        if let t = sender.titleForSegment(at: sender.selectedSegmentIndex) {
            if let Id = stock.segmentId[t] {
                self.showPrice(Id)
            }
        }
    }

    func setSegment() { //這段都應該在main執行
        DispatchQueue.main.async {
            let segmentCount:Int = self.stock.segment.count
            let isFullScreen:Bool = {
                if let d = UIApplication.shared.delegate {
                    if let w = d.window {
                        return w!.frame.equalTo(w!.screen.bounds)
                    }
                }
                return true
            }()
            let countLimit:Int = {
                if self.isPad {
                    if isFullScreen {
                        return (UIDevice.current.orientation.isLandscape ? 31 : 21)
                    } else {
                        return (UIDevice.current.orientation.isLandscape ? 13 : 7)
                    }
                } else {
                    return (UIDevice.current.orientation.isLandscape ? 15 : 7)
                }
            }()
            let countMid:Int   = (countLimit - 1) / 2
            var IndexFrom:Int = 0
            var IndexTo:Int   = 0
            var simIndex:Int  = 0
            if let sIndex = self.stock.segmentIndex[self.stock.simId] {
                simIndex = sIndex   //畫面目前的Id對照首字的Index
            }
            if segmentCount > countLimit {
                if simIndex <= countMid {
                    IndexFrom = 0
                    IndexTo   = countLimit - 1
                } else if simIndex >= (segmentCount - countMid) {
                    IndexFrom = segmentCount - countLimit
                    IndexTo   = segmentCount - 1
                } else {
                    IndexFrom = simIndex - countMid
                    IndexTo   = simIndex + countMid
                }
            } else if segmentCount > 2 {
                IndexTo = segmentCount - 1
            }
            self.uiSegment.isEnabled = false
            self.uiSegment.isHidden = true
            self.uiSegment.removeAllSegments()
            if IndexTo > 0 && segmentCount == self.stock.segment.count {
                var simN0:String = ""
                if let n0 = self.stock.simName.first {
                    simN0 = String(n0)
                }
                let sItems = Array(self.stock.segment[IndexFrom...IndexTo])
                for title in sItems {
                    let i = self.uiSegment.numberOfSegments
                    self.uiSegment.insertSegment(withTitle: title, at: i, animated: false)
                    if title == simN0 {
                        self.uiSegment.selectedSegmentIndex = i
                    }
                }
                if self.uiSegment.numberOfSegments > 2 {
                    self.uiSegment.isHidden = false
                    self.uiSegment.isEnabled = true
                    self.uiSegment.sizeToFit()  //可能是iOS12的bug有時不會autosize
                }
            }
            self.updateSummary()    //橫置時顯示「平均週期」
        }
    }







































    




    @IBAction func uiDoubleTap(_ sender: UITapGestureRecognizer) {
       if let _ = fetchedResultsController.fetchedObjects {
            if fetchedResultsController.fetchedObjects!.count > 0 {
                let indexPath:IndexPath = IndexPath(row: 0, section: 0)
                tableView.scrollToRow(at: indexPath, at: .none, animated: true)
                scrollFooter(toEnd: false)
            }
        }
    }


    @IBAction func uiTripleTap(_ sender: UITapGestureRecognizer) {
        if let _ = fetchedResultsController.fetchedObjects {
            if fetchedResultsController.fetchedObjects!.count > 0 {
                let firstPrice = fetchedResultsController.fetchedObjects!.last as! Price //最後1筆，也就是最早的股價
                if let indexPath = fetchedResultsController.indexPath(forObject: firstPrice) {
                    tableView.scrollToRow(at: indexPath, at: .none, animated: true)
                    scrollFooter(toEnd: true)
                }
            }
        }
    }
    
    
    @IBAction func uiDoubleTapScrollView(_ sender: UITapGestureRecognizer) {
        scrollFooter(toEnd: false)
    }
    
    @IBAction func uiTripleTapScrollView(_ sender: UITapGestureRecognizer) {
        scrollFooter(toEnd: true)
    }
    
    func scrollFooter(toEnd:Bool) {
        if let footer = uiFooter.text {
            if footer.count > 0 {
                let offsetX = uiScrollView.contentSize.width - uiScrollView.bounds.size.width
                if toEnd && offsetX > 0 {
                    let offsetCG = CGPoint(x: offsetX + 20, y: self.uiScrollView.contentOffset.y)
                    self.uiScrollView.setContentOffset(offsetCG, animated: true)
                } else {
                    let offsetCG = CGPoint(x:0, y:0)
                    uiScrollView.setContentOffset(offsetCG, animated: true)
                }
            }
        }
    }
    

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "segueSetting" {
            if let _ = stock.simPrices[stock.simId] {
                return true
            } else {
                return false
            }
        }
        return true
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var identifier:String
        if let _ = segue.identifier {
            identifier = segue.identifier!
        } else {
            identifier = ""
        }
        switch identifier {
        case "segueToStockList":
            self.nsLog ("=== segueToStockList ===")

            if let stockView = segue.destination as? stockViewController {
                self.simIdCopy = stock.simId
                self.sortedStocksCopy = stock.sortStocks()
                stockView.masterUI = self

                let backItem = UIBarButtonItem()
                backItem.title = ""
                navigationItem.backBarButtonItem = backItem
            }
        case "segueStockPicker":
            if let pickerView = segue.destination as? pickerViewController {
                self.simIdCopy = stock.simId
                pickerView.masterUI = self
                pickerView.popoverPresentationController?.delegate = self
                if let sourceView = pickerView.popoverPresentationController?.sourceView {
                    pickerView.popoverPresentationController?.sourceRect = sourceView.bounds
                }

            }
        case "segueSetting":
            if let settingView = segue.destination as? settingViewController {
                settingView.masterUI = self
                if let sim = stock.simPrices[stock.simId] {
                    simPriceCopy = stock.copySimPrice(sim)    //保存未變動前的單股設定
                }
                settingView.popoverPresentationController?.delegate = self
                if let sourceView = settingView.popoverPresentationController?.sourceView {
                    settingView.popoverPresentationController?.sourceRect = sourceView.bounds
                }

            }
        default:
            break
        }
    }





























//
//
//
//
//
//
//
//
//
//
//
//
//
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// ========== updatePrice ========
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//

//    let dispatchGroupWaitForPrices:DispatchGroup = DispatchGroup()
//    let dispatchGroupWaitForRemoves:DispatchGroup = DispatchGroup()

    // ********** 模擬參數 **********
    var simPriceCopy:simPrice?
    var simSettingChangedCopy:simPrice?
    var simIdCopy:String?
    var sortedStocksCopy:[(id:String,name:String)]?

    func lockUI(_ message:String="", solo:Bool=false) {
        DispatchQueue.main.async {
            if self.stock.priceTimer.isValid {
                self.stock.priceTimer.invalidate()
            }
            self.messageWithTimer(message,seconds: 0)
            self.uiProfitLoss.textColor    = UIColor.lightGray
            self.uiInformation.isEnabled   = false
            self.uiBarAdd.isEnabled        = false
            self.uiBarAction.isEnabled     = false
            self.uiBarRefresh.isEnabled    = false    //先lock沒錯
            self.uiSetting.isEnabled       = false
            self.uiMoneyChanged.isEnabled  = false
            self.uiSimReversed.isEnabled   = false
            self.uiStockName.isEnabled     = false
            self.uiRightButton.isEnabled   = false
            self.uiLeftButton.isEnabled    = false
            self.uiSegment.isEnabled       = false
            self.refreshControl.endRefreshing()
            self.stock.isUpdatingPrice = true
            if let rows = self.tableView.indexPathsForVisibleRows {
                self.tableView.reloadRows(at: rows, with: .fade)   //讓加碼按鈕失效
            }
            self.defaults.set(true, forKey: "locked")
            self.nsLog(">>> lockUI...\(message) \(solo ? "solo" : "")")
            self.setIdleTimer(timeInterval: -2)     //立即停止休眠，即使沒有插電
            self.stock.updatedPrices = []
        }
    }

    func unlockUI(_ message:String="") {
        //unlockUI最好統一由stock.setProgress(,1)來觸發
        DispatchQueue.main.async {
            self.uiProfitLoss.textColor    = UIColor.darkGray
            self.uiBarAdd.isEnabled        = true
            self.uiBarAction.isEnabled     = true
            self.uiBarRefresh.isEnabled    = true
            self.uiInformation.isEnabled   = true
            self.uiSetting.isEnabled       = true
            self.uiMoneyChanged.isEnabled  = true
            self.uiSimReversed.isEnabled   = true
            self.uiStockName.isEnabled     = true
            self.uiRightButton.isEnabled   = true
            self.uiLeftButton.isEnabled    = true
            self.uiSegment.isEnabled       = true
            if let rows = self.tableView.indexPathsForVisibleRows {
                self.tableView.reloadRows(at: rows, with: .fade)   //讓加碼按鈕生效
            }
            self.setProgress(1)
            self.setProgress(0)
            self.stock.isUpdatingPrice = false
            self.stock.updatedPrices = []
            self.defaults.set(false, forKey: "locked")
            self.showPrice()
            if message.count > 0 {
                self.messageWithTimer(message,seconds: 7)
                self.nsLog("<<< unlockUI: \(message)")
            } else {
                self.uiMessageClear()
                self.nsLog("<<< unlockUI")
            }
            if self.stock.versionLast < self.stock.versionNow && message != "" { //含versionLast == "" 的時候
                self.goToReleaseNotes()
                self.stock.versionLast = self.stock.versionNow
            }
            self.setIdleTimer(timeInterval: 60) //60秒後恢復休眠排程
            if !self.stock.simTesting {
                self.stock.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
            }
        }
        if !self.stock.switchToYahoo || Date().compare(twDateTime.time1330()) == .orderedDescending {
            self.reportToLINE()
        }
    }

    func goToReleaseNotes() {
        if self.stock.simTesting {
            return
        }
        let textMessage = "前往開發網站查看\n" + stock.versionNow + "版的變更說明？"
        let alert = UIAlertController(title: "Release Notes", message: textMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "不用", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
            if let URL = URL(string: "https://sites.google.com/site/appsimStock/ban-ben-shuo-ming") {
                UIApplication.shared.open(URL, options: [:], completionHandler: nil)
            }
        }))
        self.present(alert, animated: true, completion: nil)

    }

    var timeReported:Date = Date.distantPast
    var reportCopy:String = ""
    func reportToLINE(oneTimeReport:Bool=false) {
        if let bot = self.bot, lineReport && stock.simTesting == false {
            var closedReport:Bool = false
            var inReportTime:Bool = false
            if !oneTimeReport {
                let todayNow = Date()
                let time0920:Date = twDateTime.timeAtDate(todayNow, hour: 09, minute: 20)
                let time1020:Date = twDateTime.timeAtDate(todayNow, hour: 10, minute: 20)
                let time1120:Date = twDateTime.timeAtDate(todayNow, hour: 11, minute: 20)
                let time1220:Date = twDateTime.timeAtDate(todayNow, hour: 12, minute: 20)
                let time1320:Date = twDateTime.timeAtDate(todayNow, hour: 13, minute: 20)
                let time1332:Date = twDateTime.time1330(todayNow, delayMinutes: 2)

                let inMarketingTime:Bool = !stock.todayIsNotWorkingDay && twDateTime.marketingTime(todayNow)
                inReportTime = inMarketingTime && (
                    (todayNow.compare(time0920) == .orderedDescending && self.timeReported.compare(time0920) == .orderedAscending) ||
                        (todayNow.compare(time1020) == .orderedDescending && self.timeReported.compare(time1020) == .orderedAscending) ||
                        (todayNow.compare(time1120) == .orderedDescending && self.timeReported.compare(time1120) == .orderedAscending) ||
                        (todayNow.compare(time1220) == .orderedDescending && self.timeReported.compare(time1220) == .orderedAscending) ||
                        (todayNow.compare(time1320) == .orderedDescending && self.timeReported.compare(time1320) == .orderedAscending))
                closedReport = !stock.todayIsNotWorkingDay && todayNow.compare(time1332) == .orderedDescending && self.timeReported.compare(time1332) == .orderedAscending
            }
            if (inReportTime || closedReport || oneTimeReport) {
                //以上3種時機：盤中時間、收盤日報、日報測試
                let report = stock.composeReport(isTest:oneTimeReport)
                if report.count > 0 && (report != self.reportCopy || !inReportTime)  {
                    if isPad {  //我用iPad時為特殊情況，日報是送到小確幸群組
                        bot.pushTextMessage(to: "team", message: report)
                    } else {    //其他人是從@Line送給自己的帳號
                        bot.pushTextMessage(message: report)
                    }
                    self.timeReported = defaults.object(forKey: "timeReported") as! Date
                    if self.timeReported.compare(twDateTime.time1330()) != .orderedAscending {
                        self.timeReported = Date()  //收盤後的1332是最後一次日報截止時間
                        self.defaults.set(self.timeReported, forKey: "timeReported")
                    }
                    self.reportCopy = report
                }

            }
        }
    }

















    var idleTimer:Timer?
    func setIdleTimer(timeInterval:TimeInterval) {  //幾秒後恢復休眠排程
        //  UIDevice.current.batteryState == .unplugged
        if timeInterval == 0 {
            disableIdleTimer(false)              //立即恢復休眠
        } else if timeInterval < 0  {
            if timeInterval == -1 && UIDevice.current.batteryState == .unplugged {
                self.idleTimer = Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(masterViewController.disableIdleTimer), userInfo: nil, repeats: false)
                self.nsLog("idleTimer in \(120)s.\n") //-1沒插電延後120秒恢復休眠排程
            }  else {
                disableIdleTimer(true)           //-2立即停止休眠
                if let _ = idleTimer {
                    idleTimer?.invalidate()
                    idleTimer = nil
                    self.nsLog("no idleTimer.\n")
                }
            }
        } else {
            self.idleTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(masterViewController.disableIdleTimer), userInfo: nil, repeats: false)
            self.nsLog("idleTimer in \(timeInterval)s.\n") //恢復休眠排程
        }
    }

    @objc func disableIdleTimer(_ on:Bool=false) {
        UIApplication.shared.isIdleTimerDisabled = on    //預設參數是啟動休眠
    }

    @objc func uiMessageClear(_ timer:Timer?=nil) {
        var msg:String = ""
        if let t = timer {
            msg = t.userInfo as! String
        }
        if msg == "" || uiMessage.text == msg {
            uiMessage.text = ""
        }
    }

    var msgTimer:Timer = Timer()
    func messageWithTimer(_ text:String="",seconds:Int=0) {  //timer是0秒，表示不設timer來清除訊息
        DispatchQueue.main.async {
            self.uiMessage.text = text
            if seconds > 0 {
                self.msgTimer = Timer.scheduledTimer(timeInterval: Double(seconds), target: self, selector: #selector(masterViewController.uiMessageClear), userInfo: text, repeats: false)
            }
        }
    }

    func setProgress(_ progress:Float, message:String="") { //progress == -1 表示沒有執行什麼，跳過
        let hidden:Bool = (progress == 0 ? true : false)
        DispatchQueue.main.async {
            if self.uiProgress.isHidden != hidden {
                self.uiProgress.isHidden = hidden
            }
            self.uiProgress.setProgress(progress, animated: false) //animate)
        }
        if message.count > 0 {
            if msgTimer.isValid {
                msgTimer.invalidate()
            }
            self.messageWithTimer(message,seconds:0)
        } else {
            if progress == 0 {
                self.messageWithTimer()
            }
        }
    }




























    
    func showPrice(_ Id:String?=nil) {
        //fetch之前要先save不然就會遇到以下error:
        //CoreData: error:  API Misuse: Attempt to serialize store access on non-owning coordinator
        if let id = Id {
            let _ = self.stock.setSimId(newId: id)
        }
        DispatchQueue.main.async {
            coreData.shared.saveContext()
            self.updateSummary()
            self.setProgress(0)
            self.fetchPrice()
            self.updateSummary()
        }

    }

    func fetchPrice() {
        _fetchedResultsController = nil
        //帶入資料庫的起迄交易日期
        if fetchedResultsController.fetchedObjects!.count > 0 {
            let fetchedCount = fetchedResultsController.fetchedObjects?.count
            self.nsLog("\(stock.simId)\(stock.simName) \tfetchPrice: \(fetchedCount!)筆")

        } else {
            self.nsLog("\(stock.simId)\(stock.simName) \tfetchPrice... no objects.")

        }
        tableView.reloadData()

    }

    func initSummary() {
        uiMessageClear()
        setStockNameTitle()
        uiSetting.setTitle(String(format:"本金%.f萬元 期間%.1f年",0,0), for: UIControl.State())
        uiProfitLoss.text = formatProfitLoss(simPL: 0,simROI: 0, simDays: 0, qtyInventory: 0)
        uiMoneyChanged.isHidden = true
        uiSimReversed.isHidden = true
        uiFooter.text = ""
        uiFooterHeight.constant = 0
    }

    func setStockNameTitle(_ id:String="") {
        var newId:String = ""
        if id == "" {
            newId = stock.simId
        } else {
            newId = id
        }
        if let sim = stock.simPrices[newId] {
            uiStockName.setTitle(stock.simId + " " + sim.name, for: UIControl.State())
        }
    }

    //更新結餘標示，在runAllsimPrice之後執行
    func updateSummary() {
        setStockNameTitle()
        if let sim = stock.simPrices[stock.simId] {
            let roi = sim.ROI()
            let lastQtyInventory = (sim.getPriceLast("qtyInventory") as? Double ?? 0)
            uiProfitLoss.text = formatProfitLoss(simPL:roi.pl, simROI:roi.roi, simDays:Int(roi.days), qtyInventory: lastQtyInventory)
            var moneyTitle:String = String(format:"本金%.f萬元",stock.simPrices[stock.simId]!.initMoney)
            if sim.maxMoneyMultiple > 1 {
                uiMoneyChanged.isHidden = false
                moneyTitle = moneyTitle + String(format:"x%.f",stock.simPrices[stock.simId]!.maxMoneyMultiple)
            } else {
                uiMoneyChanged.isHidden = true
            }
            if sim.simReversed {
                uiSimReversed.isHidden = false
            } else {
                uiSimReversed.isHidden = true
            }
            let timeTitle:String = String(format:"期間%.1f年",roi.years)
            uiSetting.setTitle((moneyTitle + " " + timeTitle), for: UIControl.State())
            let reportFooter = sim.reportMissed()
            uiFooter.text = reportFooter
            if reportFooter.count > 0 {
                uiFooterHeight.constant = (isPad ? 30 : 24)
            } else {
                uiFooterHeight.constant = 0
            }
        } else {
            initSummary()
        }

    }

    func formatProfitLoss(simPL:Double,simROI:Double,simDays:Int,qtyInventory:Double) -> String {
        var textString:String = ""
        var formatTxt = ""
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency   //貨幣格式
        numberFormatter.maximumFractionDigits = 0
        var textPL:String = ""
        if let t = numberFormatter.string(for: simPL) {
            textPL = t
        }
        formatTxt = "累計損益%@"
        if qtyInventory > 0 {
            formatTxt = "損益含未實現%@"
        }
        formatTxt = formatTxt + " 平均年報酬率%.1f%%"
        if simDays > 0 && (isPad || isLandScape) {
            formatTxt += " 平均週期\(simDays)天"
        }

        textString = String(format:formatTxt,textPL,simROI)

        return textString
    }




















    //Export
    func saveAndExport() {
        if stock.sortedStocks.count > 2 {
            let textMessage = "選擇範圍和內容？"
            let alert = UIAlertController(title: "匯出CSV檔案"+(lineReport ? "或傳送日報" : ""), message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "各股CSV.zip", style: .default, handler: { action in
                self.csvExport("all")
            }))
            alert.addAction(UIAlertAction(title: "全股合併CSV", style: .default, handler: { action in
                self.csvExport("allInOne")
            }))
            alert.addAction(UIAlertAction(title: "只要\(stock.simId)\(stock.simName)的CSV", style: .default, handler: { action in
                self.csvExport("single")
            }))
            if lineReport {
                alert.addAction(UIAlertAction(title: "送出LINE日報", style: .default, handler: { action in
                    self.reportToLINE(oneTimeReport: true)
                }))
            }
            self.present(alert, animated: true, completion: nil)
        } else {
            self.csvExport("single")
        }
    }

    func csvExport (_ type:String) {

        func csvToFile(_ type:String, id:String="", timeStamp:Date) -> String { //產生單csv檔案
            var csv:String = ""
            var fileURL:String = ""
            var fileName:String = ""
            if type == "allInOne" {
                fileName = twDateTime.stringFromDate(timeStamp, format: "yyyyMMdd-HHmmssSSS") + "_simStock" + ".csv"
            } else { // if type == "all" || type == "single" {
                if let s = self.stock.simPrices[id] {
                    let dtStart:String = twDateTime.stringFromDate(s.dateStart, format: "yyyyMMdd")
                    let dtEnd:String = twDateTime.stringFromDate((s.dateEndSwitch ? s.dateEnd : Date()), format: "yyyyMMdd")
                    fileName = id + s.name + "_" + dtStart + "-" + dtEnd + ".csv"
                }
            }
            fileURL = NSTemporaryDirectory().appending(fileName)
            csv = stock.csvExport(type, id:id)
            do {
                try csv.write(toFile: fileURL, atomically: true, encoding: .utf8)
            } catch {
                self.nsLog("csvToFile error \t\(error)")
            }
            return fileURL
        }
        
        func exportFile(_ fileURLs:[URL]) { //popup匯出單csv或zip檔案
            let activityViewController : UIActivityViewController = UIActivityViewController(activityItems: fileURLs, applicationActivities: nil)
            activityViewController.excludedActivityTypes = [    //標為註解以排除可用的，留下不要的
                .addToReadingList,
    //            .airDrop,
                .assignToContact,
    //            .copyToPasteboard,
    //            .mail,
    //            .markupAsPDF,   //iOS11之後才有
    //            .message,
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
            activityViewController.completionWithItemsHandler = {activity, success, items, error in
                self.sortedStocksCopy = self.stock.sortStocks() //作弊讓viewWillApear時不再updatePrices
            }
            DispatchQueue.main.async {
                self.present(activityViewController, animated: true, completion: nil)
            }
        }

        var fileURL:[URL] = []
        var filePaths:[String] = []
        let timeStamp = Date()
        self.lockUI("匯出檔案")
        DispatchQueue.global().async {
            if type == "all" {  //各股CSV.zip
                for (id,_) in self.stock.sortedStocks {
                    filePaths.append(csvToFile(type, id:id, timeStamp: timeStamp))
                }
                filePaths.append(self.csvSummaryFile(timeStamp: timeStamp))
                filePaths.append(self.csvMonthlyRoiFile(timeStamp: timeStamp))
                let zipName = twDateTime.stringFromDate(timeStamp, format: "yyyyMMdd_HHmmssSSS") + ".zip"
                let zipPath = NSTemporaryDirectory().appending(zipName)
                SSZipArchive.createZipFile(atPath: zipPath, withFilesAtPaths: filePaths)
                fileURL = [URL(fileURLWithPath: zipPath)]
            } else if type == "allInOne" {  //全股合併CSV
                fileURL = [URL(fileURLWithPath: csvToFile(type, timeStamp: timeStamp))]
            } else {    //單股CSV
                fileURL = [URL(fileURLWithPath: csvToFile(type, id:self.stock.simId, timeStamp: timeStamp))]
            }
            DispatchQueue.main.async {
                exportFile(fileURL)
            }
        }

    }







    func csvSummaryFile(timeStamp:Date) -> String {
        let fileName = twDateTime.stringFromDate(timeStamp, format: "_累計年平均_yyyyMMdd_hhmmssSSS") + ".csv"
        let filePath = NSTemporaryDirectory().appending(fileName)

        var text = ""
        text  = self.stock.csvSummary() //<<<<<<<<<< 產出csv內容
        text += "\n匯出時間: \(twDateTime.stringFromDate(timeStamp, format: "yyyy/MM/dd HH:mm:ss.SSS"))\n"
        do {
            try text.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            self.nsLog("error in csvSummaryFile\n\(error)")
        }
        self.nsLog("*csv \(fileName)")
        DispatchQueue.main.async {
            self.uiProgress.setProgress(1, animated: true)
        }
        return filePath

    }

    func csvMonthlyRoiFile(timeStamp:Date) -> String {
        let fileName = twDateTime.stringFromDate(timeStamp, format: "_逐月已實現_yyyyMMdd_hhmmssSSS") + ".csv"
        let filePath = NSTemporaryDirectory().appending(fileName)

        var text = ""
        text  = self.stock.csvMonthlyRoi()  //<<<<<<<<<< 產出csv內容，不指定起迄日代表模擬期間全部
        text += "\n匯出時間: \(twDateTime.stringFromDate(timeStamp, format: "yyyy/MM/dd HH:mm:ss.SSS"))\n"
        do {
            try text.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            self.nsLog("error in csvSummaryFile\n\(error)")
        }
        self.nsLog("*csv \(fileName)")
        DispatchQueue.main.async {
            self.uiProgress.setProgress(1, animated: true)
        }
        return filePath

    }
































    // ===== Table View =====

    func numberOfSections(in tableView: UITableView) -> Int {
        let sections = (fetchedResultsController.sections?.count ?? 0)
        return sections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let _ = fetchedResultsController.sections {
            let sectionInfo = fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
            return sectionInfo.numberOfObjects
        }
        return 0


    }

    func price10Message(id:String, dateTime:Date) -> (message:String,width:CGFloat,height:CGFloat,delay:Int)? {
        if let sim = stock.simPrices[id] {
            if sim.price10.count > 0 {
//                let dt = sim.dateRange()
                if !stock.todayIsNotWorkingDay && twDateTime.marketingTime(dateTime) && twDateTime.isDateInToday(dateTime) && sim.getPriceLast("simReverse") as? String != "買" {
                    
                    func rightPadding(text:String ,toLength: Int, withPad character: Character) -> String {
                        let newLength = text.count    //在固定長度的String右邊填空白
                        if newLength < toLength {
                            return text + String(repeatElement(character, count: toLength - newLength))
                        } else {
                            return text
                        }
                    }
                    
                    var tapMsg:[String] = []
                    var rowL:Int = 0
                    var rowH:Int = 0
                    for p in sim.price10 {
                        let msg = rightPadding(text:String(format:"%.2f \(p.action) %.f (%.1f%%)",p.close,p.qty,p.roi),toLength: 19,withPad: " ")
                        if p.side == "L" {
                            tapMsg.append(msg)
                            rowL += 1
                        } else {
                            if tapMsg.count >= (rowH + 1) {
                                tapMsg[rowH]  += "\(msg)"
                            } else {
//                                tapMsg.append((rowL > 0 ? String(repeatElement(" ", count: 20)) : "") + msg)
                                tapMsg.append((rowL > 0 ? rightPadding(text:" ",toLength: 20,withPad: " ") : "") + msg)
                            }
                            rowH += 1
                        }
                    }
                    let msg = tapMsg.joined(separator: "\n")
                    let width = CGFloat(rowL > 0 && rowH > 0 ? 400 : 200)
                    let height  = CGFloat(tapMsg.count <= 2 ? 48 : tapMsg.count * 22)
                    let delay   = 5
                    return (msg,width,height,delay)
                }
            }
        }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cellPrice", for: indexPath) as! priceCell
        cell.masterView = self  //cellDelegate
        
        let price = fetchedResultsController.object(at: indexPath) as! Price

        cell.uiDate.text = twDateTime.stringFromDate(price.dateTime, format: "yyyy/MM/dd")
        cell.uiTime.text = twDateTime.stringFromDate(price.dateTime, format: "EEE HH:mm:ss")
        
        cell.uiClose.text = String(format:"%.2f",price.priceClose)
        cell.uiClose.textColor = simRuleColor(price.simRule)    //收盤價的顏色根據可買規則分類
        cell.uiClose.gestureRecognizers = nil
        if let p10 = price10Message(id: price.id, dateTime: price.dateTime) {
            let tapRecognizerClose:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
            tapRecognizerClose.message = p10.message
            tapRecognizerClose.width   = p10.width
            tapRecognizerClose.height  = p10.height
            tapRecognizerClose.delay   = p10.delay
            cell.uiClose.gestureRecognizers = [tapRecognizerClose]
            cell.uiClose.text = String(format:"[%.2f]",price.priceClose)
        }

        if twDateTime.marketingTime(price.dateTime) {
            cell.uiLabelClose.text = "成交價"
            cell.uiTime.textColor = UIColor.orange
            cell.uiDate.textColor = UIColor.orange
            
        } else {
            cell.uiLabelClose.text = "收盤價"
            cell.uiTime.textColor = UIColor.darkGray
            cell.uiDate.textColor = UIColor.darkGray
            
        }

        switch price.priceUpward {
        case "▲","▵","up":
            cell.uiLabelClose.text = cell.uiLabelClose.text! + price.priceUpward
            cell.uiLabelClose.textColor = UIColor.red
        case "▼","▿","down":
            cell.uiLabelClose.text = cell.uiLabelClose.text! + price.priceUpward
            cell.uiLabelClose.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
        default:
            cell.uiLabelClose.textColor = UIColor.darkGray
        }
        cell.uiDivCash.text = ""
        cell.uiDivCash.isHidden = true
        cell.uiConsDivCash.constant = 0
        if price.dividend == 0 {
            cell.uiLabelClose.text = cell.uiLabelClose.text! + "\n[除權息]"
            if let amt = self.stock.simPrices[price.id]?.dateDividend[twDateTime.startOfDay(price.dateTime)] {
                if amt > 0 {
                    cell.uiDivCash.text = String(format:"(+%.2f)",amt)
                    cell.uiDivCash.isHidden = false
                    cell.uiConsDivCash.constant = 4 //讓成交價的位置略下移
                }
            }
        }
//        //為測試暫時顯示成交量
//        cell.uiDivCash.text = String(format:"(+%.2f)",price.priceVolume)
//        cell.uiDivCash.isHidden = false
//        cell.uiConsDivCash.constant = 4

        if price.qtyBuy != 0 {
            cell.uiSimTrans1.text = "買"
            cell.uiSimTrans1.textColor = UIColor.red
            cell.uiSimTrans2.text = String(format:"%.f",price.qtyBuy)
            cell.uiSimTrans2.textColor = UIColor.red
        } else if price.qtySell != 0 {
            cell.uiSimTrans1.text = "賣"
            cell.uiSimTrans1.textColor = UIColor.blue
            cell.uiSimTrans2.text = String(format:"%.f",price.qtySell)
            cell.uiSimTrans2.textColor = UIColor.blue
        } else if price.qtyInventory != 0 {
            cell.uiSimTrans1.text = "餘"
            cell.uiSimTrans1.textColor = UIColor.brown
            cell.uiSimTrans2.text = String(format:"%.f",price.qtyInventory)
            cell.uiSimTrans2.textColor = UIColor.brown
        } else {
            cell.uiSimTrans1.text = ""
            cell.uiSimTrans2.text = ""
        }

        if price.simDays != 0 {
            cell.uiSimDays.text = String(format:"%.f天",price.simDays)
        } else {
            cell.uiSimDays.text = ""
        }

        if price.qtyInventory != 0 || price.qtySell != 0 {
            cell.uiSimUnitCost.text = String(format:"%.2f",price.simUnitCost)
            cell.uiSimUnitDiff.text = String(format:"%.2f%%",price.simUnitDiff)
            if price.simUnitDiff < -45 {
                cell.uiSimUnitDiff.textColor = UIColor(red:0, green:192/255, blue:0, alpha:1)
            } else if price.simUnitDiff >= -45 && price.simUnitDiff < -35 {
                cell.uiSimUnitDiff.textColor = UIColor(red:0, green:160/255, blue:0, alpha:1)
            } else if price.simUnitDiff >= -35 && price.simUnitDiff < -25 {
                cell.uiSimUnitDiff.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
            } else if price.simUnitDiff > 6.4 && price.simUnitDiff <= 9.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:128/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 9.4 && price.simUnitDiff <= 13.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:160/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 13.4 && price.simUnitDiff <= 16.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:192/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 16.4 && price.simUnitDiff <= 19.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:224/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 19.4  {
                cell.uiSimUnitDiff.textColor = UIColor.red
            } else {
                cell.uiSimUnitDiff.textColor = UIColor.darkGray
            }

            cell.uiSimCost.text = String(format:"%.f萬元",price.simCost/10000)
            cell.uiSimCost.isHidden = false
            cell.uiSimUnitCost.isHidden = false
            cell.uiSimUnitDiff.isHidden = false
            cell.uiLabelCost.isHidden = false
            cell.uiLabelUnitCost.isHidden = false
            cell.uiLabelUnitDiff.isHidden = false
            cell.uiTipForQty.isHidden = false
        } else {
            cell.uiSimCost.text = ""
            cell.uiSimUnitCost.text = ""
            cell.uiSimUnitDiff.text = ""
            cell.uiSimCost.isHidden = true
            cell.uiSimUnitCost.isHidden = true
            cell.uiSimUnitDiff.isHidden = true
            cell.uiLabelCost.isHidden = true
            cell.uiLabelUnitCost.isHidden = true
            cell.uiLabelUnitDiff.isHidden = true
            cell.uiTipForQty.isHidden = true
        }
        
        if price.simROI != 0 || price.qtySell != 0 {
            cell.uiSimROI.text = String(format:"%.1f%%",price.simROI)
            cell.uiTipForButton.text = "報酬率"
        } else {
            cell.uiSimROI.text = ""
            cell.uiTipForButton.text = ""
        }


        if price.simIncome != 0 {
            cell.uiSimIncome.text = String(format:"%.f千元",price.simIncome/1000)
            cell.uiSimIncome.isHidden = false
            cell.uiLabelIncome.isHidden = false
        } else {
            cell.uiSimIncome.text = ""
            cell.uiSimIncome.isHidden = true
            cell.uiLabelIncome.isHidden = true
        }

        
        if price.moneyMultiple > 0 {
            if price.moneyMultiple == 1 {
                cell.uiMoneyBuy.text = "本金餘"
            } else {
                cell.uiMoneyBuy.text = String(format:"%.fx本金餘",price.moneyMultiple)
            }
            let buyMoney:Double = price.simBalance //(price.moneyMultiple * stock.simPrices[stock.simId]?.initMoney * 10000) - price.simCost
            cell.uiSimMoney.text = String(format:"%.f萬元",buyMoney/10000)
            if let initMoney = stock.simPrices[price.id]?.initMoney {
                let simPL:Double = price.simBalance - (price.moneyMultiple  * initMoney * 10000) + (price.qtyInventory > 0 ? price.simIncome + price.simCost : 0)
                cell.uiSimPL.text = String(format:"%.f千元",simPL/1000)
            } else {
                cell.uiSimPL.text = "0元"
            }
            cell.uiMoneyBuy.isHidden = false
            cell.uiSimMoney.isHidden = false
            cell.uiSimPL.isHidden = false
            cell.uiLabelPL.isHidden = false
        } else {
            cell.uiSimMoney.text = ""
            cell.uiMoneyBuy.text = ""
            cell.uiMoneyBuy.isHidden = true
            cell.uiSimMoney.isHidden = true
            cell.uiSimPL.isHidden = true
            cell.uiLabelPL.isHidden = true
        }


        //以下是cell展開後的欄位

        cell.uiOpen.text = String(format:"%.2f",price.priceOpen)
        cell.uiHigh.text = String(format:"%.2f",price.priceHigh)
        cell.uiLow.text = String(format:"%.2f",price.priceLow)
        cell.uiMA20.text = String(format:"%.2f",price.ma20)
        cell.uiMA60.text = String(format:"%.2f",price.ma60)
        cell.uiMacdOsc.text = String(format:"%.2f",price.macdOsc)
        cell.uiK.text = String(format:"%.2f",price.kdK)
        cell.uiD.text = String(format:"%.2f",price.kdD)
        cell.uiJ.text = String(format:"%.2f",price.kdJ)



        var lastPrice:Price?
        var nextIndexPath = indexPath

        let numberOfRows = fetchedResultsController.sections![indexPath.section].numberOfObjects
        let numberOfSections = fetchedResultsController.sections!.count
        if numberOfRows > 1 && indexPath.row < numberOfRows - 1 {
            nextIndexPath.row += 1
        } else if numberOfSections > 1 && indexPath.section < numberOfSections - 1 {
            nextIndexPath.section += 1
            nextIndexPath.row = 0
        }
        if nextIndexPath != indexPath {
            lastPrice = fetchedResultsController.object(at: nextIndexPath) as? Price
        }
        cell.uiHigh.gestureRecognizers = nil
        cell.uiLow.gestureRecognizers = nil
        if price.priceHighDiff >= 6 {
            if price.priceHighDiff > 9 {
                cell.uiHigh.textColor = UIColor.red
                cell.uiHigh.text = "▲" + cell.uiHigh.text!
            } else {
                cell.uiHigh.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                cell.uiHigh.text = "▵" + cell.uiHigh.text!
            }
            let tapRecognizerHighDiff:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
            tapRecognizerHighDiff.message = String(format:"最高價漲\(price.priceHighDiff == 10 ? "停" : "%.2f%%")",price.priceHighDiff)
            tapRecognizerHighDiff.delay   = 2
            cell.uiHigh.gestureRecognizers = [tapRecognizerHighDiff]
        } else {
            cell.uiHigh.textColor = UIColor.darkGray
        }
        if price.priceLowDiff >= 5 {
            if price.priceLowDiff > 9 {
                cell.uiLow.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
                cell.uiLow.text = "▼" + cell.uiLow.text!
            } else {
                cell.uiLow.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
                cell.uiLow.text = "▿" + cell.uiLow.text!
            }
            let tapRecognizerLowDiff:TapGesture = TapGesture.init(target: self, action: #selector(self.TapPopover))
            tapRecognizerLowDiff.message = String(format:"最低價跌\(price.priceLowDiff == 10 ? "停" : "%.2f%%")",price.priceLowDiff)
            tapRecognizerLowDiff.delay   = 2
            cell.uiLow.gestureRecognizers = [tapRecognizerLowDiff]
        } else {
            cell.uiLow.textColor = UIColor.darkGray
        }
 
        var growing:String = ""
        if price.macd9 != 0 {    //不是最早那一筆
            if price.kdK == price.kMinIn5d {
                growing = "▼"
            } else if price.kdK == price.kMaxIn5d {
                growing = "▲"
            } else if let last = lastPrice {
                if price.kdK > last.kdK {
                    growing = "▵"
                } else if price.kdK < last.kdK {
                    growing = "▿"
                }
            }
        }
        cell.uiK.text = growing + cell.uiK.text!

        growing = ""
        if price.macd9 != 0 {
            if price.macdOsc == price.macdMin9d {
                growing = "▼"
            } else if price.macdOsc == price.macdMax9d {
                growing = "▲"
            } else if let last = lastPrice {
                if price.macdOsc > last.macdOsc {
                    growing = "▵"
                } else if price.macdOsc < last.macdOsc {
                    growing = "▿"
                }
            }
        }
        cell.uiMacdOsc.text = growing + cell.uiMacdOsc.text!


        if price.macdOsc < price.macdOscL {
            cell.uiMacdOsc.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
        } else if price.macdOsc < (price.macdOscL * 0.6) {
            cell.uiMacdOsc.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
        } else if price.macdOsc > price.macdOscH {
            cell.uiMacdOsc.textColor = UIColor.red
        } else if price.macdOsc > (price.macdOscH * 0.6) {
            cell.uiMacdOsc.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
        } else {
            cell.uiMacdOsc.textColor = UIColor.darkGray
        }

        //K,D,J的顏色標示
        if (price.kdK > price.k80Base) {
            cell.uiK.textColor = UIColor.red
        } else if (price.kdK) < round(price.k20Base / 2) {
            cell.uiK.textColor = UIColor(red:0, green:192/255, blue:0, alpha:1)
        } else if (price.kdK < price.k20Base) {
            cell.uiK.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
        } else {
            cell.uiK.textColor = UIColor.darkGray
        }
        if (price.kdD > price.k80Base) {
            cell.uiD.textColor = UIColor.red
        } else if (price.kdD < price.k20Base) {
            cell.uiD.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
        } else {
            cell.uiD.textColor = UIColor.darkGray
        }
        if (price.kdJ > 100) {
            cell.uiJ.textColor = UIColor.red
        } else if (price.kdJ < -1) {
            cell.uiJ.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
        } else {
            cell.uiJ.textColor = UIColor.darkGray
        }

        //以下是Extension欄位
        if extVersion {

            cell.uiMA20Diff.text = String(format:"%.2f",price.ma20Diff)
            cell.uiMA60Diff.text = String(format:"%.2f",price.ma60Diff)
            cell.uiMADiff.text = String(format:"%.2f",price.maDiff)

            cell.uiMA20Min.text = String(format:"%.2f",price.ma20Min9d)
            cell.uiMA60Min.text = String(format:"%.2f",price.ma60Min9d)
            cell.uiMAMin.text = String(format:"%.2f",price.maMin9d)

            cell.uiMA20Max.text = String(format:"%.2f",price.ma20Max9d)
            cell.uiMA60Max.text = String(format:"%.2f",price.ma60Max9d)
            cell.uiMAMax.text = String(format:"%.2f",price.maMax9d)

            cell.uiMA20Days.text = String(format:"%.f",price.ma20Days)
            cell.uiMA60Days.text = String(format:"%.f",price.ma60Days)
            cell.uiMADays.text = String(format:"%.f",price.maDiffDays)

            if price.ma20Diff < price.ma20L {
                cell.uiMA20Diff.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else if price.ma20Diff > price.ma20H {
                cell.uiMA20Diff.textColor = UIColor.red
            } else {
                cell.uiMA20Diff.textColor = UIColor.darkGray
            }
            if price.ma60Diff < price.ma60L {
                cell.uiMA60Diff.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else if price.ma60Diff > price.ma60H {
                cell.uiMA60Diff.textColor = UIColor.red
            } else {
                cell.uiMA60Diff.textColor = UIColor.darkGray
            }
            
            if price.ma20Diff == price.ma20Min9d {
                cell.uiMA20Min.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else {
                cell.uiMA20Min.textColor = UIColor.darkGray
            }
            if price.ma20Diff == price.ma20Max9d {
                cell.uiMA20Max.textColor = UIColor.red
            } else {
                cell.uiMA20Max.textColor = UIColor.darkGray
            }
            if price.ma60Diff == price.ma60Min9d {
                cell.uiMA60Min.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else {
                cell.uiMA60Min.textColor = UIColor.darkGray
            }
            if price.ma60Diff == price.ma60Max9d {
                cell.uiMA60Max.textColor = UIColor.red
            } else {
                cell.uiMA60Max.textColor = UIColor.darkGray
            }
            if price.maDiff == price.maMin9d {
                cell.uiMAMin.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else {
                cell.uiMAMin.textColor = UIColor.darkGray
            }
            if price.maDiff == price.maMax9d {
                cell.uiMAMax.textColor = UIColor.red
            } else {
                cell.uiMAMax.textColor = UIColor.darkGray
            }

            
            cell.uiOscMin.text = String(format:"%.2f",price.macdMin9d)
            cell.uiOscMax.text = String(format:"%.2f",price.macdMax9d)
            cell.uiOscL.text = String(format:"%.1f",price.macdOscL)
            cell.uiOscH.text = String(format:"%.1f",price.macdOscH)
            if price.macdOsc == price.macdMin9d {
                cell.uiOscMin.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else {
                cell.uiOscMin.textColor = UIColor.darkGray
            }
            if price.macdOsc == price.macdMax9d {
                cell.uiOscMax.textColor = UIColor.red
            } else {
                cell.uiOscMax.textColor = UIColor.darkGray
            }


            cell.uiP60L.text  = String(format:"%.1f",price.price60LowDiff)
            cell.uiP60H.text  = String(format:"%.1f",price.price60HighDiff)
            cell.uiP250L.text = String(format:"%.1f",price.price250LowDiff)
            cell.uiP250H.text = String(format:"%.1f",price.price250HighDiff)

            cell.uiK20.text = String(format:"%.f",price.k20Base)
            cell.uiK80.text = String(format:"%.f",price.k80Base)

            let ma20HL:Double = (price.ma20H - price.ma20L == 0 ? 0.5 : price.ma20H - price.ma20L)
            let ma60HL:Double = (price.ma60H - price.ma60L == 0 ? 0.5 : price.ma60H - price.ma60L)
            let ma20MaxHL:Double = (price.ma20Max9d - price.ma20Min9d) / ma20HL
            let ma60MaxHL:Double = (price.ma60Max9d - price.ma60Min9d) / ma60HL
            cell.uiMA20L.text = String(format:"%.1f",price.ma20L)
            cell.uiMA20H.text = String(format:"%.1f",price.ma20H)
            cell.uiMA60L.text = String(format:"%.1f",price.ma60L)
            cell.uiMA60H.text = String(format:"%.1f",price.ma60H)
            cell.uiMA20MaxHL.text = String(format:"%.2f",ma20MaxHL)
            cell.uiMA60MaxHL.text = String(format:"%.2f",ma60MaxHL)
            
            cell.uiKZ.text  = String(format:"%.1f",price.kdKZ)
            cell.uiOscZ.text = String(format:"%.1f",price.macdOscZ)
            cell.uiMA60Z.text = String(format:"%.1f,%.1f,%.1f",price.ma60Z,price.ma60Z2,price.ma60Z1)
            cell.uiVolumeZ.text = String(format:"%.1f",price.priceVolumeZ)

            cell.uiUpdatedBy.text = price.updatedBy
            switch price.updatedBy {
            case "Google","Yahoo","yahoo","twse":
                cell.uiUpdatedBy.textColor = UIColor.orange
            case "CNYES":
                cell.uiUpdatedBy.textColor = UIColor(red:128/255, green:128/255, blue:0, alpha:1) //黃綠色
            case "TWSE":
                cell.uiUpdatedBy.textColor = UIColor(red:0/255, green:51/255, blue:153/255, alpha:1)
            default:
                cell.uiUpdatedBy.textColor = UIColor.darkGray
            }
            
            let rules:[String] = ["L","M","N","H","I","J","S","S-"]
            let ruleLevel:String = (rules.contains(price.simRule) ? String(format:"%.f",price.simRuleLevel) : "")
            let simRule:String = (price.simRule.count > 0 ? "(" + price.simRule + ruleLevel + ")" : "")
            cell.uiSimRule.text = price.simRuleBuy + simRule
            
            cell.uiMA60Avg.text = String(format:"%.1f",price.ma60Avg) + price.ma60Rank


            //Rank的顏色標示
            switch price.ma60Rank {
            case "A":
                cell.uiMA60Avg.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
            case "B":
                cell.uiMA60Avg.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
            case "C+":
                cell.uiMA60Avg.textColor = UIColor(red: 96/255, green:0, blue:0, alpha:1)
            case "C":
                cell.uiMA60Avg.textColor = UIColor.darkGray
            case "C-":
                cell.uiMA60Avg.textColor = UIColor(red: 0, green:64/255, blue:0, alpha:1)
            case "D":
                cell.uiMA60Avg.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
            case "E":
                cell.uiMA60Avg.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
            default:
                cell.uiMA60Avg.textColor = UIColor.darkGray
            }

            if price.simUpdated {
                cell.uiUpdatedBy.backgroundColor = UIColor.clear
            } else {
                cell.uiUpdatedBy.backgroundColor = UIColor.yellow
                cell.uiUpdatedBy.textColor = UIColor.red
            }
        }


        //反轉按鈕
        if self.stock.isUpdatingPrice == false {
            cell.uiSimReverse.isSelected = false
            cell.uiSimReverse.isEnabled = true
            cell.uiSimReverse.isHidden = false
            if price.simReverse == "" {
                cell.uiSimReverse.isHidden = true
            } else if price.simReverse != "無" {
                cell.uiSimReverse.isSelected = true
            }
        } else {
            cell.uiSimReverse.isEnabled = false
            cell.uiSimReverse.isSelected = false
            cell.uiSimReverse.isHidden = false
        }
        if cell.uiSimReverse.isSelected {
            cell.uiSimReverse.tintColor = UIColor.clear
        } else {
            cell.uiSimReverse.tintColor = self.view.tintColor
        }



        //加碼按鈕
        if let button = cell.uiButtonIncrease {
            if price.moneyChange > 0 {
                button.isSelected = true
                button.isHidden = false
                button.tintColor = UIColor.clear
            } else if price.moneyRemark != "+" { //既未曾加碼也沒有建議加碼
                button.isSelected = false
                cell.uiButtonIncrease.isHidden = true
                button.tintColor = self.view.tintColor
            } else {
                button.isSelected = false
                button.isHidden = false
                button.tintColor = self.view.tintColor
            }
            if stock.isUpdatingPrice == false {
                button.isEnabled = true
            } else {
                button.isEnabled = false
            }
        }

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



    func simRuleColor(_ simRule:String) -> UIColor {
        //可買規則分色
        var sRule:String = ""
        var rColor:UIColor //= UIColor.darkGray
        if let r = simRule.first {
            sRule = String(describing: r)
        }
        
        switch sRule {
        case "H":   //追高
            rColor = UIColor(red: 96/255, green:0, blue:0, alpha:1)
        case "L":   //承低
            rColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
        case "X":   //測試
            rColor = UIColor.blue
        case "M","N","I","J":   //暫停、待變
            rColor = UIColor.systemGray
        default:    //沒有、不變：""、"S"、"S-"、"S+"
            rColor = UIColor.darkGray
        }
        
        return rColor

    }




    //加減碼按鈕的行動
    func moneyChanging (_ sender:UITableViewCell,changeFactor:Double) {
        if let indexPath = self.tableView.indexPath(for: sender) {
            let price = fetchedResultsController.object(at: indexPath) as! Price
            var change:Double = 0
            if price.moneyChange == 0 {   //還沒增減
                if price.moneyMultiple > 1 {
                    if changeFactor == -1 { //已經超過1個資本，應該要減到1個資本
                        change = changeFactor * (price.moneyMultiple - 1)
                    } else if changeFactor == 1 { //繼續加碼
                        change = changeFactor
                    }
                } else if price.moneyMultiple == 1 {
                    if changeFactor == 1 { //已1個資本，只能繼續加碼
                        change = changeFactor
                    }
                }
                price.moneyChange = change   //還沒加碼就加碼（或減碼）
            } else {
                price.moneyChange = 0        //已加碼就還原（或減碼）
            }
            coreData.shared.saveContext()
            if let rows = tableView.indexPathsForVisibleRows {
                tableView.reloadRows(at: rows, with: .fade)
            }
            self.stock.simPrices[self.stock.simId]!.willGiveMoney = false   //暫停自動加碼
            self.stock.simPrices[self.stock.simId]!.willUpdateAllSim = true
            self.stock.setupPriceTimer(self.stock.simId, mode: "simOnly")
        }
    }

    //反轉模擬按鈕的行動
    var lastReversed:(date:Date,action:String) = (Date.distantPast,"")
    func reverseAction (_ sender:UITableViewCell,button:UIButton) {
        if let indexPath = self.tableView.indexPath(for: sender) {
            self.stock.isUpdatingPrice = true
            let price = self.fetchedResultsController.object(at: indexPath) as! Price
            let dt:Date = twDateTime.startOfDay(price.dateTime)
            if let act = self.stock.simPrices[self.stock.simId]?.setReverse(date: dt) {
                if dt == self.lastReversed.date && act == self.lastReversed.action && self.stock.sortedStocks.count > 2 {
                    var actionMessage:String = ""
                    switch act {
                    case "買":
                        actionMessage = "買入"
                    case "賣":
                        actionMessage = "賣出"
                    default:
                        actionMessage = "復原"
                    }
                    let textMessage = "套用到其他股票\n" + "於同日全部" + actionMessage + "？"
                    let alert = UIAlertController(title: "全部套用", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "不用", style: .cancel, handler: { action in
                        self.stock.setupPriceTimer(self.stock.simId, mode: "simOnly")
                        self.lastReversed.date = Date.distantPast
                        self.lastReversed.action = ""
                    }))
                    alert.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
                        
                        for (id,_) in self.stock.sortedStocks {
                            if id != price.id {
                                _ = self.stock.simPrices[id]!.setReverse(date: dt,action: act)
                                //這裡已經有把willUpdateAllSim = true
                            }
                        }
                        self.stock.setupPriceTimer(mode: "simOnly")
                        self.lastReversed.action = ""
                        self.lastReversed.date = Date.distantPast
                    }))
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                } else {
                        self.stock.setupPriceTimer(self.stock.simId, mode: "simOnly")
                        self.lastReversed.date = dt
                        self.lastReversed.action = act
                }
            }
            if let rows = self.tableView.indexPathsForVisibleRows {
                self.tableView.reloadRows(at: rows, with: .fade)
            }
            self.stock.isUpdatingPrice = false
        }

    }











    func goNextMoneyChange() {
        if let dt = stock.simPrices[stock.simId]?.dateRange() {
            var scrollToIndexPath:IndexPath?
            var dateOfMoneyChange:Date = dt.last

            if fetchedResultsController.fetchedObjects!.count > 0 {
                if let visibleRows = tableView.indexPathsForVisibleRows {
                    for indexPath in visibleRows.reversed() {
                        let price = fetchedResultsController.object(at: indexPath) as! Price
                        if price.moneyChange > 0 {
                            dateOfMoneyChange = price.dateTime  //得畫面第一筆有moneyChange的日期
                            break
                        }
                    }
                }
                let fetched = coreData.shared.fetchPrice(sim:stock.simPrices[stock.simId]!,dateOP:"<",dateStart: dateOfMoneyChange,asc: false)
                for price in fetched.Prices { //往後找
                    if price.moneyChange > 0 {
                        if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                            scrollToIndexPath = priceIndexPath
                        }
                        break
                    }

                }
                if scrollToIndexPath == nil {   //後面沒有，再從頭找起
                    let fetched = coreData.shared.fetchPrice(sim:stock.simPrices[stock.simId]!,dateOP:">",dateStart: dateOfMoneyChange,asc: false)
                    for price in fetched.Prices {
                        if price.moneyChange > 0 {
                            if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                                scrollToIndexPath = priceIndexPath
                            }
                            break
                        }
                    }

                }
                if let _ = scrollToIndexPath {  //找到了就捲過去
                    tableView.scrollToRow(at: scrollToIndexPath!, at: UITableView.ScrollPosition.middle, animated: true)
                }
            }
        }
    }

    func goNextSimReverse() {
        if let dt = stock.simPrices[stock.simId]?.dateRange() {
            var scrollToIndexPath:IndexPath?
            var dateOfSimReverse:Date = dt.last

            if fetchedResultsController.fetchedObjects!.count > 0 {
                if let visibleRows = tableView.indexPathsForVisibleRows {
                    for indexPath in visibleRows.reversed() {
                        let price = fetchedResultsController.object(at: indexPath) as! Price
                        if price.simReverse != "無" && price.simReverse != "" {
                            dateOfSimReverse = price.dateTime  //得畫面末筆有moneyChange的日期
                            break
                        }
                    }
                }
                let fetched = coreData.shared.fetchPrice(sim:stock.simPrices[stock.simId]!,dateOP:"<",dateStart: dateOfSimReverse,asc: false)
                for price in fetched.Prices { //往後找
                    if price.simReverse != "無" && price.simReverse != "" {
                        if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                            scrollToIndexPath = priceIndexPath
                        }
                        break
                    }
                }
                if scrollToIndexPath == nil {   //後面沒有，再從頭找起
                    let fetched = coreData.shared.fetchPrice(sim:stock.simPrices[stock.simId]!,dateOP:">",dateStart: dateOfSimReverse,asc: false)
                    for price in fetched.Prices {
                        if price.simReverse != "無" && price.simReverse != "" {
                            if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                                scrollToIndexPath = priceIndexPath
                            }
                            break
                        }
                    }
                }
                if let _ = scrollToIndexPath {  //找到了就捲過去
                    tableView.scrollToRow(at: scrollToIndexPath!, at: UITableView.ScrollPosition.middle, animated: true)
                }
            }
        }
    }










    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let bg0h:CGFloat = (self.isPad ?  43 : 33)
        if selectedCellIndexPath == indexPath {
            let price = fetchedResultsController.object(at: indexPath) as! Price
            var bg1h:CGFloat = (self.isPad ? 202.5 : 164.67)
            var bg2h:CGFloat = 0
            if price.qtyInventory == 0 && price.qtySell == 0 {
                bg1h -= (self.isPad ? 20 : 14)
            }
            if price.dividend == 0 {
                bg1h += (self.isPad ? 20 : 14)
            }
            if extVersion {
                bg2h = (self.isPad ? 276 : 218)
            }
            return bg0h + bg1h + bg2h
        } else {
            return bg0h
        }

    }



    var selectedCellIndexPath: IndexPath?

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if selectedCellIndexPath != nil && selectedCellIndexPath == indexPath {
            selectedCellIndexPath = nil
        } else {
            selectedCellIndexPath = indexPath
        }
        tableView.beginUpdates()    //???
        tableView.endUpdates()

        if selectedCellIndexPath != nil {
            // This ensures, that the cell is fully visible once expanded
            tableView.scrollToRow(at: indexPath, at: .none, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if extVersion {
            if let c = tableView.cellForRow(at: indexPath) {
                let cell = c as! priceCell
                let price = fetchedResultsController.object(at: indexPath) as! Price
                if price.simUpdated {
                    cell.uiUpdatedBy.backgroundColor = UIColor.clear
                } else {
                    cell.uiUpdatedBy.backgroundColor = UIColor.yellow
                }
            }
        }

    }


    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var sectionHeader:String = ""
        if let sections = fetchedResultsController.sections {
            sectionHeader = sections[section].name
         }

        return sectionHeader
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        let title = UILabel()
        if self.isPad {
            title.font = UIFont.systemFont(ofSize: CGFloat(20))
        } else {
            title.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)   //標準字體大小
        }
        title.textColor = UIColor.lightGray

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font=title.font
        header.textLabel?.textColor=title.textColor

    }



        //提供年度末兩碼的索引，不好按
        func sectionIndexTitles(for tableView: UITableView) -> [String]? {
            var titles:[String] = []
            if let sections = fetchedResultsController.sections {
                if sections.count > 7 {
                    for section in sections {
                        let t = String(section.name[section.name.index(section.name.endIndex, offsetBy: -2)...])
                        titles.append(t)
                    }
                    return titles
                }
            }
            return nil

        }
    
        func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
            if let sections = fetchedResultsController.sections {
                for (i,section) in sections.enumerated() {
                    let t = String(section.name[section.name.index(section.name.endIndex, offsetBy: -2)...])
                    if t == title {
                        return i
                    }
                }
            }
            return index
        }




    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        // Return no adaptive presentation style, use default presentation behaviour
        return .none
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        //do som stuff from the popover
        var settingDate:(startOnly:Bool,endOnly:Bool,allStart:Bool,allEnd:Bool,allSwitch:Bool) = (false,false,false,false,false)
        var settingInitMoney:(selfOnly:Bool,all:Bool) = (false,false)
        var settingGiveMoney:(resetOnly:Bool,resetAll:Bool,giveOnly:Bool,giveAll:Bool,reverseOnly:Bool,reverseAll:Bool) = (false,false,false,false,false,false)
        var settingMessage:String = ""
        if let sCopy = simPriceCopy {   //股票設定的開窗關閉之後
            if let s = stock.simPrices[stock.simId] {
                if s.willResetReverse {
                    settingGiveMoney.reverseOnly = true
                    if let changedCopy = simSettingChangedCopy {
                        if s.willResetReverse && changedCopy.willResetReverse && changedCopy.id != stock.simId {
                            settingMessage += "\n回復預設"
                            settingGiveMoney.reverseAll = true
                        }
                    }
                }
                if s.willGiveMoney != sCopy.willGiveMoney {
                    settingGiveMoney.giveOnly = true
                    if let changedCopy = simSettingChangedCopy {
                        if s.willGiveMoney == changedCopy.willGiveMoney && sCopy.id != stock.simId {
                            settingMessage += (s.willGiveMoney ? "\n自動2次加碼" : "\n取消自動加碼")
                            settingGiveMoney.giveAll = true
                        }
                    }
                }
                if s.dateStart != sCopy.dateStart {
                    settingDate.startOnly = true
                    if let changedCopy = simSettingChangedCopy {
                        if s.dateStart == changedCopy.dateStart && changedCopy.id != stock.simId {
                            settingDate.allStart = true
                            settingMessage += "\n起日＝ " + twDateTime.stringFromDate(changedCopy.dateStart)
                        }
                    }
                }
                if s.dateEnd != sCopy.dateEnd || s.dateEndSwitch != sCopy.dateEndSwitch {
                    settingDate.endOnly = true
                    if let changedCopy = simSettingChangedCopy {
                        if (s.dateEndSwitch != sCopy.dateEndSwitch && s.dateEndSwitch == changedCopy.dateEndSwitch) || (s.dateEnd != sCopy.dateEnd && s.dateEnd == changedCopy.dateEnd) && changedCopy.id != stock.simId {
                            if s.dateEndSwitch {
                                settingDate.allEnd = true
                                settingDate.allSwitch = true
                                settingMessage += "\n迄日＝ " + twDateTime.stringFromDate(changedCopy.dateEnd)
                            } else {
                                settingDate.allSwitch = true
                                settingMessage += "\n不指定迄日"
                            }
                        }
                    }
                }
                if s.initMoney != sCopy.initMoney {
                    settingInitMoney.selfOnly = true
                    if let changedCopy = simSettingChangedCopy {
                        if s.initMoney == changedCopy.initMoney && changedCopy.id != stock.simId {
                            settingInitMoney.all = true
                            settingMessage += "\n本金＝ " + String(format: "%.f萬元",changedCopy.initMoney)
                        }
                    }
                }
            }




            func changeSetting (changeAll:Bool=false) {
                if changeAll {
                    for (id,_) in self.stock.sortedStocks {
                        if let changedCopy = simSettingChangedCopy {
                            if id != changedCopy.id {
                                if id != self.stock.simId {
                                    if settingGiveMoney.reverseAll {
                                        self.stock.simPrices[id]!.resetToDefault()
                                    }
                                    if settingGiveMoney.giveAll {
                                        self.stock.simPrices[id]!.willGiveMoney   = self.stock.simPrices[self.stock.simId]!.willGiveMoney
                                        self.stock.simPrices[id]!.willResetMoney  = self.stock.simPrices[self.stock.simId]!.willResetMoney
                                    }
                                    if settingDate.allStart {
                                        self.stock.simPrices[id]!.dateStart       = self.stock.simPrices[self.stock.simId]!.dateStart
                                        self.stock.simPrices[id]!.dateEarlier     = self.stock.simPrices[self.stock.simId]!.dateEarlier
                                        self.stock.simPrices[id]!.willResetMoney  = true
                                        self.stock.simPrices[id]!.twseTask        = [:]
                                        self.stock.simPrices[id]!.cnyesTask       = [:]
                                    }
                                    if settingDate.allSwitch {
                                        self.stock.simPrices[id]!.dateEndSwitch   = self.stock.simPrices[self.stock.simId]!.dateEndSwitch
                                        if self.stock.simPrices[id]!.dateEndSwitch == false {
                                            self.stock.simPrices[id]!.dateEnd         = self.stock.simPrices[self.stock.simId]!.dateEnd
                                        }
                                    }
                                    if settingDate.allEnd {
                                        self.stock.simPrices[id]!.dateEnd         = self.stock.simPrices[self.stock.simId]!.dateEnd
                                    }
                                    if settingInitMoney.all && id != "t00" {
                                        self.stock.simPrices[id]!.initMoney       = self.stock.simPrices[self.stock.simId]!.initMoney
                                        self.stock.simPrices[id]!.willResetMoney = true

                                    }
                                } else if settingDate.startOnly {   //自己有改起日，也要重算加碼
                                    self.stock.simPrices[id]!.willResetMoney = true
                                }   //if id != self.stock.simId
                                self.stock.simPrices[id]!.willUpdateAllSim = true
                            }   //if id != changedCopy.id
                        }   //if let changedCopy = simSettingChangedCopy
                    }   //for id in self.stock.simPrices.keys

                    if settingGiveMoney.reverseAll {  //全部的股都改預設時，恢復起始本金和年數
                        self.defaults.set(self.stock.defaultMoney, forKey: "defaultMoney")
                        self.defaults.set(self.stock.defaultYears, forKey: "defaultYears")
                    }
                    if settingInitMoney.all {    //全部的股都變更起始本金時，也要變更預設的起始本金
                        self.nsLog("set defaultMoney=\(self.stock.simPrices[self.stock.simId]!.initMoney)")
                        self.defaults.set(self.stock.simPrices[self.stock.simId]!.initMoney, forKey: "defaultMoney")
                    }
                    if settingDate.allStart || settingDate.allEnd {
                        if let start = twDateTime.calendar.ordinality(of: .day, in: .era, for: self.stock.simPrices[self.stock.simId]!.dateStart) {
                            var endDate:Date = Date()
                            if self.stock.simPrices[self.stock.simId]!.dateEndSwitch {
                                endDate = self.stock.simPrices[self.stock.simId]!.dateEnd
                            }
                            if let end = twDateTime.calendar.ordinality(of: .day, in: .era, for: endDate) {
                                let years = Int(round(Float(end - start) / 365.4))
                                if years > 1 {
                                    self.nsLog("set defaultYears=\(years)")
                                    self.defaults.set(years, forKey: "defaultYears")
                                }
                            }
                        }
                    }

                    if !self.stock.simTesting {
                        self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
                    }
                    self.stock.setupPriceTimer()    //(mode: "all")

                } else {    //if changeAll {
                    if settingDate.startOnly {
                        self.stock.simPrices[self.stock.simId]!.twseTask    = [:]
                        self.stock.simPrices[self.stock.simId]!.cnyesTask   = [:]
                    }
                    if settingDate.startOnly || settingInitMoney.selfOnly { 
                        self.stock.simPrices[self.stock.simId]!.willResetMoney = true
                    }
                    self.initSummary()
                    self.stock.simPrices[self.stock.simId]!.willUpdateAllSim = true
                    self.stock.setupPriceTimer(self.stock.simId, mode: "all")

                }   //if changeAll {

            }


            if (settingGiveMoney.reverseAll || settingDate.allStart || settingDate.allEnd || settingDate.allSwitch || settingInitMoney.all || settingGiveMoney.giveAll || settingGiveMoney.resetAll) && stock.sortedStocks.count > 2 {
                let textMessage = "將以下設定套用到其他股票？\n" + settingMessage
                let alert = UIAlertController(title: "全部套用", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "不用", style: .cancel, handler: { action in
                    changeSetting(changeAll: false)
                    self.simSettingChangedCopy = nil

                }))
                alert.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
                    changeSetting(changeAll: true)
                    self.simSettingChangedCopy = nil

                }))
                self.present(alert, animated: true, completion: nil)

            } else if settingDate.startOnly || settingDate.endOnly || settingInitMoney.selfOnly || settingGiveMoney.resetOnly || settingGiveMoney.reverseOnly  || settingGiveMoney.giveOnly {
                //若非如上條件就是都沒變
                changeSetting(changeAll: false)
                if let sim = stock.simPrices[stock.simId] {
                    self.simSettingChangedCopy = self.stock.copySimPrice(sim)
                    Timer.scheduledTimer(withTimeInterval: 5*60, repeats: false, block: {_ in
                        self.simSettingChangedCopy  = nil
                    })
                }
            }
            simPriceCopy = nil
        } else {    //股票名稱滾輪關閉之後
            if self.simIdCopy != stock.simId {
                showPrice(stock.simId)
                self.simIdCopy = nil
            }
        }   //if let sCopy = simPriceCopy
    }




}


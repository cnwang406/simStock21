//
//  simStockPageView.swift
//  simStock21
//
//  Created by peiyu on 2020/6/28.
//  Copyright © 2020 peiyu. All rights reserved.
//

import SwiftUI

struct stockPageView: View {
    @State var list: simStockList
    @State var stock : Stock
    @State var prefix: String
    
    var body: some View {
        VStack (alignment: .center) {
            tradeListView(list: self.list, stock: self.stock, selected: (stock.trades.count > 0 ? stock.trades[0].date : nil))
            Spacer()
            stockPicker(list: self.list, prefix: self.$prefix, stock: self.$stock)
        }
            .navigationBarItems(trailing:
                HStack {
                    prefixPicker(list: self.list, prefix: self.$prefix, stock: self.$stock)
                }
            )
    }
}

func pickerIndexRange(index:Int, count:Int, max: Int) -> (from:Int, to:Int) {
    var from:Int = 0
    var to:Int = count - 1
    let center:Int = (max - 1) / 2
    
    if count > max {
        if index <= center {
            from = 0
            to = max - 1
        } else if index >= (count - center) {
            from = count - max
            to = count - 1
        } else {
            from = index - center
            to = index + center
        }
    }
    
    return(from,to)
}

struct prefixPicker: View {
    @State var list: simStockList
    @Binding var prefix: String
    @Binding var stock : Stock

    var prefixs:[String] {
            let prefixs = list.prefixs
            let prefixIndex = prefixs.firstIndex(of: prefix) ?? 0
        let maxCount = (list.widthClass == .widePad ? 33 : (list.widthClass == .compact ? 7 : (list.widthClass == .widePhone ? 15 : 17)))
            let index = pickerIndexRange(index: prefixIndex, count: prefixs.count, max: maxCount)
            return Array(prefixs[index.from...index.to])
    }

    var body: some View {
        HStack {
            if self.prefixs.first == list.prefixs.first {
                Text("|").foregroundColor(.gray).fixedSize()
            } else {
                Text("-").foregroundColor(.gray).fixedSize()
            }
            Picker("", selection: $prefix) {
                ForEach(self.prefixs, id:\.self) {prefix in
                    Text(prefix).tag(prefix)
                }
            }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                .fixedSize()
                .onReceive([self.prefix].publisher.first()) { value in
                    if self.stock.prefix != self.prefix {
                        self.stock = self.list.prefixStocks(prefix: value)[0]
                    }
                }
            if self.prefixs.last == list.prefixs.last {
                Text("|").foregroundColor(.gray).fixedSize()
            } else {
                Text("-").foregroundColor(.gray).fixedSize()
            }
        }
    }
}

struct stockPicker: View {
    @State var list: simStockList
    @Binding var prefix:String
    @Binding var stock :Stock
    
    var prefixStocks:[Stock] {
        let stocks = list.prefixStocks(prefix: self.prefix)
        let stockIndex = stocks.firstIndex(of: self.stock) ?? 0
        let maxCount = (list.widthClass == .widePad ? 13 : (list.widthClass == .compact ? 3 : 7))
        let index = pickerIndexRange(index: stockIndex, count: stocks.count, max: maxCount)
        return Array(stocks[index.from...index.to])
    }

    var body: some View {
        VStack (alignment: .center) {
            if self.prefixStocks.count > 1 {
                HStack {
                    if self.prefixStocks.first == list.prefixStocks(prefix: self.prefix).first {
                        Text("|").foregroundColor(.gray).fixedSize()
                    } else {
                        Text("-").foregroundColor(.gray)
                    }
                    Picker("", selection: $stock) {
                        ForEach(self.prefixStocks, id:\.self.sId) { stock in
                             Text(stock.sName).tag(stock)
                        }
                    }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .fixedSize()
                    if self.prefixStocks.last == list.prefixStocks(prefix: self.prefix).last {
                        Text("|").foregroundColor(.gray).fixedSize()
                    } else {
                        Text("-").foregroundColor(.gray).fixedSize()
                    }
                }
            }
		}
    }
    
}


struct tradeListView: View {
    @ObservedObject var list: simStockList
    @ObservedObject var stock : Stock
    @State var selected: Date?
    @State var showReload:Bool = false
    @State var showSetting: Bool = false
    @State var showInformation:Bool = false
        
    var simSummary: (profit:String, roi:String, days:String) {
        if stock.trades.count == 0 {
            return ("","","尚無模擬交易")
        } else {
            let trade = stock.trades[0]
            if trade.rollDays == 0 || trade.rollRounds == 0 {
                return ("","","尚無模擬交易")
            } else {
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .currency   //貨幣格式
                numberFormatter.maximumFractionDigits = 0
                let rollAmtProfit = "累計損益" + (numberFormatter.string(for: trade.rollAmtProfit) ?? "$0")
                let rollAmtRoi = String(format:"年報酬率%.1f%%",trade.rollAmtRoi/stock.years)
                let rollDays = String(format:"平均週期%.f天",trade.rollDays/trade.rollRounds)
                return (rollAmtProfit,rollAmtRoi,rollDays)
            }
        }
    }

    func openUrl(_ url:String) {
        if let URL = URL(string: url) {
            if UIApplication.shared.canOpenURL(URL) {
                UIApplication.shared.open(URL, options:[:], completionHandler: nil)
            }
        }
    }
    
    //== 表頭：股票名稱、模擬摘要 ==
    var body: some View {
        VStack(alignment: .leading) {
            Group {
                HStack(alignment: .top) {
                    Group {
                        Text(stock.sId)
                        Text(stock.sName)
                    }
                        .foregroundColor(list.requestRunning ? .gray : .primary)
                    Spacer(minLength: 40)
                    HStack {
                        //== 工具按鈕 1 ==
                        Button(action: {self.showSetting = true}) {
                            Image(systemName: "wrench")
                        }
                            .sheet(isPresented: $showSetting) {
                                settingForm(list: self.list, stock: self.stock, showSetting: self.$showSetting, dateStart: self.stock.dateStart, moneyBase: self.stock.simMoneyBase, addInvest: self.stock.simAddInvest)
                            }
                        //== 工具按鈕 2 ==
                        Spacer()
                        Button(action: {self.showReload = true}) {
                            Image(systemName: "arrow.clockwise")
                        }
                            .actionSheet(isPresented: $showReload) {
                                ActionSheet(title: Text("立即更新"), message: Text("刪除或重算？"), buttons: [
                                    .default(Text("重算模擬")) {
                                        self.list.reloadNow([self.stock], action: .simResetAll)
                                    },
                                    .default(Text("重算技術數值")) {
                                        self.list.reloadNow([self.stock], action: .tUpdateAll)
                                    },
                                    .default(Text("刪除最後1個月")) {
                                        self.list.deleteTrades([self.stock], oneMonth: true)
                                    },
                                    .destructive(Text("沒事，不用了。"))
                                ])
                            }
                        //== 工具按鈕 3 ==
                        Spacer()
                        Button(action: {self.showInformation = true}) {
                            Image(systemName: "questionmark.circle")
                        }
                            .actionSheet(isPresented: $showInformation) {
                                ActionSheet(title: Text("參考訊息"), message: Text("小確幸v\(list.versionNow)"),
                                buttons: [
                                    .default(Text("小確幸網站")) {
                                        self.openUrl("https://peiyu66.github.io/simStock21/")
                                    },
                                    .default(Text("Yahoo! 技術分析")) {
                                        self.openUrl("https://tw.stock.yahoo.com/q/ta?s=" + self.stock.sId)
                                    },
                                    .destructive(Text("沒事，不用了。"))
                                ])
                            }

                    } //工具按鈕的HStack
                        .frame(width: 100, alignment: .trailing)
                        .font(.body)


                }
                .font(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding()
            
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Spacer()
                        Text(String(format:"期間%.1f年", stock.years))
                        Text(stock.simMoneyBase > 0 ? String(format:"起始本金%.f萬元",stock.simMoneyBase) : "")
                        Text(stock.simAddInvest ? "自動2次加碼" : "不自動加碼")
                            .foregroundColor(stock.simAddInvest ? .primary : .red)
                    }
    //                    .lineLimit(1)
    //                    .minimumScaleFactor(0.6)
    //                    .padding(.trailing)
                    HStack {
                        Spacer()
                        Text(simSummary.profit)
                        Text(simSummary.roi)
                        Text(simSummary.days)
                    }
                    
                }
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.trailing)
            }   //Group （表頭）


            //== 日交易明細列表 ==
            List {
                ForEach(stock.trades, id:\.self.dateTime) { trade in
                    tradeCell(list: self.list, stock: self.stock, trade: trade, selected: self.$selected)
                        .onTapGesture {
                            if self.selected == trade.date {
                                self.selected = nil
                            } else {
                                self.selected = trade.date
                            }
                        }
//                        .onAppear { print(trade.date, "show") }
//                        .onDisappear { print(trade.date, "out") }
                }
            }
            .id(UUID())
            .listStyle(GroupedListStyle())
            Spacer()
            
        }
    }
}

struct settingForm: View {
    @State var list: simStockList
    @ObservedObject var stock:Stock
    @Binding var showSetting: Bool
    @State var dateStart:Date
    @State var moneyBase:Double
    @State var addInvest:Bool
    @State var applyToGroup:Bool = false
    @State var applyToAll:Bool = false
    @State var saveToDefaults:Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("\(stock.sId)\(stock.sName)的設定").font(.title)) {
                    DatePicker(selection: $dateStart, in: (twDateTime.calendar.date(byAdding: .year, value: -15, to: Date()) ?? stock.dateFirst)...(twDateTime.calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()), displayedComponents: .date) {
                        Text("起始日期")
                    }
                    .environment(\.locale, Locale(identifier: "zh_Hant_TW"))
                    HStack {
                        Text(String(format:"起始本金%.f萬元",self.moneyBase))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 180, alignment: .leading)
                        Slider(value: $moneyBase, in: 10...1000, step: 10)
                    }
                    Toggle("自動2次加碼", isOn: $addInvest)
                }
                Section(header: Text("擴大設定範圍").font(.title),footer: Text(self.list.simDefaults).font(.footnote)) {
                    Toggle("套用到全部股", isOn: $applyToAll)
                    .onReceive([self.applyToAll].publisher.first()) { (value) in
                        self.applyToGroup = value
                    }
                    Toggle("套用到同股群", isOn: $applyToGroup)
                        .disabled(self.applyToAll)
                    Toggle("作為新股預設值", isOn: $saveToDefaults)
                }

            }
            .navigationBarTitle("模擬設定")
            .navigationBarItems(leading: cancel, trailing: done)

        }
            .navigationViewStyle(StackNavigationViewStyle())
    }
    
    var cancel: some View {
        Button("取消") {
            self.showSetting = false
        }
    }
    var done: some View {
        Button("確認") {
            DispatchQueue.global().async {
                self.list.applySetting(self.stock, dateStart: self.dateStart, moneyBase: self.moneyBase, addInvest: self.addInvest, applyToGroup: self.applyToGroup, applyToAll: self.applyToAll, saveToDefaults: self.saveToDefaults)
            }
            self.showSetting = false
        }
    }
    

    
}


struct tradeCell: View {
    @State var list: simStockList
    @State var stock: Stock
    @ObservedObject var trade:Trade
    @Binding var selected: Date?
    
    func textSize(textStyle: UIFont.TextStyle) -> CGFloat {
       return UIFont.preferredFont(forTextStyle: textStyle).pointSize
    }
    
    var simSummary: some View {
        Group {
            if trade.simRule != "_" {
                VStack(alignment: .leading,spacing: 2) {
                    Text("本金餘額")
                    if trade.simDays > 0 {
                        Text("本輪損益")
                    }
                    Text("累計損益")
                }
                .font(.custom("Courier", size: textSize(textStyle: .footnote)))
                VStack(alignment: .trailing,spacing: 2) {
                    Text(String(format:"%.f萬元",trade.simAmtBalance/10000))
                    if trade.simDays > 0 {
                        Text(String(format:"%.f仟元",trade.simAmtProfit/1000))
                    }
                    Text(String(format:"%.f仟元",trade.rollAmtProfit/1000))
                }
                Spacer()
                VStack(alignment: .leading,spacing: 2) {
                    if trade.simDays > 0 {
                        Text("單位成本")
                        Text("本輪成本")
                    } else {
                        Text("")
                    }
                    Text("單輪成本")
                }
                .font(.custom("Courier", size: textSize(textStyle: .footnote)))
                VStack(alignment: .trailing,spacing: 2) {
                    if trade.simDays > 0 {
                        Text(String(format:"%.2f元",trade.simUnitCost))
                        Text(String(format:"%.1f萬元",trade.simAmtCost/10000))
                    } else {
                        Text("")
                    }
                    Text(String(format:"%.1f萬元",trade.rollAmtCost/10000))
                }
                .frame(minWidth: 55)
                Spacer()
                VStack(alignment: .leading,spacing: 2) {
                    if trade.simDays > 0 {
                        Text(String(format:"第%.f輪" + (trade.rollRounds > 10 ? "" : " ") + trade.simRuleBuy,trade.rollRounds))
                        Text("本輪報酬")
                    } else {
                        Text("")
                    }
                    Text("累計報酬")
                }
                    .font(.custom("Courier", size: textSize(textStyle: .footnote)))
                VStack(alignment: .trailing,spacing: 2) {
                    if trade.simDays > 0 {
                        Text(String(format:"平均%.f天",trade.days))
                        Text(String(format:"%.1f%%",trade.simAmtRoi))
                    } else {
                        Text("")
                    }
                    Text(String(format:"%.1f%%",trade.rollAmtRoi))
                }
                Spacer()
            } else {   //if trade.simRule != "_"
                EmptyView()
            }
        }
        .font(.custom("Courier", size: textSize(textStyle: .footnote)))

    }
    
    func p10Text(p10:(price:Double,action:String,qty:Double,roi:Double)) -> String {
        var text:String = String(format:"%.2f",p10.price)
        if p10.action == "買" {
            text += p10.action + String(format:"%.f",p10.qty)
        } else {
            text += p10.action + String(format:"%.1f%%",p10.roi)
        }
        return text
    }
    
    var priceAndKDJ: some View {
        Group {
            VStack(alignment: .leading,spacing: 2) {
                Text("開盤")
                Text("最高")
                Text("最低")
            }
            VStack(alignment: .trailing,spacing: 2) {
                Text(String(format:"%.2f",trade.priceOpen))
                Text(String(format:"%.2f",trade.priceHigh))
                Text(String(format:"%.2f",trade.priceLow))
            }
            .frame(minWidth: 55 , alignment: .trailing)
            Spacer()
            VStack(alignment: .leading,spacing: 2) {
                Text(twDateTime.inMarketingTime(trade.dateTime) ? "成交" : "收盤")
                    .foregroundColor(trade.color(.time))
                Text("MA20")
                Text("MA60")
            }
            VStack(alignment: .trailing,spacing: 2) {
                Text(String(format:"%.2f",trade.priceClose))
                    .foregroundColor(trade.color(.time))
                Text(String(format:"%.2f",trade.tMa20))
                Text(String(format:"%.2f",trade.tMa60))
            }
            .frame(minWidth: 55 , alignment: .trailing)
            Spacer()
        }
        .font(.custom("Courier", size: textSize(textStyle: .callout)))
    }
    
    
    
     var body: some View {
        VStack(alignment: .leading) {
            HStack {
                //== 1反轉 ==
                Group {
                    if trade.simRule != "_" {
                        Image(systemName: trade.simReversed == "" ? "circle" : "circle.fill")
                            .foregroundColor(.blue)
                            .onTapGesture {
                                self.list.setReversed(self.trade)
                            }
                    } else {
                        Text("")
                    }
                }
                .frame(width: 20, alignment: .center)
                //== 2日期,3單價 ==
                Text(twDateTime.stringFromDate(trade.dateTime))
                    .foregroundColor(trade.color(.time))
                    .frame(width: (list.widthClass == .compact ? 80.0 : 128.0), alignment: .leading)
                Text(String(format:"%.2f",trade.priceClose))
                    .frame(width: (list.widthClass == .compact ? 64.0 : 104.0), alignment: .center)
                    .foregroundColor(trade.color(.ruleF))
                    .background(RoundedRectangle(cornerRadius: 20).fill(trade.color(.ruleB)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(trade.color(.ruleR), lineWidth: 1)
                    )

                //== 4買賣,5數量 ==
                Text(trade.simQty.action)
                    .frame(width: (list.widthClass == .compact ? 16.0 : 24.0), alignment: .center)
                    .foregroundColor(trade.color(.qty))
                Text(trade.simQty.qty > 0 ? String(format:"%.f",trade.simQty.qty) : "")
                    .frame(width: (list.widthClass == .compact ? 32.0 : 56.0), alignment: .center)
                    .foregroundColor(trade.color(.qty))
                //== 6天數,7成本價,8報酬率 ==
                if trade.simQtyInventory > 0 || trade.simQtySell > 0 {
                    Text(String(format:"%.f天",trade.simDays))
                        .frame(width: (list.widthClass == .compact ? 40.0 : 56.0), alignment: .trailing)
                    if self.list.widthClass != .compact {
                        Text(String(format:"%.2f",trade.simUnitCost))
                            .frame(width: 56.0, alignment: .trailing)
                            .foregroundColor(.gray)
                            .font(.callout)
                    }
                    if self.list.widthClass != .compact || trade.simQtySell > 0 {
                        Text(String(format:"%.1f%%",trade.simAmtRoi))
                            .frame(width: (list.widthClass == .compact ? 40.0 : 56.0), alignment: .trailing)
                            .foregroundColor(trade.simQtySell > 0 ? trade.color(.qty) : .gray)
                            .font(trade.simQtySell > 0 ? .body : .callout)
                    }
                } else {
                    EmptyView()
                }
                //== 9加碼 ==
//                if trade.simQtySell > 0 {
//                    Text(String(format:"%.2f",trade.simUnitCost))
//                    .frame(width: (list.widthClass == .compact ? 40.0 : 64.0), alignment: .trailing)
//                    Text(String(format:"%.1f%%",trade.simAmtRoi))
//                        .frame(width: (list.widthClass == .compact ? 40.0 : 64.0), alignment: .trailing)
//                } else
                if trade.simRuleInvest == "A" {
                    Text((trade.invested > 0 ? "已加碼" + (list.widthClass != .compact ? String(format:"(%.f)",trade.simInvestTimes - 1) : "") : "請加碼") + (trade.simInvestByUser > 0 ? "+" : (trade.simInvestByUser < 0 ? "-" : " ")))
                        .foregroundColor(.blue)
                        .font(.callout)
                        .frame(width: (list.widthClass == .compact ? 40.0 : 88.0), alignment: .leading)
                        .onTapGesture {
                            self.list.addInvest(self.trade)
                        }
                } else {
                    EmptyView()
                }
            }   //HStack
                .font(.body)
            if self.selected == trade.date {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("").frame(width: 20.0, alignment: .center)
                            Text(twDateTime.stringFromDate(trade.dateTime, format: "EEE HH:mm:ss"))
                            .frame(width: (list.widthClass == .compact ? 80.0 : 128.0), alignment: .leading)
                        }
                        HStack {
                            Text("").frame(width: 20.0, alignment: .center)
                            Text(trade.tSource)
                            .frame(width: (list.widthClass == .compact ? 80.0 : 128.0), alignment: .leading)
                        }
                    }
                        .font(.caption)
                        .foregroundColor(trade.color(.time))
                    //== 五檔價格試算建議 ==
                    VStack(alignment: .leading, spacing: 2) {
                        if trade.date == stock.p10.date {
                            HStack {
                                ForEach(self.stock.p10.L.indices, id:\.self) { i in
                                    Group {
                                        if i > 0 {
                                            Divider()
                                        }
                                        Text(self.p10Text(p10: self.stock.p10.L[i]))
                                    }
                                }
                            }
                            HStack {
                                ForEach(self.stock.p10.H.indices, id:\.self) { i in
                                    Group {
                                        if i > 0 {
                                            Divider()
                                        }
                                        Text(self.p10Text(p10: self.stock.p10.H[i]))
                                    }
                                }
                            }
                        }
                    }
                        .font(.custom("Courier", size: textSize(textStyle: .footnote)))
                        .foregroundColor(trade.color(.ruleB))
                }
                Spacer()
                //== 單價和模擬摘要 ==
                if list.widthClass == .compact {
                    VStack {
                        HStack {
                            Text("").frame(width: 20.0, alignment: .center)
                            self.priceAndKDJ
                        }
                        Spacer()
                        HStack {
                            Text("").frame(width: 20.0, alignment: .center)
                            self.simSummary
                        }
                    }
                } else {
                    HStack (alignment: .center) {
                        Text("").frame(width: 20.0, alignment: .center)
                        self.priceAndKDJ
//                        Spacer()
                        self.simSummary
                    }
                }
                Spacer()    //以下是擴充技術數值
                if list.widthClass != .compact {
                    HStack {
                        Text("").frame(width: 20.0, alignment: .center)
                        Group {
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("")
                                Text("value")
                                Text("max9")
                                .foregroundColor(trade.tMa20DiffMax9 == trade.tMa20Diff || trade.tMa60DiffMax9 == trade.tMa60Diff || trade.tOscMax9 == trade.tOsc || trade.tKdKMax9 == trade.tKdK ? .red : .primary)
                                Text("min9")
                                .foregroundColor(trade.tMa20DiffMin9 == trade.tMa20Diff || trade.tMa60DiffMin9 == trade.tMa60Diff || trade.tOscMin9 == trade.tOsc || trade.tKdKMin9 == trade.tKdK ? .red : .primary)
                                Text("z125")
                                Text("z250")
                                Text("z375")
                            }
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("ma20x")
                                Text(String(format:"%.2f",trade.tMa20Diff))
                                Text(String(format:"%.2f",trade.tMa20DiffMax9))
                                    .foregroundColor(trade.tMa20DiffMax9 == trade.tMa20Diff ? .red : .primary)
                                Text(String(format:"%.2f",trade.tMa20DiffMin9))
                                    .foregroundColor(trade.tMa20DiffMin9 == trade.tMa20Diff ? .red : .primary)
                                Text(String(format:"%.2f",trade.tMa20DiffZ125))
                                Text(String(format:"%.2f",trade.tMa20DiffZ250))
                                Text(String(format:"%.2f",trade.tMa20DiffZ375))
                            }
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("ma60x")
                                Text(String(format:"%.2f",trade.tMa60Diff))
                                Text(String(format:"%.2f",trade.tMa60DiffMax9))
                                .foregroundColor(trade.tMa60DiffMax9 == trade.tMa60Diff ? .red : .primary)
                                Text(String(format:"%.2f",trade.tMa60DiffMin9))
                                .foregroundColor(trade.tMa60DiffMin9 == trade.tMa60Diff ? .red : .primary)
                                Text(String(format:"%.2f",trade.tMa60DiffZ125))
                                Text(String(format:"%.2f",trade.tMa60DiffZ250))
                                Text(String(format:"%.2f",trade.tMa60DiffZ375))
                            }
                        }
                        Group {
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("osc")
                                Text(String(format:"%.2f",trade.tOsc))
                                Text(String(format:"%.2f",trade.tOscMax9))
                                .foregroundColor(trade.tOscMax9 == trade.tOsc ? .red : .primary)
                                Text(String(format:"%.2f",trade.tOscMin9))
                                .foregroundColor(trade.tOscMin9 == trade.tOsc ? .red : .primary)
                                Text(String(format:"%.2f",trade.tOscZ125))
                                Text(String(format:"%.2f",trade.tOscZ250))
                                Text(String(format:"%.2f",trade.tOscZ375))
                            }
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("k")
                                Text(String(format:"%.2f",trade.tKdK))
                                Text(String(format:"%.2f",trade.tKdKMax9))
                                .foregroundColor(trade.tKdKMax9 == trade.tKdK ? .red : .primary)
                                Text(String(format:"%.2f",trade.tKdKMin9))
                                .foregroundColor(trade.tKdKMin9 == trade.tKdK ? .red : .primary)
                                Text(String(format:"%.2f",trade.tKdKZ125))
                                Text(String(format:"%.2f",trade.tKdKZ250))
                                Text(String(format:"%.2f",trade.tKdKZ375))
                            }
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("d")
                                Text(String(format:"%.2f",trade.tKdD))
                                Text("-")
                                Text("-")
                                Text(String(format:"%.2f",trade.tKdDZ125))
                                Text(String(format:"%.2f",trade.tKdDZ250))
                                Text(String(format:"%.2f",trade.tKdDZ375))
                            }
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("j")
                                Text(String(format:"%.2f",trade.tKdJ))
                                Text("-")
                                Text("-")
                                Text(String(format:"%.2f",trade.tKdJZ125))
                                Text(String(format:"%.2f",trade.tKdJZ250))
                                Text(String(format:"%.2f",trade.tKdJZ375))
                            }
                        }
                        Spacer()
                        Group {
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("high")
                                Text(String(format:"%.2f",trade.tHighDiff))
                                Text("-")
                                Text("-")
                                Text(String(format:"%.2f",trade.tHighDiff125))
                                Text(String(format:"%.2f",trade.tHighDiff250))
                                Text(String(format:"%.2f",trade.tHighDiff375))
                            }
                            Spacer()
                            VStack(alignment: .trailing,spacing: 2) {
                                Text("low")
                                Text(String(format:"%.2f",trade.tLowDiff))
                                Text("-")
                                Text("-")
                                Text(String(format:"%.2f",trade.tLowDiff125))
                                Text(String(format:"%.2f",trade.tLowDiff250))
                                Text(String(format:"%.2f",trade.tLowDiff375))
                            }
                        }
                        Spacer()
                    }   //HStack
                        .font(.custom("Courier", size: textSize(textStyle: .footnote)))
                }
            }   //If
        }   //VStack
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

}

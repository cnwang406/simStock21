//
//  simStockListView.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import SwiftUI

struct simStockListView: View {
    
    @ObservedObject var list: simStockList
        
    var body: some View {
        NavigationView {
            VStack (alignment: .leading) {
                Spacer()
                SearchBar(editText: self.$searchText, searchText: $list.searchText, isSearching: self.$isSearching)
                    .disabled(self.isChoosing || list.isRunning)
                HStack(alignment: .bottom){
                    if self.isSearching && list.searchText != nil && !self.list.searchGotResults {
                        if list.searchTextInGroup {
                            Text("\(list.searchText?[0] ?? "搜尋的股票")已在股群中。")
                                .foregroundColor(.orange)
                        } else {
                            Text("查無符合者，試以部分的代號或簡稱來查詢？")
                                .foregroundColor(.orange)
                        }
                        Button("[知道了]") {
                            self.searchText = ""
                            self.list.searchText = nil
                            self.isSearching = false
                        }
                    }
                }
                    .font(.footnote)
                    .padding(.horizontal, 20)
                Spacer()
                List{
                    ForEach(list.groupStocks, id: \.self) { (stocks:[Stock]) in
                        stockSection(list: self.list, stocks: stocks, isChoosing: self.$isChoosing, isSeaching: self.$isSearching, checkedStocks: self.$checkedStocks)
                    }
                }
                    .listStyle(GroupedListStyle())
            }
                .navigationBarTitle("", displayMode: .inline)
                .navigationBarItems(leading: choose, trailing: endChoosing)
        }
            .navigationViewStyle(StackNavigationViewStyle())

    }
    
    @State var isChoosing = false           //進入了選取模式
    @State var isSearching:Bool = false     //進入了搜尋模式
    @State var showFilter:Bool = false      //顯示pickerGroups
    @State var checkedStocks: [Stock] = []  //已選取的股票們
    @State var searchText:String = ""       //輸入的搜尋文字
    @State var showExport:Bool = false      //顯示匯出選單
    @State var showShare:Bool = false       //分享代號簡稱
    @State var shareText:String = ""        //要匯出的文字內容
    @State var showMoveAlert:Bool = false
    @State var showReload:Bool = false
    
    func isChoosingOff() {
        self.isChoosing = false
        self.checkedStocks = []
    }
    
    var choose: some View {
//        GeometryReader { geometryProxy in
        HStack {
            if self.isChoosing {
                Text("請勾選")
                    .foregroundColor(Color(.darkGray))
                 Image(systemName: "chevron.right")
                     .foregroundColor(.gray)
                if self.checkedStocks.count > 0 {
                    Button((self.list.widthClass != .compact ? "自股群" : "") + "移除") {
                        self.showMoveAlert = true
                    }
                    .alert(isPresented: self.$showMoveAlert) {
                            Alert(title: Text("自股群移除"), message: Text("確認要移除？"), primaryButton: .default(Text("移除"), action: {
                                self.list.moveStocks(self.checkedStocks)
                                self.isChoosingOff()
                            }), secondaryButton: .default(Text("取消"), action: {self.isChoosingOff()}))
                        }
                    Divider()
                    Button("加入" + (self.list.widthClass != .compact ? "股群" : "")) {
                        self.showFilter = true
                    }
                    .sheet(isPresented: self.$showFilter) {
                            pickerGroups(list: self.list, checkedStocks: self.$checkedStocks, isMoving: self.$isChoosing, isPresented: self.$showFilter, searchText: self.$searchText)
                        }
                    Divider()
                    Button((self.list.widthClass != .compact ? "刪除或" : "") + "重算") {
                        self.showReload = true
                    }
                    .actionSheet(isPresented: self.$showReload) {
                            ActionSheet(title: Text("刪除或重算"), message: Text("內容和範圍？"), buttons: [
                                .default(Text("重算模擬")) {
                                    self.list.reloadNow(self.checkedStocks, action: .simResetAll)
                                    self.isChoosingOff()
                                },
                                .default(Text("重算技術數值")) {
                                    self.list.reloadNow(self.checkedStocks, action: .tUpdateAll)
                                    self.isChoosingOff()
                                },
                                .default(Text("刪除最後1個月")) {
                                    self.list.deleteTrades(self.checkedStocks, oneMonth: true)
                                    self.isChoosingOff()
                                },
                                .destructive(Text("沒事，不用了。")) {
                                    self.isChoosingOff()
                                }
                            ])
                        }
                    Divider()
                    Button("匯出" + (self.list.widthClass != .compact ? "CSV" : "")) {
                        self.showExport = true
                    }
                    .actionSheet(isPresented: self.$showExport) {
                            ActionSheet(title: Text("匯出"), message: Text("文字內容？"), buttons: [
                                .default(Text("代號和名稱")) {
                                    self.shareText = self.list.csvStocksIdName(self.checkedStocks)
                                    self.showShare = true
                                },
                                .destructive(Text("沒事，不用了。")) {
                                    self.isChoosingOff()
                                }
                            ])
                        }
                        .sheet(isPresented: self.$showShare) {   //分享窗
                            ShareSheet(activityItems: [self.shareText]) { (activity, success, items, error) in
                                self.isChoosingOff()
                            }
                        }
                } else {
                    Button("全選") {
                        for stocks in self.list.groupStocks {
                            for stock in stocks {
                                self.checkedStocks.append(stock)
                            }
                        }
                    }
                }
                Spacer()
            } else if self.list.searchGotResults {
                Text("請勾選")
                if self.checkedStocks.count > 0 {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                    Button("加入股群") {
                            self.showFilter = true
                    }
                    .sheet(isPresented: self.$showFilter) {
                            pickerGroups(list: self.list, checkedStocks: self.$checkedStocks, isMoving: self.$isSearching, isPresented: self.$showFilter, searchText: self.$searchText)
                        }
                }
            } else if !self.isSearching {
                if list.isRunning {
                    Text(list.runningMsg)
                        .foregroundColor(.orange)
                } else {
                    Button("選取") {
                        self.isChoosing = true
                        self.searchText = ""
                        self.list.searchText = nil
                        self.isSearching = false
                    }
                }
            }
        }
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        .frame(width: (self.list.widthClass == .compact ? 300 : 500) , alignment: .leading)

//        }

    }
    
    var endChoosing: some View {
        HStack {
            if isChoosing {
                Button("取消" + (list.widthClass != .compact ? "選取模式" : "")) {
                    self.isChoosingOff()
                }
            } else if self.list.searchGotResults {
                Button("放棄" + (list.widthClass != .compact ? "搜尋結果" : "")) {
                    self.searchText = ""
                    self.list.searchText = nil
                    self.isSearching = false
                    self.isChoosingOff()
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}



struct pickerGroups:View {
    @ObservedObject var list: simStockList
    @Binding var checkedStocks: [Stock]
    @Binding var isMoving:Bool
    @Binding var isPresented:Bool
    @Binding var searchText:String
    @State   var groupPicked:String = "新增股群"
    @State   var newGroup:String = "股群_"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text((list.widthClass != .compact ? "選取的股票要" : "") + "新增股群或加入既有股群？"), footer: Text(self.groupPicked == "新增股群" ? "加入新增的[\(self.newGroup)]。\n\n" : "加入[\(self.groupPicked)]。")) {
                    Picker("", selection: self.$groupPicked) {
                        Text("新增股群").tag("新增股群")
                        ForEach(self.list.groups, id: \.self) { (gName:String) in
                            Text(gName).tag(gName)
                        }
                    }
                        .labelsHidden()
//                        .pickerStyle(SegmentedPickerStyle())
//                        .fixedSize()
                }
                if self.groupPicked == "新增股群" {
                    Section (header: Text("新的股群名稱：").font(.title)) {
                        TextField("輸入股群名稱", text: self.$newGroup, onEditingChanged: { _ in    //began or end (bool)
                            }, onCommit: {
                            })
                    }
                    .disabled(self.groupPicked != "新增股群")
                }
            }
            .navigationBarTitle("加入股群")
            .navigationBarItems(leading: cancel, trailing: done)

        }
            .navigationViewStyle(StackNavigationViewStyle())
    }
    
    var cancel: some View {
        Button("取消") {
            self.isPresented = false
            self.isMoving = false
            self.searchText = ""
            self.list.searchText = nil
            self.checkedStocks = []            
        }
    }
    var done: some View {
        Group {
            if self.groupPicked != "新增股群" || self.newGroup != "" {
                Button("確認") {
                    let toGroup:String = (self.groupPicked != "新增股群" ? self.groupPicked : self.newGroup)
                    self.list.moveStocks(self.checkedStocks, toGroup: toGroup)
                    self.isPresented = false
                    self.isMoving = false
                    self.searchText = ""
                    self.list.searchText = nil
                    self.checkedStocks = []
                }
            }
        }
    }


}

struct ShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void

    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = [    //標為註解以排除可用的，留下不要的
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
    let callback: Callback

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to do here
    }
    
    static func dismantleUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator) {
    }
}


struct stockSection : View {
    @ObservedObject var list: simStockList
    @State var stocks: [Stock]
    @Binding var isChoosing:Bool
    @Binding var isSeaching:Bool
    @Binding var checkedStocks: [Stock]


    var header:some View {
        HStack {
            if isChoosing {
                checkGroup(checkedStocks: self.$checkedStocks, stocks: self.$stocks)
            }
            Text((stocks[0].group == "" ? "<搜尋結果>" : "[\(stocks[0].group)]"))
                .font(.headline)
        }
    }
    
    var footer:some View {
        Text(list.stocksSummary(stocks))
    }

    var body: some View {
        Section(header: header,footer: footer) {
            ForEach(stocks, id: \.self) {stock in
                stockCell(list: self.list, stock: stock, isChoosing: self.$isChoosing, isSearching: self.$isSeaching, checkedStocks: self.$checkedStocks)
            }
        }
    }
    
}

struct checkGroup: View {
    @State var isChecked:Bool = false
    @Binding var checkedStocks:[Stock]
    @Binding var stocks : [Stock]
    
    
    func checkGroup() {
        self.isChecked = !self.isChecked
        if self.isChecked {
            self.checkedStocks += stocks
        } else {
            self.checkedStocks = self.checkedStocks.filter{!stocks.contains($0)}
        }
    }

    var body: some View {
        Group {
            Button(action: checkGroup) {
                Image(systemName: isChecked ? "checkmark.square" : "square")
            }
        }
    }
}


struct stockCell : View {
    @ObservedObject var list: simStockList
    @ObservedObject var stock : Stock
    @Binding var isChoosing:Bool
    @Binding var isSearching:Bool
    @Binding var checkedStocks:[Stock]
    @State   var prefix:String = ""
    
    func checkStock() {
        if self.checkedStocks.contains(self.stock) {
            self.checkedStocks.removeAll(where: {$0 == stock})
        } else {
            self.checkedStocks.append(stock)
        }
    }
    
    var body: some View {
        HStack {
            if isChoosing || (isSearching && stock.group == "") {
                Button(action: checkStock) {
                    Image(systemName: self.checkedStocks.contains(self.stock) ? "checkmark.square" : "square")
                }
            }
            Group {
                Text(stock.sId)
                    .font(list.widthClass == .compact ? .callout : .body)
                    .frame(width : (list.widthClass == .compact ? 40.0 : 60.0), alignment: .leading)
                Text(stock.sName)
                    .frame(width : (isSearching && stock.group == "" ? 150.0 : (list.widthClass == .compact ? 75.0 : 110.0)), alignment: .leading)
            }
                .foregroundColor(list.isRunning ? .gray : .primary)
            if stock.group != "" {
                Group {
                    if stock.trades.count > 0 {
                        lastTrade(list: self.list, stock: self.stock, trade: stock.trades[0], isChoosing: self.$isChoosing, isSearching: self.$isSearching)
                    } else {
                        EmptyView()
                    }
                }
                if !isChoosing && !isSearching {
                    NavigationLink(destination: stockPageView(list: self.list, stock: stock, prefix: stock.prefix)) {
                        Text("")
                    }
                }
            }
        }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundColor(self.checkedStocks.contains(stock) ? .orange : (isSearching && stock.group != "" ? .gray : .primary))
    }
}

struct lastTrade: View {
    @ObservedObject var list: simStockList
    @ObservedObject var stock : Stock
    @ObservedObject var trade:Trade
    @Binding var isChoosing:Bool
    @Binding var isSearching:Bool
    

    var body: some View {
        HStack{
            Text(String(format:"%.2f",trade.priceClose))
                .frame(width: (list.widthClass == .compact ? 50.0 : 70.0), alignment: .center)
                .foregroundColor(trade.color(.ruleF, gray: (isChoosing || isSearching)))
                .background(RoundedRectangle(cornerRadius: 20).fill(trade.color(.ruleB, gray: (isChoosing || isSearching))))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(trade.color(.ruleR, gray: (isChoosing || isSearching)), lineWidth: 1)
                )
            if list.widthClass != .compact {
                Text(trade.simQty.action)
                .frame(width: 30.0, alignment: .trailing)
                .foregroundColor(trade.color(.qty, gray: (isChoosing || isSearching)))
                Text(trade.simQty.qty > 0 ? String(format:"%.f",trade.simQty.qty) : "")
                .frame(width: (list.widthClass == .compact ? 35.0 : 50.0), alignment: .trailing)
                .foregroundColor(trade.color(.qty, gray: (isChoosing || isSearching)))

            } else {
                EmptyView()
            }
            Text(String(format:"%.1f年",stock.years))
                .frame(width: (list.widthClass == .compact ? 40.0 : 70.0), alignment: .trailing)
            if trade.days > 0 {
                Text(String(format:"%.f天",trade.days))
                    .frame(width: (list.widthClass == .compact ? 35.0 : 70.0), alignment: .trailing)
                Text(String(format:"%.1f%%",trade.rollAmtRoi/stock.years))
                    .frame(width: (list.widthClass == .compact ? 40.0 : 70.0), alignment: .trailing)
            } else {
                EmptyView()
            }
        }
            .font(list.widthClass == .compact ? .footnote : .body)
            .foregroundColor(isChoosing || isSearching ? .gray : .primary)


    }
}




struct SearchBar: View {
    @Binding var editText: String
    @Binding var searchText:[String]?
    @Binding var isSearching:Bool
    @State var isEditing:Bool = false

    //來自： https://www.appcoda.com/swiftui-search-bar/
    var body: some View {
        HStack {
            TextField("以代號或簡稱來搜尋未加入股群的上市股票", text: $editText    /*, onEditingChanged: { editing in
                if !editing {
                    self.isEditing = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)  // Dismiss the keyboard
                }
            } */, onCommit: {
                self.searchText = self.editText.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ").components(separatedBy: " ")
                self.isEditing = false
                self.isSearching = true
            })
                .padding(7)
                .padding(.horizontal, 25)
                .lineLimit(nil)
                .minimumScaleFactor(0.6)
                .background(Color(.systemGray6))
//                .keyboardType(.webSearch)
                .cornerRadius(8)
                .onTapGesture {
                    self.isEditing = true
                    self.isSearching = true
                }
                .overlay(
                   HStack {
                       Image(systemName: "magnifyingglass")
                           .foregroundColor(.gray)
                           .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                           .padding(.leading, 8)
                
                       if isEditing {
                            Button(action: {
                                self.editText = ""
                                self.searchText = nil
                                self.isSearching = false
                           })
                           {
                                Image(systemName: "multiply.circle.fill")
                                   .foregroundColor(.gray)
                                   .padding(.trailing, 8)
                           }
                       }
                   }
                )
                .padding(.horizontal, 10)
            if isEditing && isSearching {
                Button(action: {
                    self.isSearching = false
                    self.isEditing = false
                    self.editText = ""
                    self.searchText = nil
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)  // Dismiss the keyboard
                })
                {
                    Text("取消")
                }
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        simStockListView(list: simStockList())
    }
}

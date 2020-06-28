//
//  simStockListView.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import SwiftUI
import CoreData

struct simStockListView: View {
    
    @ObservedObject var list: simStockList
        
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                SearchBar(text: self.$searchText, searchText: $list.searchText, isSearching: self.$isSearching)
                    .disabled(self.isChoosing)
                HStack(alignment: .bottom){
                    if self.isSearching && list.searchText != nil && !self.list.searchGotResults {
                    Text("未加入股群的股票中查無符合者，試以部分的代號或簡稱來查詢？")
                        .foregroundColor(.orange)
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
                    ForEach(list.groupedStocks, id: \.self) {(stocks:[Stock]) in
                        stockSection(stocks: stocks, isChoosing: self.$isChoosing, isSeaching: self.$isSearching, checkedStocks: self.$checkedStocks)
                    }
                }
                    .listStyle(GroupedListStyle())
            }
            .navigationBarItems(leading: choose, trailing: endChoosing)
        }
        .navigationViewStyle(StackNavigationViewStyle())
 
    }
    
    @State var isChoosing = false   //進入了選取模式
    @State var isSearching:Bool = false     //進入了搜尋模式
    @State var showFilter:Bool = false
    @State var checkedStocks: [Stock] = []  //已選取的股票們
    @State var searchText:String = ""       //輸入的搜尋文字

    
    var choose: some View {
        HStack {
            if isChoosing {
                Text("請勾選")
                    .foregroundColor(Color(.darkGray))
                 if checkedStocks.count > 0 {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                    Button((list.isPad || list.isLandscape ? "自股群" : "") + "移除") {
                        self.list.moveStockToGroup(self.checkedStocks)
                        self.checkedStocks = []
                        self.isChoosing = false
                    }
                    Divider()
                    Button("加入股群") {
                        self.showFilter = true
                    }
                    .sheet(isPresented: $showFilter) {
                        pickerGroups(list: self.list, checkedStocks: self.$checkedStocks, isMoving: self.$isChoosing, isPresented: self.$showFilter, searchText: self.$searchText)
                    }
                }
            } else if self.list.searchGotResults {
                Text("請勾選")
                if checkedStocks.count > 0 {
                    Text(">")
                    Button("加入股群") {
                            self.showFilter = true
                        }
                        .sheet(isPresented: $showFilter) {
                            pickerGroups(list: self.list, checkedStocks: self.$checkedStocks, isMoving: self.$isSearching, isPresented: self.$showFilter, searchText: self.$searchText)
                        }
                }
            } else if !isSearching {
                Button("選取") {
                    self.isChoosing = true
                    // self.searchText = ""
                    // self.list.searchText = nil
                }
            } else {
                Text(String("isSearching:\(self.isSearching)"))
            }
        }
    .fixedSize()
            .frame(width:240.0, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.5)


    }
    
    var endChoosing: some View {
        HStack {
            if isChoosing {
                Button("離開" + (list.isPad || list.isLandscape ? "選取模式" : "")) {
                    self.isChoosing = false
                    self.checkedStocks = []
                }
            } else if self.list.searchGotResults {
                Button("放棄" + (list.isPad || list.isLandscape ? "搜尋結果" : "")) {
                    self.searchText = ""
                    self.list.searchText = nil
                    self.checkedStocks = []
                    self.isSearching = false
                }
            }
        }
        .frame(width:(list.isPad || list.isLandscape ? 100.0 : 50.0), alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}


struct pickerGroups:View {
    @ObservedObject var list: simStockList
    @Binding var checkedStocks: [Stock]
    @Binding var isMoving:Bool
    @Binding var isPresented:Bool
    @Binding var searchText:String
    @State   var groupPicked:String = "新增股群"
    @State   var newGroup:String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("選取的股票要加入哪個股群？")) {
                    Picker("", selection: $groupPicked) {
                        Text("新增股群").tag("新增股群")
                        ForEach(list.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                        .pickerStyle(WheelPickerStyle())
                }
                if groupPicked == "新增股群" {
                    Section (header: Text("加入新增的股群：")) {
                            TextField("輸入股群名稱", text: $newGroup, onEditingChanged: { _ in    //began or end (bool)
                            }, onCommit: {
                            })
                    }
                }
            }
            .navigationBarTitle("加入股群")
            .navigationBarItems(leading: cancel, trailing: done)
        }
    }
    
    var cancel: some View {
        Button("取消") {
            self.isPresented = false
        }
    }
    var done: some View {
        Button("確認") {
            let toGroup:String = (self.groupPicked != "新增股群" ? self.groupPicked : self.newGroup)
            self.list.moveStockToGroup(self.checkedStocks, group: toGroup)
            self.isPresented = false
            self.isMoving = false
            self.searchText = ""
            self.list.searchText = nil
            self.checkedStocks = []
        }
    }


}




struct stockSection : View {
    @State var stocks : [Stock]
    @Binding var isChoosing:Bool
    @Binding var isSeaching:Bool
    @Binding var checkedStocks: [Stock]


    var header:String {
        (stocks[0].group == "" ? "<搜尋結果>" : "[\(stocks[0].group)]")
    }
    var footer:String {
        "\(stocks.count)支股"
    }

    var body: some View {
        Section(header: Text(header),footer: Text(footer)) {
            ForEach(stocks, id: \.sId) {stock in
                stockCell(stock: stock, isChoosing: self.$isChoosing, isSearching: self.$isSeaching, checkedStocks: self.$checkedStocks)
            }
        }
    }
    
}


struct stockCell : View {
    var stock : Stock
    @Binding var isChoosing:Bool
    @Binding var isSearching:Bool
    @Binding var checkedStocks:[Stock]
        
    var body: some View {
        HStack {
            if isChoosing || (isSearching && stock.group == "") {
                checkStock(stock: self.stock, isChecked: false, checkedStocks: self.$checkedStocks)
            }
            Text(stock.sId)
                .frame(width : 50.0, alignment: .leading)
            Text(stock.sName)
                .frame(width : 80.0, alignment: .leading)
            if stock.group != "" && !isChoosing && !isSearching {
                NavigationLink(destination: stockPage(stock: stock)) {
                    Text("")
                }
                    .navigationBarTitle("")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct checkStock: View {
    var stock : Stock
    @State var isChecked:Bool
    @Binding var checkedStocks:[Stock]
    
    
    func check() {
        self.isChecked = !self.isChecked
        if self.isChecked {
            self.checkedStocks.append(stock)
        } else {
            self.checkedStocks.removeAll(where: {$0 == stock})
        }
    }

    var body: some View {
        Group {
            Button(action: check) {
                Image(systemName: isChecked ? "checkmark.square" : "square")
            }
        }
    }
}

struct stockPage: View {
    var stock : Stock
    
    var body: some View {
        VStack {
            HStack {
                Text(stock.sId)
                Text(stock.sName)
            }
        }
        .padding()
    }
}

struct SearchBar: View {
    @State   private var isEditing = false
    @Binding var text: String
    @Binding var searchText:[String]?
    @Binding var isSearching:Bool


    var body: some View {
        HStack {
            TextField("以代號或簡稱來搜尋未加入股群的上市股票", text: $text, onEditingChanged: {    //began or end (bool)
                self.isEditing = $0
//                self.isSearching = true
            }, onCommit: {
                self.searchText = self.text.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ").components(separatedBy: " ")
                self.isEditing = false
                self.isSearching = true
            })
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .minimumScaleFactor(0.5)
                .cornerRadius(8)
                .overlay(
                   HStack {
                       Image(systemName: "magnifyingglass")
                           .foregroundColor(.gray)
                           .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                           .padding(.leading, 8)
                
                       if isEditing {
                            Button(action: {
                                self.text = ""
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
            if isEditing {
                Button(action: {
                    self.isSearching = false
                    self.isEditing = false
                    self.text = ""
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

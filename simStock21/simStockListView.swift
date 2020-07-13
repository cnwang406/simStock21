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
    @Environment(\.horizontalSizeClass) var sizeClass
        
    var body: some View {
        NavigationView {
            VStack (alignment: .leading) {
                Spacer()
                SearchBar(editText: self.$searchText, searchText: $list.searchText, isSearching: self.$isSearching)
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


    
    var choose: some View {
        HStack {
            if isChoosing {
                Text("請勾選")
                    .foregroundColor(Color(.darkGray))
                 if checkedStocks.count > 0 {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                    Button((sizeClass == .regular ? "自股群" : "") + "移除") {
                        self.list.moveStocks(self.checkedStocks)
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
                Button("編輯") {
                    self.isChoosing = true
                    self.searchText = ""
                    self.list.searchText = nil
                    self.isSearching = false
                }
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
                Button("取消" + (sizeClass == .regular ? "編輯模式" : "")) {
                    self.isChoosing = false
                    self.checkedStocks = []
                }
            } else if self.list.searchGotResults {
                Button("放棄" + (sizeClass == .regular ? "搜尋結果" : "")) {
                    self.searchText = ""
                    self.list.searchText = nil
                    self.checkedStocks = []
                    self.isSearching = false
                }
            }
        }
        .frame(width:(sizeClass == .regular ? 100.0 : 50.0), alignment: .trailing)
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
                    Picker("", selection: self.$groupPicked) {
                        Text("新增股群").tag("新增股群")
                        ForEach(self.list.groups, id: \.self) { (gName:String) in
                            Text(gName).tag(gName)
                        }
                    }
//                        .pickerStyle(WheelPickerStyle())
                        .labelsHidden()
                }

                if self.groupPicked == "新增股群" {
                    Section (header: Text("加入新增的股群：")) {
                        TextField("輸入股群名稱", text: self.$newGroup, onEditingChanged: { _ in    //began or end (bool)
                            }, onCommit: {
                            })
                    }
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




struct stockSection : View {
    @ObservedObject var list: simStockList

    @State var stocks : [Stock]
    @Binding var isChoosing:Bool
    @Binding var isSeaching:Bool
    @Binding var checkedStocks: [Stock]


    var header:some View {
        Text((stocks[0].group == "" ? "<搜尋結果>" : "[\(stocks[0].group)]"))
            .font(.headline)
//            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.5))
    }
    var footer:some View {
        Text("\(stocks.count)支股")
    }

    var body: some View {
        Section(header: header,footer: footer) {
            ForEach(stocks, id: \.self) {stock in
                stockCell(list: self.list, stock: stock, isChoosing: self.$isChoosing, isSearching: self.$isSeaching, checkedStocks: self.$checkedStocks)
            }
        }
    }
    
}


struct stockCell : View {
    @ObservedObject var list: simStockList

    var stock : Stock
    @Binding var isChoosing:Bool
    @Binding var isSearching:Bool
    @Binding var checkedStocks:[Stock]
    @State   var prefix:String = ""
        
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
                NavigationLink(destination: stockPageView(list: self.list, stock: stock, prefix: stock.prefix)) {
                    Text("")
                }
//                .simultaneousGesture(TapGesture().onEnded{
//                    self.list.stock = self.stock
//                    print("hello hello hello")
//                })
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
            .foregroundColor(self.checkedStocks.contains(stock) ? .orange : ((isSearching && stock.group != "") ? .gray : .primary))
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
                .background(Color(.systemGray6))
                .minimumScaleFactor(0.5)
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

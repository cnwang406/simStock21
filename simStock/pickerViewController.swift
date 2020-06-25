//
//  pickerViewController.swift
//  simPrice
//
//  Created by peiyu on 2016/9/12.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit

class pickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate { //, UIGestureRecognizerDelegate
    @IBOutlet weak var uiPicker: UIPickerView!
    var masterUI:masterUIDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let simId = masterUI?.getStock().simId {
            stockPickerScrollTo(simId)
        }
    }

    //===== 以下 stockId Picker dataSource and delegate =====
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var count:Int = 0
        if let cnt = masterUI?.getStock().sortedStocks.count {
            count = cnt
        }
        return count
    }

//    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        let id = stockNames[row].id
//        let name = stockNames[row].name
//        let label = id + " " + name  //這是按名稱排序後的股票代號名稱
//        return label
//    }


    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var pickerLabel:UILabel? = view as? UILabel
        if pickerLabel == nil {
            pickerLabel = UILabel()
        }
        if let sortedStocks = masterUI?.getStock().sortedStocks {
            let id = sortedStocks[row].id
            let name = sortedStocks[row].name
            let titleData = id + " " + name  //這是按名稱排序後的股票代號名稱
            var fontColor:UIColor = UIColor.black
            
            if let sim = masterUI?.getStock().simPrices[id] {
                let endQtySell = (sim.getPriceEnd("qtySell") as? Double ?? 0)
                if endQtySell > 0 {
                    fontColor = UIColor.blue
                } else {
                    fontColor = (masterUI?.simRuleColor((sim.getPriceEnd("simRule") as? String ?? "")) ?? UIColor.darkGray)
                }
            }

            let attributedTitle = NSMutableAttributedString(string: titleData, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor):fontColor, convertFromNSAttributedStringKey(NSAttributedString.Key.font) : UIFont.systemFont(ofSize: 24.0)]))
            
            
            pickerLabel?.attributedText = attributedTitle
            pickerLabel?.textAlignment = .center
        }
        return pickerLabel!
    }


    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if let simId = masterUI?.getStock().sortedStocks[row].id {  //這是股票代號
            let _ = masterUI?.getStock().setSimId(newId:simId)
        }
    }
    //===== 以上 stockId Picker dataSource and delegate =====

    func stockPickerScrollTo(_ stockId:String) {  //捲到stockId那一列
        if let sortedStocks = masterUI?.getStock().sortedStocks {
            if let row = sortedStocks.firstIndex(where: {$0.id == stockId}) {
                uiPicker.selectRow(row, inComponent: 0, animated: false)
                return
            }
        }
        uiPicker.selectRow(0, inComponent: 0, animated: false)
        return
    }



}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

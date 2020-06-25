//
//  priceself.swift
//  simStock
//
//  Created by peiyu on 2016/4/1.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit

protocol priceCellDelegate:class {
    func moneyChanging (_ sender:UITableViewCell,changeFactor:Double)
    func reverseAction (_ sender:UITableViewCell,button:UIButton)
}

//******************************************
//********** 價格與模擬明細的介面元件 **********
//******************************************

class priceCell: UITableViewCell {
    var masterView:priceCellDelegate?

    @IBOutlet weak var uiDate: UILabel!
    @IBOutlet weak var uiTime: UILabel!
    @IBOutlet weak var uiClose: UILabel!
    @IBOutlet weak var uiDivCash: UILabel!
    @IBOutlet weak var uiConsDivCash: NSLayoutConstraint!
    
    @IBOutlet weak var uiSimDays: UILabel!
    @IBOutlet weak var uiSimIncome: UILabel!
    @IBOutlet weak var uiSimTrans1: UILabel!
    @IBOutlet weak var uiSimTrans2: UILabel!
    @IBOutlet weak var uiSimUnitCost: UILabel!
    @IBOutlet weak var uiSimUnitDiff: UILabel!
    @IBOutlet weak var uiMoneyBuy: UILabel!
    @IBOutlet weak var uiSimMoney: UILabel!
    @IBOutlet weak var uiSimCost: UILabel!
    @IBOutlet weak var uiLabelCost: UILabel!
    @IBOutlet weak var uiSimPL: UILabel!
    @IBOutlet weak var uiLabelPL: UILabel!

    @IBOutlet weak var uiLabelUnitCost: UILabel!
    @IBOutlet weak var uiLabelUnitDiff: UILabel!
    @IBOutlet weak var uiLabelIncome: UILabel!
    @IBOutlet weak var uiTipForQty: UILabel!

    @IBOutlet weak var uiOpen: UILabel!
    @IBOutlet weak var uiHigh: UILabel!
    @IBOutlet weak var uiLow: UILabel!

    @IBOutlet weak var uiK: UILabel!
    @IBOutlet weak var uiD: UILabel!
    @IBOutlet weak var uiJ: UILabel!
    @IBOutlet weak var uiMA20: UILabel!
    @IBOutlet weak var uiMA60: UILabel!
    @IBOutlet weak var uiMacdOsc: UILabel!
    @IBOutlet weak var uiUpdatedBy: UILabel!

    @IBOutlet weak var uiLabelClose: UILabel!
    @IBOutlet weak var uiSimROI: UILabel!

    @IBOutlet weak var uiButtonIncrease: UIButton!
    @IBOutlet weak var uiTipForButton: UILabel!
    @IBOutlet weak var uiSimReverse: UIButton!

    @IBOutlet weak var uiMA20Diff: UILabel!
    @IBOutlet weak var uiMA60Diff: UILabel!
    @IBOutlet weak var uiMADiff: UILabel!
    @IBOutlet weak var uiMA20Min: UILabel!
    @IBOutlet weak var uiMA60Min: UILabel!
    @IBOutlet weak var uiMAMin: UILabel!
    @IBOutlet weak var uiMA20Max: UILabel!
    @IBOutlet weak var uiMA60Max: UILabel!
    @IBOutlet weak var uiMAMax: UILabel!
    @IBOutlet weak var uiMA20Days: UILabel!
    @IBOutlet weak var uiMA60Days: UILabel!
    @IBOutlet weak var uiMADays: UILabel!
    
    @IBOutlet weak var uiMA20L: UILabel!
    @IBOutlet weak var uiMA20H: UILabel!
    @IBOutlet weak var uiMA20MaxHL: UILabel!
    @IBOutlet weak var uiMA60L: UILabel!
    @IBOutlet weak var uiMA60H: UILabel!
    @IBOutlet weak var uiMA60MaxHL: UILabel!
    @IBOutlet weak var uiMA60Z: UILabel!
    @IBOutlet weak var uiOscMin: UILabel!
    @IBOutlet weak var uiOscMax: UILabel!
    @IBOutlet weak var uiOscL: UILabel!
    @IBOutlet weak var uiOscH: UILabel!
    @IBOutlet weak var uiOscZ: UILabel!
    @IBOutlet weak var uiK20: UILabel!
    @IBOutlet weak var uiK80: UILabel!
    @IBOutlet weak var uiKZ: UILabel!
    @IBOutlet weak var uiSimRule: UILabel!
    @IBOutlet weak var uiMA60Avg: UILabel!
    @IBOutlet weak var uiVolumeZ: UILabel!
    @IBOutlet weak var uiP60L: UILabel!
    @IBOutlet weak var uiP60H: UILabel!
    @IBOutlet weak var uiP250L: UILabel!
    @IBOutlet weak var uiP250H: UILabel!
    
    @IBOutlet weak var uiBG0: UILabel!
    @IBOutlet weak var uiBG1: UILabel!
    @IBOutlet weak var uiBG2: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        uiDate.adjustsFontSizeToFitWidth = true
        uiTime.adjustsFontSizeToFitWidth = true
        uiClose.adjustsFontSizeToFitWidth = true
        uiDivCash.adjustsFontSizeToFitWidth = true

        uiSimDays.adjustsFontSizeToFitWidth = true
        uiSimIncome.adjustsFontSizeToFitWidth = true
        uiSimTrans1.adjustsFontSizeToFitWidth = true
        uiSimTrans2.adjustsFontSizeToFitWidth = true
        uiSimUnitCost.adjustsFontSizeToFitWidth = true
        uiSimUnitDiff.adjustsFontSizeToFitWidth = true
        uiMoneyBuy.adjustsFontSizeToFitWidth = true
        uiSimMoney.adjustsFontSizeToFitWidth = true
        uiSimCost.adjustsFontSizeToFitWidth = true
        uiLabelCost.adjustsFontSizeToFitWidth = true
        uiSimPL.adjustsFontSizeToFitWidth = true
        uiLabelPL.adjustsFontSizeToFitWidth = true

        uiLabelUnitCost.adjustsFontSizeToFitWidth = true
        uiLabelUnitDiff.adjustsFontSizeToFitWidth = true
        uiLabelIncome.adjustsFontSizeToFitWidth = true
        uiTipForQty.adjustsFontSizeToFitWidth = true

        uiOpen.adjustsFontSizeToFitWidth = true
        uiHigh.adjustsFontSizeToFitWidth = true
        uiLow.adjustsFontSizeToFitWidth = true

        uiK.adjustsFontSizeToFitWidth = true
        uiD.adjustsFontSizeToFitWidth = true
        uiJ.adjustsFontSizeToFitWidth = true
        uiMA20.adjustsFontSizeToFitWidth = true
        uiMA60.adjustsFontSizeToFitWidth = true

        uiMacdOsc.adjustsFontSizeToFitWidth = true
        uiUpdatedBy.adjustsFontSizeToFitWidth = true

        uiLabelClose.adjustsFontSizeToFitWidth = true
        uiSimROI.adjustsFontSizeToFitWidth = true

        uiTipForButton.adjustsFontSizeToFitWidth = true

        uiMA20Diff.adjustsFontSizeToFitWidth = true
        uiMA60Diff.adjustsFontSizeToFitWidth = true
        uiMADiff.adjustsFontSizeToFitWidth = true
        uiMA20Min.adjustsFontSizeToFitWidth = true
        uiMA60Min.adjustsFontSizeToFitWidth = true
        uiMAMin.adjustsFontSizeToFitWidth = true
        uiMA20Max.adjustsFontSizeToFitWidth = true
        uiMA60Max.adjustsFontSizeToFitWidth = true
        uiMAMax.adjustsFontSizeToFitWidth = true
        uiMA20Days.adjustsFontSizeToFitWidth = true
        uiMA60Days.adjustsFontSizeToFitWidth = true
        uiMADays.adjustsFontSizeToFitWidth = true

        uiMA20L.adjustsFontSizeToFitWidth = true
        uiMA20H.adjustsFontSizeToFitWidth = true
        uiMA20MaxHL.adjustsFontSizeToFitWidth = true
        uiMA60L.adjustsFontSizeToFitWidth = true
        uiMA60H.adjustsFontSizeToFitWidth = true
        uiMA60MaxHL.adjustsFontSizeToFitWidth = true
        uiMA60Z.adjustsFontSizeToFitWidth = true
        uiOscMin.adjustsFontSizeToFitWidth = true
        uiOscMax.adjustsFontSizeToFitWidth = true
        uiOscL.adjustsFontSizeToFitWidth = true
        uiOscH.adjustsFontSizeToFitWidth = true
        uiOscZ.adjustsFontSizeToFitWidth = true
        uiK20.adjustsFontSizeToFitWidth = true
        uiK80.adjustsFontSizeToFitWidth = true
        uiKZ.adjustsFontSizeToFitWidth = true
        uiSimRule.adjustsFontSizeToFitWidth = true
        uiMA60Avg.adjustsFontSizeToFitWidth = true
        uiP60L.adjustsFontSizeToFitWidth = true
        uiP250L.adjustsFontSizeToFitWidth = true
        uiP60H.adjustsFontSizeToFitWidth = true
        uiP250H.adjustsFontSizeToFitWidth = true
        uiVolumeZ.adjustsFontSizeToFitWidth = true

        uiBG0.adjustsFontSizeToFitWidth = true
        uiBG1.adjustsFontSizeToFitWidth = true
        uiBG2.adjustsFontSizeToFitWidth = true

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func uiIncreasePrincipal(_ sender: UIButton) {
        masterView?.moneyChanging(self, changeFactor: 1)
    }

    @IBAction func uiReverse(_ sender: UIButton) {
        masterView?.reverseAction(self, button: sender)
    }
}







//****************************************
//********** 模擬參數的輸入介面元件 **********
//****************************************

class settingButtonCell:UITableViewCell {
    @IBOutlet weak var uiSetToDefault: UIButton!
}


class initMoneyCell: UITableViewCell {
    var settingView:settingDelegate?
    @IBOutlet weak var uiMoney: UILabel!
    @IBOutlet weak var uiMoneySlider: UISlider!

    @IBAction func uiMoneyChanged(_ sender: UISlider) {
        var value:Float = sender.value
        value = round(value)
        sender.setValue(value, animated: false)
        var money:Double = 100
        if value > 33 {
            money = Double(value - 31) * 500
        } else if value > 28 {
            money = Double(value - 23) * 100
        } else if value > 19 {
            money = Double(value - 18) * 50
        } else {
            money = ceil(Double(value + 1) / 2) * 10
        }
        uiMoney.adjustsFontSizeToFitWidth = true
        uiMoney.text = String(format:"%.f萬元",money)
        settingView?.changedInitMoney(money)
    }

}

class dateLabelCell: UITableViewCell {
    @IBOutlet weak var uiDateLabelTitle: UILabel!
    @IBOutlet weak var uiDateLabel: UILabel!
}

class datePickerCell: UITableViewCell {
    var settingView:settingDelegate?
    var settingItem:String?
    @IBOutlet weak var uiDatePicker: UIDatePicker!
    @IBAction func uiDatePickerChanged(_ sender: UIDatePicker) {
         if let _ = settingItem {
            settingView?.changedDatePicker(sender.date, settingItem: settingItem!)
        } else {
            settingView?.changedDatePicker(sender.date, settingItem: "")
        }

    }
}

class dateSwitchCell: UITableViewCell {
    var settingView:settingDelegate?
    @IBOutlet weak var uiDateSwitch: UISwitch!
    @IBAction func uiDateSwitchChanged(_ sender: UISwitch) {
        let switchOn = sender.isOn
        settingView?.changedDateEndSwitch(switchOn)
    }
}

class giveMoneySwitchCell: UITableViewCell {
    var settingView:settingDelegate?
    @IBOutlet weak var uiGiveMoneySwitch: UISwitch!
    @IBAction func uiGiveMoneySwitchChanged(_ sender: UISwitch) {
        let switchOn = sender.isOn
        settingView?.changedGiveMoneySwitch(switchOn)
    }
    
    
}









//*****************************************
//********** 股群清單 **********
//*****************************************

class stockListCell: UITableViewCell {
    var stockView:stockViewDelegate?

    @IBOutlet weak var uiId: UILabel!
    @IBOutlet weak var uiName: UILabel!
    @IBOutlet weak var uiButtonAdd: UIButton!
    @IBOutlet weak var uiROI: UILabel!
    @IBOutlet weak var uiYears: UILabel!
    @IBOutlet weak var uiButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var uiMultiple: UILabel!
    @IBOutlet weak var uiDays: UILabel!

    @IBAction func uiCellAddButton(_ sender: UIButton) {
        stockView?.addSearchedToList(self)
    }

    @IBOutlet weak var uiCellPriceClose: UILabel!
    @IBOutlet weak var uiCellPriceUpward: UILabel!
    @IBOutlet weak var uiCellAction: UILabel!
    @IBOutlet weak var uiCellQty: UILabel!
    @IBOutlet weak var uiMissed: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.uiId.adjustsFontSizeToFitWidth = true
        self.uiName.adjustsFontSizeToFitWidth = true
        self.uiCellPriceClose.adjustsFontSizeToFitWidth = true
        self.uiCellPriceUpward.adjustsFontSizeToFitWidth = true
        self.uiCellAction.adjustsFontSizeToFitWidth = true
        self.uiCellQty.adjustsFontSizeToFitWidth = true
        self.uiDays.adjustsFontSizeToFitWidth = true
        self.uiYears.adjustsFontSizeToFitWidth = true
        self.uiMissed.adjustsFontSizeToFitWidth = true
        self.uiMultiple.adjustsFontSizeToFitWidth = true
        self.uiROI.adjustsFontSizeToFitWidth = true
        
    }
    
}



//Class for ToolTip Label
class ToolTipUp: UILabel {

    var newRect:CGRect!

    override func drawText(in rect: CGRect) {
        super.drawText(in: newRect)
    }

    override func draw(_ rect: CGRect) {
        let tailSize:CGFloat = rect.height / 4
        newRect = CGRect(x: rect.minX, y: rect.minY + tailSize, width: rect.width, height: rect.height - tailSize)

        let triangleBez = UIBezierPath()
        triangleBez.move(to: CGPoint(x: rect.midX - (tailSize / 2), y:newRect.minY))
        triangleBez.addLine(to: CGPoint(x:rect.midX,y:rect.minY))
        triangleBez.addLine(to: CGPoint(x: rect.midX + (tailSize / 2), y:newRect.minY))
        triangleBez.close()

        UIColor.groupTableViewBackground.setFill()
        let roundRectBez = UIBezierPath(roundedRect: newRect, cornerRadius: 5)
        roundRectBez.append(triangleBez)
        roundRectBez.fill()
        
        super.draw(rect)
        
    }
    
}

class TapGesture: UITapGestureRecognizer {
    var message:String = ""
    var width:CGFloat  = 150
    var height:CGFloat = 44
    var delay:Int      = 1
}

class popoverMessage: UIViewController,UIPopoverPresentationControllerDelegate {
    @IBOutlet weak var uiPopoverText: UILabel!
    
    var delay:Int = 1
    override func viewDidLoad() {
        super.viewDidLoad()
        uiPopoverText.adjustsFontSizeToFitWidth = true
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(delay) , execute: {
                self.dismiss(animated: true, completion: nil)
            })
        }
    }
        
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
}


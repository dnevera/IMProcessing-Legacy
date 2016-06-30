//
//  IMPRGBCurvesControl.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 29/06/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Cocoa
import SnapKit
import IMProcessing
import simd

public enum IMPCurvesRGBChannelType : String {
    case RGB = "RGB"
    case Red = "Red"
    case Green = "Green"
    case Blue = "Blue"
}

public class IMPRGBCurvesControl: IMPViewBase {
    
    typealias Type = IMPCurvesRGBChannelType
    
    public var backgroundColor:IMPColor? {
        didSet{
            wantsLayer = true
            layer?.backgroundColor = backgroundColor?.CGColor
            channelSelector.backgroundColor = backgroundColor
            _curvesView.backgroundColor = backgroundColor
        }
    }

    public var curvesView:IMPCurvesView {get{return _curvesView}}
    
    
    lazy var _curvesView:IMPCurvesView = {
        return IMPCurvesView(frame: self.bounds)
    }()

    lazy var splineFunctionSelector:IMPPopUpButton = {
        let v = IMPPopUpButton(frame:NSRect(x:10,y:10,width: self.bounds.size.width, height: 40), pullsDown: false)
        v.autoenablesItems = false
        v.target = self
        v.action = #selector(self.selectSplineFunction(_:))
        v.selectItemAtIndex(0)
        return v
    }()
    
    
    @objc private func selectSplineFunction(sender:IMPPopUpButton){
        guard let item = sender.titleOfSelectedItem else {return}
        if let t = IMPCurveFunction(rawValue: item) {
            if curvesView.curveFunction != t {
                curvesView.curveFunction = t
            }
        }
    }

    lazy var channelSelector:IMPPopUpButton = {
        let v = IMPPopUpButton(frame:NSRect(x:10,y:10,width: self.bounds.size.width, height: 40), pullsDown: false)
        v.autoenablesItems = false
        v.target = self
        v.action = #selector(self.selectChannel(_:))
        v.selectItemAtIndex(0)
        return v
    }()
    
    @objc private func selectChannel(sender:IMPPopUpButton)  {
        for i in curvesView.list {
            i.isActive = false
        }
        currentCurveIndex = sender.indexOfSelectedItem
    }

    
    lazy var resetButton:NSButton = {
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .Center

        let attributes = [ NSForegroundColorAttributeName : IMPColor.darkGrayColor(), NSParagraphStyleAttributeName : pstyle ]
        
        let b = NSButton()
        b.attributedTitle = NSAttributedString(string: "Reset  ", attributes: attributes)
        
        b.target = self
        b.action = #selector(self.resetHandler(_:))

        return b
    }()

    @objc private func resetHandler(sender:NSButton)  {
            curvesView.reset()
    }

    var currentCurveIndex:Int = 0 {
        didSet {
            curvesView.list[currentCurveIndex].isActive = true
        }
    }
    
    var initial = true
    override public func updateLayer() {
        if initial {
            
            addSubview(curvesView)
            addSubview(channelSelector)
            addSubview(splineFunctionSelector)
            addSubview(resetButton)
            
            initial = true
            
            channelSelector.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.snp_top).offset(0)
                make.left.equalTo(self).offset(0)
                make.width.greaterThanOrEqualTo(44)
            }

            resetButton.snp_makeConstraints { (make) -> Void in
                make.centerY.equalTo(self.channelSelector.snp_centerY).offset(0)
                make.right.equalTo(self).offset(0)
            }

            splineFunctionSelector.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.snp_top).offset(0)
                make.left.equalTo(self.channelSelector.snp_right).offset(10)
                make.right.equalTo(self.resetButton.snp_left).offset(-10)
            }
            
            curvesView.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.channelSelector.snp_bottom).offset(5)
                make.left.equalTo(self).offset(0)
                make.right.equalTo(self).offset(0)
                make.bottom.equalTo(self).offset(0)
            }
            
            curvesView <- IMPCurvesView.CurveInfo(name: Type.RGB.rawValue,   color:  IMPColor(red: 1,   green: 1, blue: 1, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Red.rawValue,   color:  IMPColor(red: 1,   green: 0.2, blue: 0.2, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Green.rawValue, color:  IMPColor(red: 0,   green: 1,   blue: 0,   alpha: 0.6))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Blue.rawValue,  color:  IMPColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8))
            
            for el in curvesView.list {
                channelSelector.addItemWithTitle(el.name)
            }
            
            curvesView.list[0].isActive = true
            
            splineFunctionSelector.addItemsWithTitles([IMPCurveFunction.Cubic.rawValue, IMPCurveFunction.Bezier.rawValue])
        }
        channelSelector.selectItemAtIndex(currentCurveIndex)
    }
}

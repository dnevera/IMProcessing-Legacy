//
//  IMPHSVCurvesControl.swift
//  IMPCurvesViewTest
//
//  Created by denis svinarchuk on 02.07.16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Cocoa
import SnapKit
import IMProcessing
import simd

public enum IMPHSVCurvesCircleType : String {
    case Master   = "Master"
    case Reds     = "Reds"
    case Yellows  = "Yellows"
    case Greens   = "Greens"
    case Cyans    = "Cyans"
    case Blues    = "Blues"
    case Magentas = "Magentas"
}

public enum IMPHSVCurvesChannelType : String {
    case Hue        = "Hue"
    case Saturation = "Saturation"
    case Value      = "Value"
}

public class IMPHSVCurvesControl: IMPViewBase {
    
    public typealias Type = IMPHSVCurvesCircleType
    public typealias ChannelType = IMPHSVCurvesChannelType
    
    public typealias AutoRangesType    = [(low:float2,high:float2)]
    public typealias AutoFunctionType  = (() -> AutoRangesType)
    
    public var backgroundColor:IMPColor? {
        didSet{
            wantsLayer = true
            layer?.backgroundColor = backgroundColor?.CGColor
            colorslSelector.backgroundColor = backgroundColor
            _curvesView.backgroundColor = backgroundColor
        }
    }
    
    public var curvesView:IMPCurvesView {get{return _curvesView}}
    public var autoCorrection:AutoFunctionType?
    
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
                curvesView.reset()
                curvesView.curveFunction = t
            }
        }
    }
    
    lazy var colorslSelector:IMPPopUpButton = {
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
    
    lazy var hueTab:NSTabViewItem = {
        var i = NSTabViewItem(identifier: IMPHSVCurvesChannelType.Hue.rawValue)
        i.label = IMPHSVCurvesChannelType.Hue.rawValue
        return i
    }()

    lazy var saturationTab:NSTabViewItem = {
        var i = NSTabViewItem(identifier: IMPHSVCurvesChannelType.Saturation.rawValue)
        i.label = IMPHSVCurvesChannelType.Saturation.rawValue
        return i
    }()

    lazy var valueTab:NSTabViewItem = {
        var i = NSTabViewItem(identifier: IMPHSVCurvesChannelType.Value.rawValue)
        i.label = IMPHSVCurvesChannelType.Value.rawValue
        return i
    }()

    lazy var channelsTab:NSTabView = {
        var t = NSTabView()
        t.addTabViewItem(self.hueTab)
        t.addTabViewItem(self.saturationTab)
        t.addTabViewItem(self.valueTab)
        return t
    }()
    
    var initial = true
    override public func updateLayer() {
        if initial {
            
            addSubview(channelsTab)
            //addSubview(curvesView)
            addSubview(colorslSelector)
            addSubview(splineFunctionSelector)
            addSubview(resetButton)
            
            initial = true
            
            colorslSelector.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.snp_top).offset(0)
                make.left.equalTo(self).offset(0)
                make.width.greaterThanOrEqualTo(44)
            }
            
            resetButton.snp_makeConstraints { (make) -> Void in
                make.centerY.equalTo(self.colorslSelector.snp_centerY).offset(0)
                make.right.equalTo(self.snp_right).offset(-10)
            }
            
            splineFunctionSelector.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.snp_top).offset(0)
                make.left.equalTo(self.colorslSelector.snp_right).offset(10)
                make.right.equalTo(self.resetButton.snp_left).offset(-10)
            }
            
            channelsTab.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.colorslSelector.snp_bottom).offset(5)
                make.left.equalTo(self).offset(0)
                make.right.equalTo(self).offset(0)
                make.bottom.equalTo(self).offset(0)
            }
            
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Master.rawValue,    color:  IMPColor(red: 1,   green: 1,   blue: 1,   alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Reds.rawValue,      color:  IMPColor(red: 1,   green: 0.2, blue: 0.2, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Yellows.rawValue,   color:  IMPColor(red: 0.7, green: 0.7, blue: 0.2, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Greens.rawValue,    color:  IMPColor(red: 0,   green: 1,   blue: 0,   alpha: 0.6))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Cyans.rawValue,     color:  IMPColor(red: 1,   green: 0.7, blue: 0.7, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Blues.rawValue,     color:  IMPColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: Type.Magentas.rawValue,  color:  IMPColor(red: 0.8, green: 0.2, blue: 0.8, alpha: 0.8))
            
            for el in curvesView.list {
                colorslSelector.addItemWithTitle(el.name)
            }
            
            curvesView.list[0].isActive = true
            
            splineFunctionSelector.addItemsWithTitles([IMPCurveFunction.Cubic.rawValue, IMPCurveFunction.Bezier.rawValue, IMPCurveFunction.CatmullRom.rawValue])
        }
        colorslSelector.selectItemAtIndex(currentCurveIndex)
    }
}

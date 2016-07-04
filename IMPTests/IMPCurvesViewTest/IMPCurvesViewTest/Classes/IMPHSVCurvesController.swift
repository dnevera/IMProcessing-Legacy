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

public enum IMPHSVCurvesChannelType : String {
    case Hue        = "Hue"
    case Saturation = "Saturation"
    case Value      = "Value"
}

public class IMPHSVCurvesController: NSViewController,  NSTabViewDelegate {

    public typealias ColorsType = IMPHSVColorsType
    public typealias ChannelType = IMPHSVCurvesChannelType

    public typealias CurvesUpdateHandler = ((channel:ChannelType, collors:ColorsType,  spline:IMPSpline)->Void)
    public typealias CurveFunctionUpdateHandler = ((function:IMPCurveFunction)->Void)
    
    public typealias AutoRangesType    = [(low:float2,high:float2)]
    public typealias AutoFunctionType  = (() -> AutoRangesType)
    
    
    public var didCurvesUpdate:CurvesUpdateHandler?
    public var didCurveFunctionUpdate:CurveFunctionUpdateHandler?

    lazy var splineFunctionSelector:IMPPopUpButton = {
        let v = IMPPopUpButton(frame:NSRect(x:10,y:10,width: self.view.bounds.size.width, height: 40), pullsDown: false)
        v.autoenablesItems = false
        v.target = self
        v.action = #selector(self.selectSplineFunction(_:))
        v.selectItemAtIndex(0)
        return v
    }()
    
    @objc private func selectSplineFunction(sender:IMPPopUpButton){
        guard let item = sender.titleOfSelectedItem else {return}
        if let t = IMPCurveFunction(rawValue: item) {
            for v in curvesViews {
                if v.curveFunction != t {
                    v.reset()
                    v.curveFunction = t
                }
            }
            if let o = self.didCurveFunctionUpdate{
                o(function:t)
            }
        }
    }
    
    lazy var colorslSelector:IMPPopUpButton = {
        let v = IMPPopUpButton(frame:NSRect(x:10,y:10,width: self.view.bounds.size.width, height: 40), pullsDown: false)
        v.autoenablesItems = false
        v.target = self
        v.action = #selector(self.selectColors(_:))
        v.selectItemAtIndex(0)
        return v
    }()
    
    @objc private func selectColors(sender:IMPPopUpButton)  {
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
        for v in curvesViews {
            v.reset()
        }
    }
    
    func updateCurrent() {
        if let c = currentCurves {
            for i in c.list {
                i.isActive = false
            }
            c.list[currentCurveIndex].isActive = true
        }
    }
    
    var currentCurveIndex:Int = 0 {
        didSet {
            updateCurrent()
        }
    }
    
    var currentCurves:IMPCurvesView? {
        didSet{
            updateCurrent()
        }
    }
    
    func prepareCurvesView() -> IMPCurvesView {
        let v = IMPCurvesView(frame: self.view.bounds)
        
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Master.rawValue,    color:  IMPColor(red: 1,   green: 1,   blue: 1,   alpha: 0.8))
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Reds.rawValue,      color:  IMPColor(red: 1,   green: 0.2, blue: 0.2, alpha: 0.8))
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Yellows.rawValue,   color:  IMPColor(red: 0.7, green: 0.7, blue: 0.2, alpha: 0.8))
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Greens.rawValue,    color:  IMPColor(red: 0,   green: 1,   blue: 0,   alpha: 0.6))
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Cyans.rawValue,     color:  IMPColor(red: 1,   green: 0.7, blue: 0.7, alpha: 0.8))
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Blues.rawValue,     color:  IMPColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8))
        v <- IMPCurvesView.CurveInfo(name: ColorsType.Magentas.rawValue,  color:  IMPColor(red: 0.8, green: 0.2, blue: 0.8, alpha: 0.8))
        
        for el in  v .list {
            colorslSelector.addItemWithTitle(el.name)
        }
        
        v.list[0].isActive = true
        
        v.didControlPointsUpdate = {(info) in
            if let o = self.didCurvesUpdate {
                guard let channel = self.currentChannel else {return }
                guard let spline = info.spline else { return }
                if let colors = ColorsType(rawValue:info.id){
                    o(channel: channel, collors: colors, spline: spline)
                }
            }
        }
        
        return v
    }
    
    lazy var hueCurvesView:IMPCurvesView = {
        return self.prepareCurvesView()
    }()
    
    
    lazy var saturationCurvesView:IMPCurvesView = {
        return self.prepareCurvesView()
    }()
    
    lazy var valueCurvesView:IMPCurvesView = {
        return self.prepareCurvesView()
    }()
    
    lazy var curvesViews:[IMPCurvesView] = [self.hueCurvesView,self.saturationCurvesView,self.valueCurvesView]
    
    lazy var hueTab:NSTabViewItem = {
        var i = NSTabViewItem(identifier: IMPHSVCurvesChannelType.Hue.rawValue)
        i.label = IMPHSVCurvesChannelType.Hue.rawValue
        i.view = self.hueCurvesView
        return i
    }()
    
    lazy var saturationTab:NSTabViewItem = {
        var i = NSTabViewItem(identifier: IMPHSVCurvesChannelType.Saturation.rawValue)
        i.label = IMPHSVCurvesChannelType.Saturation.rawValue
        i.view = self.saturationCurvesView
        return i
    }()
    
    lazy var valueTab:NSTabViewItem = {
        var i = NSTabViewItem(identifier: IMPHSVCurvesChannelType.Value.rawValue)
        i.label = IMPHSVCurvesChannelType.Value.rawValue
        i.view = self.valueCurvesView
        return i
    }()
    
    lazy var channelsTab:NSTabView = {
        var t = NSTabView()
        t.delegate = self
        t.addTabViewItem(self.hueTab)
        t.addTabViewItem(self.saturationTab)
        t.addTabViewItem(self.valueTab)
        
        self.currentCurves = self.hueCurvesView
        
        return t
    }()
    
    var currentChannel:ChannelType?
    
    public func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem?) {
        if let channel = ChannelType(rawValue: tabViewItem?.identifier as! String) {
            
            currentChannel = channel
            
            switch  channel {
            case .Hue:
                currentCurves = self.hueCurvesView
            case .Saturation:
                currentCurves = self.saturationCurvesView
            case .Value:
                currentCurves = self.valueCurvesView
            }
        }
    }
    
    override public func loadView() {
        view = NSView()
        configure()
    }
    
    public func configure() {
        
        view.addSubview(channelsTab)
        view.addSubview(colorslSelector)
        view.addSubview(splineFunctionSelector)
        view.addSubview(resetButton)
        
        colorslSelector.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.snp_top).offset(0)
            make.left.equalTo(self.view).offset(0)
            make.width.greaterThanOrEqualTo(44)
        }
        
        resetButton.snp_makeConstraints { (make) -> Void in
            make.centerY.equalTo(self.colorslSelector.snp_centerY).offset(0)
            make.right.equalTo(self.view.snp_right).offset(-10)
        }
        
        splineFunctionSelector.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.snp_top).offset(0)
            make.left.equalTo(self.colorslSelector.snp_right).offset(10)
            make.right.equalTo(self.resetButton.snp_left).offset(-10)
        }
        
        channelsTab.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.colorslSelector.snp_bottom).offset(5)
            make.left.equalTo(self.view).offset(0)
            make.right.equalTo(self.view).offset(0)
            make.bottom.equalTo(self.view).offset(0)
        }
        
        splineFunctionSelector.addItemsWithTitles([IMPCurveFunction.Cubic.rawValue, IMPCurveFunction.Bezier.rawValue, IMPCurveFunction.CatmullRom.rawValue])
        colorslSelector.selectItemAtIndex(currentCurveIndex)
    }
}

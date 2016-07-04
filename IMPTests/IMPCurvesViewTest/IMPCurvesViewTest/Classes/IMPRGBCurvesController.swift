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

public enum IMPRGBCurvesChannelType : String {
    case RGB   = "RGB"
    case Red   = "Red"
    case Green = "Green"
    case Blue  = "Blue"
}

public class IMPRGBCurvesController: IMPViewBase {
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        updateLayer()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        updateLayer()
    }
    
    public typealias CurvesUpdateHandler = ((channel:ChannelType,  spline:IMPSpline)->Void)
    public typealias ChannelType         = IMPRGBCurvesChannelType
    public typealias AutoRangesType      = [(low:float2,high:float2)]
    public typealias AutoFunctionType    = (() -> AutoRangesType)
    public typealias CurveFunctionUpdateHandler = ((function:IMPCurveFunction)->Void)

    public var didCurvesUpdate:CurvesUpdateHandler?
    public var didCurveFunctionUpdate:CurveFunctionUpdateHandler?
    public var autoCorrection:AutoFunctionType?
    
    lazy var curvesView:IMPCurvesView = {
        var v = IMPCurvesView(frame: self.bounds)
        v.didControlPointsUpdate = {  (info) in
            if let o = self.didCurvesUpdate {
                guard let channel = ChannelType(rawValue: info.id) else {return }
                guard let spline = info.spline else { return }
                o(channel: channel, spline: spline)
            }
        }
        return v
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
                if let o = self.didCurveFunctionUpdate{
                    o(function:t)
                }
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

    lazy var autoButton:NSButton = {
        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .Center
        
        let attributes = [ NSForegroundColorAttributeName : IMPColor.darkGrayColor(), NSParagraphStyleAttributeName : pstyle ]
        
        let b = NSButton()
        b.attributedTitle = NSAttributedString(string: "Auto  ", attributes: attributes)
        
        b.target = self
        b.action = #selector(self.autoHandler(_:))
        
        return b
    }()

    @objc private func resetHandler(sender:NSButton)  {
        currentRanges = nil
        curvesView.reset()
    }
    
    public var currentRanges:AutoRangesType? {
        didSet{
            updateAutoRanges()
        }
    }
    
    func updateAutoRanges() {
        
        guard curvesView.list.count == currentRanges?.count else {return}
        
        if let ranges = currentRanges {
            for i in 0..<ranges.count {
                let low = ranges[i].low
                let high = ranges[i].high
                if let spline = curvesView.list[i].spline {
                    spline.removeAll()
                    spline.set(point: low, atIndex: 0)
                    spline.set(point: high, atIndex: 1)
                }
            }
        }
    }
    
    @objc private func autoHandler(sender:NSButton)  {
        if let f = autoCorrection {
            currentRanges = f()
        }
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
            addSubview(autoButton)
            
            initial = true
            
            channelSelector.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.snp_top).offset(0)
                make.left.equalTo(self).offset(0)
                make.width.greaterThanOrEqualTo(44)
            }

            autoButton.snp_makeConstraints { (make) -> Void in
                make.centerY.equalTo(self.channelSelector.snp_centerY).offset(0)
                make.right.equalTo(self).offset(0)
            }

            resetButton.snp_makeConstraints { (make) -> Void in
                make.centerY.equalTo(self.channelSelector.snp_centerY).offset(0)
                make.right.equalTo(self.autoButton.snp_left).offset(-10)
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
            
            curvesView <- IMPCurvesView.CurveInfo(name: ChannelType.RGB.rawValue,   color:  IMPColor(red: 1,   green: 1, blue: 1, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: ChannelType.Red.rawValue,   color:  IMPColor(red: 1,   green: 0.2, blue: 0.2, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: ChannelType.Green.rawValue, color:  IMPColor(red: 0,   green: 1,   blue: 0,   alpha: 0.6))
            curvesView <- IMPCurvesView.CurveInfo(name: ChannelType.Blue.rawValue,  color:  IMPColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8))
            
            for el in curvesView.list {
                channelSelector.addItemWithTitle(el.name)
            }
            
            curvesView.list[0].isActive = true
            
            splineFunctionSelector.addItemsWithTitles([IMPCurveFunction.Cubic.rawValue, IMPCurveFunction.Bezier.rawValue, IMPCurveFunction.CatmullRom.rawValue])
        }
        channelSelector.selectItemAtIndex(currentCurveIndex)
    }
}

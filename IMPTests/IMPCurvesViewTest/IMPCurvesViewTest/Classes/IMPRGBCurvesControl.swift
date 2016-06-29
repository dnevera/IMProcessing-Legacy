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


public class IMPRGBCurvesControl: IMPViewBase {
    
    public var backgroundColor:IMPColor? {
        didSet{
            wantsLayer = true
            layer?.backgroundColor = backgroundColor?.CGColor
            curvesSelector.backgroundColor = backgroundColor
            _contentView.backgroundColor = backgroundColor
        }
    }
    
    lazy var _contentView:IMPCurvesView = {
        return IMPCurvesView(frame: self.bounds)
    }()
    
    public var curvesView:IMPCurvesView {get{return _contentView}}
    
    lazy var curvesSelector:IMPPopUpButton = {
        let v = IMPPopUpButton(frame:NSRect(x:10,y:10,width: self.bounds.size.width, height: 40), pullsDown: false)
        v.autoenablesItems = false
        v.target = self
        v.action = #selector(self.selectCurve(_:))
        v.selectItemAtIndex(0)
        return v
    }()
    
    @objc private func selectCurve(sender:NSPopUpButton)  {
        for i in curvesView.list {
            i.isActive = false
        }
        currentCurveIndex = sender.indexOfSelectedItem
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
            addSubview(curvesSelector)
            
            initial = true
            
            curvesSelector.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.snp_top).offset(0)
                make.left.equalTo(self).offset(0)
                make.right.equalTo(self).offset(0)
            }
            
            curvesView.snp_makeConstraints { (make) -> Void in
                make.top.equalTo(self.curvesSelector.snp_bottom).offset(5)
                make.left.equalTo(self).offset(0)
                make.right.equalTo(self).offset(0)
                make.bottom.equalTo(self).offset(0)
            }
            
            curvesView <- IMPCurvesView.CurveInfo(name: "RGB",   color:  IMPColor(red: 1,   green: 1, blue: 1, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: "Red",   color:  IMPColor(red: 1,   green: 0.2, blue: 0.2, alpha: 0.8))
            curvesView <- IMPCurvesView.CurveInfo(name: "Green", color:  IMPColor(red: 0,   green: 1,   blue: 0,   alpha: 0.6))
            curvesView <- IMPCurvesView.CurveInfo(name: "Blue",  color:  IMPColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8))
            
            for el in curvesView.list {
                curvesSelector.addItemWithTitle(el.name)
            }
            
            curvesView.list[0].isActive = true
        }
        curvesSelector.selectItemAtIndex(currentCurveIndex)
    }
}

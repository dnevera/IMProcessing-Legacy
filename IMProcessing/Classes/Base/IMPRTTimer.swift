//
//  IMPRTTimer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 01.06.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Darwin

extension mach_timebase_info{
    static let sharedInstance = mach_timebase_info(0)
    fileprivate init(_:Int) {
        self.init()
        mach_timebase_info(&self)
    }
}

extension UInt64 {
    var nanos:UInt64 {
        let info = mach_timebase_info.sharedInstance
        return  UInt64( self * UInt64(info.numer) / UInt64(info.denom))
    }
    
    var abs:UInt64 {
        let info = mach_timebase_info.sharedInstance
        return  UInt64( (self * UInt64(info.denom)) / UInt64(info.numer))
    }
}

open class IMPRTTimer {
    
    public typealias UpdateHandler = ((_ timestamp:UInt64, _ duration:UInt64)->Void)
    
    open static let nanos_per_usec:UInt64 = 1000
    open static let nanos_per_msec:UInt64 = 1000 * IMPRTTimer.nanos_per_usec
    open static let nanos_per_sec:UInt64  = 1000 * IMPRTTimer.nanos_per_msec
    
    open static let usec_per_msec:UInt64  = 1000
    open static let usec_per_sec:UInt64   = 1000 * IMPRTTimer.usec_per_msec
    
    open static let msec_per_sec:UInt64   = 1000
    
    open let duration:UInt64 // usec
    open let quality:QualityOfService
    
    open var isRunning:Bool {
        return condition
    }
    
    public init(usec: UInt64, quality:QualityOfService = .background, update:@escaping UpdateHandler, complete:UpdateHandler?=nil) {
        duration = usec
        self.quality = quality
        self.update = update
        self.complete = complete
    }
    
    public convenience init(msec: UInt64, quality:QualityOfService = .background, update:@escaping UpdateHandler, complete:UpdateHandler?=nil) {
        self.init(usec: msec * IMPRTTimer.usec_per_msec, quality: quality, update: update, complete: complete)
    }
    
    public convenience init(sec: UInt64, quality:QualityOfService = .background, update:@escaping UpdateHandler, complete:UpdateHandler?=nil) {
        self.init(usec: sec * IMPRTTimer.usec_per_sec, quality: quality, update: update, complete: complete)
    }
    
    open var now:UInt64 {
        return mach_absolute_time()
    }
    
    var info = mach_timebase_info()
    
    var lastUpdate:UInt64 = 0
    var startTime:UInt64 = 0
    open func start()  {
        
        if self.condition {
            return
        }
        
        lastUpdate = 0
        timer_queue.addOperation {
            self.condition = true
            self.startTime = self.now
            while self.condition {
                let t = self.now
                let lu = self.lastUpdate
                self.lastUpdate = t
                self.handler_queue.async {
                    let ts = (t-self.startTime).nanos
                    let ds = (t-(lu == 0 ? t : lu)).nanos
                    self.update(ts, ds )
                }
                self.wait_until(usec: self.duration)
            }
        }
        timer_queue.isSuspended = false
    }
    
    open func stop(){
        condition = false
        timer_queue.isSuspended = true
        timer_queue.cancelAllOperations()
        if let c = self.complete {
            let t = self.now
            let lu = self.lastUpdate
            self.lastUpdate = t
            self.handler_queue.async {
               c(t-self.startTime, t-(lu == 0 ? t : lu) )
            }
        }
    }

    var update:UpdateHandler
    var complete:UpdateHandler?
    
    var condition     = false
    let handler_queue = DispatchQueue(label: IMProcessing.names.prefix + "rttimer.handler", attributes: [])
    lazy var timer_queue:OperationQueue   =  {
        let t = OperationQueue()
        t.name = IMProcessing.names.prefix + "rttimer.queue"
        t.qualityOfService = self.quality
        return t
    }()
    
    deinit{
        stop()
    }
    
    func wait_until(nsec:UInt64){
        mach_wait_until(now + UInt64(nsec).abs)
    }
    
    func wait_until(usec: UInt64) {
        wait_until(nsec: usec*IMPRTTimer.nanos_per_usec)
    }
}

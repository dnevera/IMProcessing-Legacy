//
//  IMPMotionManager.swift
//  Pods
//
//  Created by denis svinarchuk on 26.12.15.
//
//

#if os(iOS)
    
    import UIKit
    import QuartzCore
    import CoreMotion
    
    public class IMPMotionManager {
    
        public struct Position{
            let x:Float
            let y:Float
            let z:Float
            let distance:Float
        }
    
        public struct RotationHandler {
            var index:Int;
            public let closure:((orientation:UIDeviceOrientation) -> Void)
        }
        
        public struct PositionHandler {
            var index:Int;
            public let closure:((position:IMPMotionManager.Position) -> Void)
        }

        public static let sharedInstance = IMPMotionManager()
        
        public var isPaused = false
        
        private var motionRotationHandlers = [RotationHandler]()
        
        public func addRotationObserver(observer:((orientation:UIDeviceOrientation) -> Void)) -> RotationHandler {
            if _motionHandler == nil {
                self.startMotion()
            }
            let h = RotationHandler(index: motionRotationHandlers.count, closure: observer)
            motionRotationHandlers.append(h)
            return h
        }
        
        public func removeRotationObserver(observer:RotationHandler){
            motionRotationHandlers.removeAtIndex(observer.index)
            for i in observer.index..<motionRotationHandlers.count{
                motionRotationHandlers[i].index -= 1
            }
        }
        
        private var motionPositionHandlers = [PositionHandler]()
        
        public func addPositionObserver(observer:((position:IMPMotionManager.Position) -> Void)) -> PositionHandler {
            if _motionHandler == nil {
                self.startMotion()
            }
            let h = PositionHandler(index: motionPositionHandlers.count, closure: observer)
            motionPositionHandlers.append(h)
            return h
        }
        
        public func removePositionObserver(observer:PositionHandler){
            motionPositionHandlers.removeAtIndex(observer.index)
            for i in observer.index..<motionPositionHandlers.count{
                motionPositionHandlers[i].index -= 1
            }
        }

        private init() {
            motionManager = CMMotionManager()
            if motionManager.accelerometerAvailable {
                motionManager.accelerometerUpdateInterval = 0.2
            }
            else{
                deviceOrientationDidChangeTo(.FaceDown)
            }
        }
        
        public func start(){
            if _motionHandler == nil {
                self.startMotion()
            }
        }
        
        public func stop(){
            if  _motionHandler != nil {
                motionManager.stopAccelerometerUpdates()
                _motionHandler = nil
            }
        }
        
        var motionManager:CMMotionManager
        var lastOrientation = UIDeviceOrientation.Unknown
        var currentOrientation = UIDeviceOrientation.Portrait
        
        var lastX = Float(0)
        var lastY = Float(0)
        var lastZ = Float(0)
        var lastDistance = Float (0)
        
        var _motionHandler:CMAccelerometerHandler?
        
        func startMotion () {
            weak var weakSelf = self
            
            _motionHandler =   { (data, error) in
                
                if let accelerometerData = data {
                    
                    if (self.isPaused) {
                        return
                    }
                    
                    weak var selfBlock = weakSelf
                    
                    let xx = accelerometerData.acceleration.x
                    let yy = -accelerometerData.acceleration.y
                    let zz = accelerometerData.acceleration.z
                    
                    let distance = sqrt(pow((weakSelf!.lastX - xx.float), 2) + pow(weakSelf!.lastY + yy.float, 2))
                    
                    if (abs(weakSelf!.lastDistance - distance) > 0.1) {
                        
                        weakSelf!.lastX = accelerometerData.acceleration.x.float
                        weakSelf!.lastY = accelerometerData.acceleration.y.float
                        weakSelf!.lastZ = accelerometerData.acceleration.z.float
                        weakSelf!.lastDistance = distance

                        let position = Position(
                            x: accelerometerData.acceleration.x.float,
                            y: accelerometerData.acceleration.y.float,
                            z: accelerometerData.acceleration.z.float,
                            distance: distance)
                        
                        weakSelf?.devicePositionDidChangeTo(position)
                    }
                    
                    var device_angle = M_PI / 2.0 - atan2(yy, xx)
                    var orientation = UIDeviceOrientation.Unknown
                    
                    if device_angle > M_PI {
                        device_angle -= 2 * M_PI
                    }
                    
                    if ((zz < -0.60) || (zz > 0.60)) {
                        if ( UIDeviceOrientationIsLandscape(selfBlock!.lastOrientation) ){
                            orientation = selfBlock!.lastOrientation
                        }
                        else{
                            orientation = .Unknown
                        }
                    } else {
                        if ( (device_angle > -M_PI_4) && (device_angle < M_PI_4) ){
                            orientation = .Portrait
                        }
                        else if ((device_angle < -M_PI_4) && (device_angle > -3 * M_PI_4)){
                            orientation = .LandscapeLeft
                        }
                        else if ((device_angle > M_PI_4) && (device_angle < 3 * M_PI_4)){
                            orientation = .LandscapeRight
                        }
                        else{
                            orientation = .PortraitUpsideDown
                        }
                    }
                    
                    if (orientation != selfBlock!.lastOrientation) {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            selfBlock?.deviceOrientationDidChangeTo(orientation)
                        })
                    }
                }
                else if error != nil {
                    NSLog(" *** Acceleraometer error: %@", error!)
                }
            }
            
            if let h  = _motionHandler{
                motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: h)
            }
        }
        
        func devicePositionDidChangeTo(position:Position){
            for h in motionPositionHandlers {
                h.closure(position: position)
            }
        }
        
        func deviceOrientationDidChangeTo(orientation:UIDeviceOrientation){
            lastOrientation = orientation
            if currentOrientation == orientation {
                return
            }
            else {
               currentOrientation = lastOrientation
                for h in motionRotationHandlers {
                    h.closure(orientation: lastOrientation)
                }
            }
        }
        
    }
    
#endif

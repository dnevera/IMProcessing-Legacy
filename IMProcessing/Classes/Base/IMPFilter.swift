//
//  IMPFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal


public func report_memory() -> String {
    var info = task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info))/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        let result: kern_return_t = $0.withMemoryRebound(to: integer_t.self, capacity: 1, { (pointer: UnsafeMutablePointer<integer_t>) -> kern_return_t in
            task_info(mach_task_self_,
                      task_flavor_t(TASK_BASIC_INFO),
                      pointer,
                      &count)
        })
        
        return result
    }
    
    if kerr == KERN_SUCCESS {
        return "\(info.resident_size/1024/1024)Mb, \(info.virtual_size/1024/1024)Mb)"
    }
    else {
        return "Error with task_info(): " + (String(cString: mach_error_string(kerr)) )
    }
}


public protocol IMPFilterProtocol:IMPContextProvider {
    var source:IMPImageProvider? {get set}
    var destination:IMPImageProvider? {get}
    var observersEnabled:Bool {get set}
    var dirty:Bool {get set}
    func apply() -> IMPImageProvider
}


private extension Array {
    mutating func swap(_ ind1: Int, _ ind2: Int){
        var temp: Element
        temp = self[ind1]
        self[ind1] = self[ind2]
        self[ind2] = temp
    }
    
}

open class IMPFilter: NSObject,IMPFilterProtocol {
    
    public typealias SourceHandler = ((_ source:IMPImageProvider) -> Void)
    public typealias DestinationHandler = ((_ destination:IMPImageProvider) -> Void)
    public typealias DirtyHandler = (() -> Void)
    
    open var observersEnabled = true {
        didSet {
            for f in filterList {
                f.observersEnabled = observersEnabled
            }
        }
    }
    
    open var context:IMPContext!
    
    open var snapshotEnabled = false {
        didSet{
            if snapshotEnabled == false {
                dirty = true
            }
        }
    }
    
    open var enabled = true {
        didSet{
            
            for filter in filterList {
                filter.enabled = enabled
            }
            
            dirty = true
            
            if enabled == false && oldValue != enabled {
                executeDestinationObservers(source)
            }
        }
    }
    
    open var source:IMPImageProvider?{
        didSet{
            if let s = source{
                s.filter=self
                _destination.orientation =  s.orientation
                executeNewSourceObservers(source)
                dirty = true
            }
        }
    }
    
    open var destination:IMPImageProvider?{
        get{
            if enabled {
                return self.apply()
            }
            else{
                return source
            }
        }
    }
    
    open var destinationSize:MTLSize?{
        didSet{
            if let ov = oldValue{
                if ov != destinationSize! {
                    dirty = true
                }
            }
            else{
                dirty = true
            }
        }
    }
    
    open var _dirty:Bool = false

    open var dirty:Bool {
        
        get {return _dirty }
        
        set(newValue){
        
            if snapshotEnabled && _destination.texture != nil {
                return
            }
            
            if let r = _root {
                if r.dirty != newValue {
                    r.dirty = newValue
                }
            }

            _dirty = newValue
            
            for f in filterList{
                if f.dirty != newValue {
                    f.dirty = newValue
                }
            }
            
            if newValue == true {
                for o in dirtyHandlers{
                    o()
                }
            }
        
        }
        
//        set(newDirty){
//            
//            context.dirty = newDirty
//            
//            for f in filterList{
//                f.dirty = newDirty
//            }
//            
//            if newDirty == true  /*&& context.dirty != true*/ {
//                for o in dirtyHandlers{
//                    o()
//                }
//            }
//        }
//        get{
//            return  context.dirty
//        }
    }
    
    required public init(context: IMPContext) {
        self.context = context
    }
    
    fileprivate var functionList:[IMPFunction] = [IMPFunction]()
    fileprivate var newSourceObservers:[SourceHandler] = [SourceHandler]()
    fileprivate var sourceObservers:[SourceHandler] = [SourceHandler]()
    fileprivate var destinationObservers:[DestinationHandler] = [DestinationHandler]()
    fileprivate var dirtyHandlers:[DirtyHandler] = [DirtyHandler]()
    
    fileprivate var filterList:[IMPFilter] = [IMPFilter]()
    fileprivate var coreImageFilterList:[CIFilter] = [CIFilter]()

    public final func addFunction(_ function:IMPFunction){
        if functionList.contains(function) == false {
            functionList.append(function)
            self.dirty = true
        }
    }
    
    public final func removeFunction(_ function:IMPFunction){
        if let index = functionList.index(of: function) {
            functionList.remove(at: index)
            self.dirty = true
        }
    }
    
    public final func removeAllFunctions(){
        functionList.removeAll()
        self.dirty = true
    }
    
    var _root:IMPFilter? = nil
    open var root:IMPFilter? {
        return _root
    }
    
    func updateNewFilterHandlers(_ filter:IMPFilter)  {
        //filter._root = self
        for o in dirtyHandlers{
            filter.addDirtyObserver(o)
        }
        dirty = true
    }
    
    func removeFilterHandlers(_ filter:IMPFilter) {
        filter._root = nil
        filter.dirtyHandlers.removeAll()
        dirty = true
    }
    
    public final func addFilter(_ filter:IMPFilter){
        if filter._root != nil {
            fatalError("\(filter) already added to \(filter._root)")
            return
        }

        filter._root = self
        
        if filterList.contains(filter) == false {
            filterList.append(filter)
            updateNewFilterHandlers(filter)
        }
    }
    
    public final func removeFilter(_ filter:IMPFilter){
        filter._root = nil
        if let index = filterList.index(of: filter) {
            removeFilterHandlers(filterList.remove(at: index) as IMPFilter)
        }
    }
    
    
    public final func addFilter(ciFilter filter:CIFilter){
        if coreImageFilterList.contains(filter) == false {
            coreImageFilterList.append(filter)
            dirty = true
        }
    }
    
    public final func removeFilter(ciFilter filter:CIFilter){
        if let index = coreImageFilterList.index(of: filter) {
            coreImageFilterList.remove(at: index)
            dirty = true
        }
    }

    public final func removeFromStack() {
        if _root != nil {
            _root?.removeFilter(self)
        }
    }
    
    public final func swapFilters(first:IMPFilter, second:IMPFilter){
        if let index1 = filterList.index(of: first) {
            if let index2 = filterList.index(of: second){
                filterList.swap(index1, index2)
                dirty = true
            }
        }
    }
    
    public final func insertFilter(_ filter:IMPFilter, index:Int){
        
        if filter._root != nil {
            fatalError("\(filter) already added to \(filter._root)")
            return
        }
        
        filter._root = root
        if filterList.contains(filter) == false {
            var i = index
            if i >= filterList.count {
                i = filterList.count
            }
            filterList.insert(filter, at: i)
            updateNewFilterHandlers(filter)
        }
    }
    
    public final func insertFilter(_ filter:IMPFilter, before:IMPFilter){
        if filter._root != nil {
            fatalError("\(filter) already added to \(filter._root)")
            return
        }

        filter._root = self
        
        if filterList.contains(filter) == false {
            if let index = filterList.index(of: before) {
                filterList.insert(filter, at: index)
                updateNewFilterHandlers(filter)
            }
        }
    }
    
    public final func insertFilter(_ filter:IMPFilter, after:IMPFilter){
        if filterList.contains(filter) == false {
            if let index = filterList.index(of: after) {
                filterList.insert(filter, at: index+1)
                updateNewFilterHandlers(filter)
            }
        }
    }
    
    public final func addNewSourceObserver(source observer:@escaping SourceHandler){
        newSourceObservers.append(observer)
    }
    
    public final func addSourceObserver(source observer:@escaping SourceHandler){
        sourceObservers.append(observer)
    }
    
    public final func addDestinationObserver(destination observer:@escaping DestinationHandler){
        destinationObservers.append(observer)
    }
    
    public final func addDirtyObserver(_ observer:@escaping DirtyHandler){
        dirtyHandlers.append(observer)
        for f in filterList{
            f.addDirtyObserver(observer)
        }
    }
    
    open func configure(_ function:IMPFunction, command:MTLComputeCommandEncoder){}
    
    internal func executeNewSourceObservers(_ source:IMPImageProvider?){
        if let s = source{
            for o in newSourceObservers {
                o(s)
            }
        }
    }
    
    internal func executeSourceObservers(_ source:IMPImageProvider?){
        if observersEnabled {
            if let s = source{
                for o in sourceObservers {
                    o(s)
                }
            }
        }
    }
    
    internal func executeDestinationObservers(_ destination:IMPImageProvider?){
        if observersEnabled {
            if let d = destination {
                for o in destinationObservers {
                    o(d)
                }
            }
        }
    }
    
    open func apply() -> IMPImageProvider {
        return doApply()
    }
    
    func newDestinationtexture(destination provider:IMPImageProvider, source input: MTLTexture) -> (MTLTexture, Int, Int) {

        var width  = input.width
        var height = input.height

        if let s = destinationSize {
            width = s.width
            height = s.height
        }
        
        if provider.texture?.width != width || provider.texture?.height != height
            ||
        provider === source
        {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: input.pixelFormat,
                width: width, height: height, mipmapped: false)
            
            if provider.texture != nil && provider.texture !== source {
                provider.texture?.setPurgeableState(.volatile)
            }
            
            return (context.device.makeTexture(descriptor: descriptor), width, height)
        }
        else {
            return (provider.texture!, provider.texture!.width, provider.texture!.height)
        }
    }
    
    open func main(source: IMPImageProvider , destination provider:IMPImageProvider) -> IMPImageProvider? {
        return nil
    }
    
    func internal_main(source: IMPImageProvider , destination provider:IMPImageProvider) -> IMPImageProvider {
        
        var currentFilter = self
        
        var currrentProvider:IMPImageProvider? = nil  //= source
        var previouseTexture:MTLTexture? = nil

        if var input = source.texture {
            
            if functionList.count > 0 {
                
                var width:Int
                var height:Int
                let texture:MTLTexture
                
                (texture, width, height) = self.newDestinationtexture(destination: provider, source: input)
                
                provider.texture = texture
                
                if let output = provider.texture {
                    
                    //
                    // Functions
                    //
                    
                    for function in self.functionList {
                        
                        self.context.execute { (commandBuffer) -> Void in
                            
                            let threadgroupCounts = MTLSizeMake(function.groupSize.width, function.groupSize.height, 1);
                            let threadgroups = MTLSizeMake(
                                (width  + threadgroupCounts.width ) / threadgroupCounts.width ,
                                (height + threadgroupCounts.height) / threadgroupCounts.height,
                                1);
                            
                            let commandEncoder = commandBuffer.makeComputeCommandEncoder()
                            
                            commandEncoder.setComputePipelineState(function.pipeline!)
                            
                            commandEncoder.setTexture(input, at:0)
                            commandEncoder.setTexture(output, at:1)
                            
                            self.configure(function, command: commandEncoder)
                            
                            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts)
                            commandEncoder.endEncoding()
                            
                        }

                        //previouseTexture?.setPurgeableState(.Volatile)
                        if previouseTexture !== source.texture {
                            previouseTexture?.setPurgeableState(.volatile)
                        }
                        previouseTexture = input
                        input = output
                        
                    }
                    
                    currrentProvider = provider
                }
            }
            
            
            if let p = main(source: currrentProvider == nil ? source : currrentProvider!, destination: provider) {
                currrentProvider = p
            }
            
            //
            // Filter chains...
            //
            var previousProvider:IMPImageProvider? = nil
            let index = 0
            for filter in filterList {
                
                filter.source = currrentProvider == nil ? source : currrentProvider!
                currrentProvider = filter.destination!

                if previouseTexture !== source.texture {
                    previousProvider?.texture?.setPurgeableState(.volatile)
                }
                previousProvider = currrentProvider
            }
            
            if #available(iOS 9.0, *) {
                
                if coreImageFilterList.count > 0 {
                    
                    guard let t = currrentProvider?.texture == nil ? source.texture! : currrentProvider?.texture! else {
                        return source
                    }
                    
                    
                    //
                    // create core image from current texture
                    //
                    var inputImage = CIImage(mtlTexture: t, options: nil)
                    
                    //
                    // apply CIFilter chains
                    //
                    for filter in coreImageFilterList {
                        filter.setValue(inputImage, forKey: kCIInputImageKey)
                        inputImage = filter.outputImage!
                    }
                    
                    let imageSize = inputImage?.extent.size
                    
                    //
                    // render image to texture back
                    //
                    self.context.execute{ (commandBuffer) in
                        
                        let width  = Int((imageSize?.width)!)
                        let height = Int((imageSize?.height)!)
                        
                        //
                        // prepare new texture
                        //
                        if currrentProvider?.texture?.width != width || currrentProvider?.texture?.height != height
                        {
                            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                                pixelFormat: input.pixelFormat,
                                width: width, height: height, mipmapped: false)
                            
                            if currrentProvider?.texture != nil {
                                currrentProvider?.texture?.setPurgeableState(.volatile)
                            }
                            
                            currrentProvider = IMPImageProvider(context: self.context)
                            
                            currrentProvider?.texture = self.context.device.makeTexture(descriptor: descriptor)
                        }
                        
                        
                        //
                        // render image to new texture
                        //
                        self.context.coreImage?.render(inputImage!,
                            to: currrentProvider!.texture!,
                            commandBuffer: commandBuffer,
                            bounds: (inputImage?.extent)!,
                            colorSpace: self.colorSpace)
                    }
                }
            }
        }
        
        return  currrentProvider == nil ? source : currrentProvider!
    }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    fileprivate lazy var _destination:IMPImageProvider = {
        return IMPImageProvider(context: self.context)
    }()

    func doApply() -> IMPImageProvider {
        
        if snapshotEnabled && _destination.texture != nil {
            return _destination
        }
        
        if let s = self.source{
            if dirty {
                
                executeSourceObservers(source)
                
                _destination = internal_main(source:  s, destination: _destination)
                
                executeDestinationObservers(_destination)
            }
        }
        
        dirty = false
    
        return _destination
    }

    open func flush() {
        for f in filterList {
            f.flush()
        }
        _destination.texture?.setPurgeableState(.empty)
        _destination.texture = nil
        source = nil
    }
    
    deinit {
        flush()
    }
}

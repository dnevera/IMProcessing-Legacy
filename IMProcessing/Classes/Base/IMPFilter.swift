//
//  IMPFilter.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 12.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
    import MetalPerformanceShaders
#else
    import Cocoa
#endif

import Metal
import CoreImage

public protocol IMPFilterProtocol:IMPContextProvider, IMPDestinationSizeProvider {
    
    var  name:             String?           {get    }
    var  source:           IMPImageProvider? {get set}
    var  destination:      IMPImageProvider  {get    }
    var  observersEnabled: Bool              {get set}
    var  enabled:          Bool              {get set}
    var  dirty:            Bool              {get set}
    
    init(context:IMPContext, name: String?)
    
    func configure()
}

open class IMPFilter: IMPFilterProtocol, /*IMPDestinationSizeProvider,*/ Equatable {
    
    // MARK: - Type aliases
    
    public enum RegisteringError: Error {
        case AlreadyExist
        case NotFound
        case OutOfRangeInsertion
    }
    
    public typealias FailHandler     = ((_ error:RegisteringError)->Void)
    public typealias CompleteHandler = ((_ image:IMPImageProvider)->Void)
    public typealias UpdateHandler   = ((_ image:IMPImageProvider) -> Void)
    public typealias FilterHandler   = ((_ filter:IMPFilter, _ source:IMPImageProvider?, _ destination:IMPImageProvider) -> Void)
    
    // MARK: - public
    
    open var prefersRendering:Bool  {
        return  context.supportsGPUv2
    }
    
    public var name: String? = nil
    
    public var context: IMPContext
    
    public var observersEnabled: Bool = true
    
    public var source: IMPImageProvider? = nil {
        didSet{
            oldValue?.texture?.setPurgeableState(.volatile)
            executeNewSourceObservers(source: source)
        }
    }
    
    public var destination: IMPImageProvider {
        return apply(result: _destination)
    }
    
    public var destinationSize: NSSize?
    
    public required init(context:IMPContext, name: String? = nil) {
        self.context = context
        self.name = name
        defer {
            configure()
        }
    }
    
    public var enabled: Bool = true {
        didSet{
            dirty = true
            executeEnablingObservers(filter: self)
        }
    }
    
    public var dirty: Bool = false {
        didSet{
            if dirty {
                executeDirtyObservers(filter: self)
            }
            for c in self.coreImageFilterList {
                c.filter?.dirty = dirty
            }
        }
    }
    
    public var chain:[FilterContainer] {
        return coreImageFilterList
    }
    
    public func extendName(suffix:String) {
        name = {
            if name == nil {
                return self.context.uid + ":" + suffix
            }
            return self.name! + ":" + suffix
        }()
    }
    
    open func configure(){}
    
    public func flush(){
        source?.image = nil
        _destination.image = nil
        for c in coreImageFilterList {
            if let f = c.filter {
                f.flush()
            }
            else if let f = c.cifilter as? IMPCIFilter{
                f.flush()
            }
        }
    }
    
    public func process(with resampleSize:NSSize? = nil){
        destinationSize = resampleSize
        _destination =  apply(result: _destination)
    }
    
    private func apply(result:IMPImageProvider) -> IMPImageProvider {
        
        guard let source = self.source else {
            dirty = false
            return result
        }
        
        guard let size = source.size else {
            dirty = false
            return result
        }
        
        var result = result
        
        if fmax(size.width, size.height) <= IMPContext.maximumTextureSize.cgfloat {
            
            if enabled == false {
                result.texture = source.texture
                dirty = false
                return result
            }
            
            let pixelFormat = result.texture?.pixelFormat ?? source.texture?.pixelFormat ?? IMProcessing.colors.pixelFormat

            let newSize = destinationSize ?? size
            
//            context.execute(.sync, complete: {
//                
//                self.executeDestinationObservers(destination: result)
//                self.dirty = false
//
//            }, action: { (commandBuffer) in
//                
//                result.texture = self.apply(size:newSize, pixelFormat:pixelFormat, commandBuffer: commandBuffer)
//                
//            })

            result.texture = self.apply(size:newSize, pixelFormat:pixelFormat, commandBuffer: nil)
            self.executeDestinationObservers(destination: result)
            self.dirty = false

            return result
        }
        
        var scaledImage = source.image
        
        if let newsize = destinationSize ?? source.size,
            let sImage = scaledImage
        {
            let originX = sImage.extent.origin.x
            let originY = sImage.extent.origin.y
            
            let scaleX = newsize.width /  sImage.extent.width
            let scaleY = newsize.height / sImage.extent.height
            let scale = min(scaleX, scaleY)
            
            let transform = CGAffineTransform.identity.translatedBy(x: -originX, y: -originY)
            scaledImage = sImage.applying(transform.scaledBy(x: scale, y: scale))
        }
        
        result.image = scaledImage
        
        if enabled == false {
            dirty = false
            return result
        }
        
        //
        // apply CIFilter chains
        //
        for c in coreImageFilterList {
            if let filter = c.cifilter {
                filter.setValue(result.image?.copy(), forKey: kCIInputImageKey)
                result.image = filter.outputImage
            }
            else if let filter = c.filter {
                filter.source = IMPImage(context: filter.context, provider: result)
                result = filter.destination
            }
            c.complete?(result)
        }
        
        executeDestinationObservers(destination: result)
        
        dirty = false
        
        return result
    }
    
    //
    // optimize processing when image < GPU SIZE
    //
    private func apply(size:NSSize?, pixelFormat:MTLPixelFormat, commandBuffer: MTLCommandBuffer? = nil) -> MTLTexture? {
        
        guard let input = self.source?.texture else { return nil}
        
        guard let colorSpace =  source?.colorSpace else { return nil }
        
        var currentResult = input
        
        for c in coreImageFilterList {
            
            context.execute(.sync, complete: { 
                
                if let filter = c.filter {
                    filter.executeDestinationObservers(destination: filter._destination)
                }
                
            }, fail: {
                
                NSLog("IMPFilter applying failed .... ")
                
            }, action: { (commandBuffer) in
                
                let device = commandBuffer.device
                
                if let filter = c.cifilter {
                    
                    if filter.isKind(of: IMPCIFilter.self) {
                        
                        guard let f = (filter as? IMPCIFilter) else {
                            return
                        }
                        
                        let dsize = f.destinationSize ?? currentResult.cgsize
                        
                        let tmp:MTLTexture = device.make2DTexture(size: dsize, pixelFormat: pixelFormat)
                        
                        if f.source == nil {
                            f.source = IMPImage(context: self.context)
                        }
                        
                        f.source?.texture = currentResult
                        f.process(to: tmp, commandBuffer: commandBuffer)
                        
                        currentResult = tmp
                    }
                    else {
                        let dsize = currentResult.cgsize
                        let tmp:MTLTexture = device.make2DTexture(size: dsize, pixelFormat: pixelFormat)
                        
                        filter.setValue(CIImage(mtlTexture: currentResult,
                                                options:  [kCIImageColorSpace: colorSpace]),
                                        forKey: kCIInputImageKey)
                        
                        guard let image = filter.outputImage else { return }
                        
                        self.context.coreImage?.render(image,
                                                       to: tmp,
                                                       commandBuffer: commandBuffer,
                                                       bounds: image.extent,
                                                       colorSpace: colorSpace)
                        
                        currentResult = tmp
                    }
                }
                else if let filter = c.filter {
                    
                    if filter.source == nil {
                        filter.source = IMPImage(context: self.context)
                    }
                    
                    filter.source?.texture = currentResult
                    if let t = filter.apply(size: nil,
                                            pixelFormat: pixelFormat,
                                            commandBuffer: commandBuffer){
                        currentResult = t
                    }
                    else {
                        return
                    }
                    
                    filter._destination.texture = currentResult

                }
            })
            
            if let comlete = c.complete {
                comlete(IMPImage(context:self.context, texture: currentResult))
            }
        }
        return currentResult
    }
    
    
    public static func == (lhs: IMPFilter, rhs: IMPFilter) -> Bool {
        if let ln = lhs.name, let rn = rhs.name {
            return ln == rn
        }
        return lhs === rhs
    }
    
    //
    // MARK: - observers
    //
    public func addObserver(newSource observer:@escaping UpdateHandler){
        newSourceObservers.append(observer)
    }
    public func addObserver(destinationUpdated observer:@escaping UpdateHandler){
        destinationObservers.append(observer)
    }
    public func addObserver(dirty observer:@escaping FilterHandler){
        root?.dirtyObservers.append(observer)
        dirtyObservers.append(observer)
    }
    public func addObserver(enabling observer:@escaping FilterHandler){
        enablingObservers.append(observer)
    }
    
    //
    // MARK: - main filter chain operations
    //
    public func add(filter: IMPFilter,
                    fail: FailHandler?=nil,
                    complete: CompleteHandler?=nil) {
        filter.root = self
        appendFilter(filter: FilterContainer(cifilter: nil, filter: filter, complete:complete),
                     fail: { (error) in
                        filter.root = nil
                        fail?(error)
        })
    }
    
    public func insert(filter: IMPFilter,
                       at index: Int,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        filter.root = self
        insertFilter(filter: FilterContainer(cifilter: nil, filter: filter, complete:complete), index:index,
                     fail: { (error) in
                        filter.root = nil
                        fail?(error)
        })
    }
    
    
    public func insert(filter: IMPFilter,
                       after filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let (index, contains) = findFilter(name: filterName, isAfter: true, fail: fail)
        if contains {
            filter.root = self
            insertFilter(filter: FilterContainer(cifilter: nil, filter: filter, complete:complete), index:index,
                         fail: { (error) in
                            filter.root = nil
                            fail?(error)
            })
        }
    }
    
    public func insert(filter: IMPFilter,
                       before filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        
        let (index, contains) = findFilter(name: filterName, isAfter: false, fail: fail)
        if contains {
            filter.root = self
            insertFilter(filter: FilterContainer(cifilter: nil, filter: filter, complete:complete), index:index,
                         fail: { (error) in
                            filter.root = nil
                            fail?(error)
            })
        }
    }
    
    
    //
    // MARK: - create filters chain
    //
    public func add(function: IMPFunction,
                    fail: FailHandler?=nil,
                    complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLKernel.register(function: function)
        appendFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), fail: fail)
    }
    
    public func add(shader: IMPShader,
                    fail: FailHandler?=nil,
                    complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLShader.register(shader: shader)
        appendFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), fail: fail)
    }
    
    public func add(function name: String,
                    fail: FailHandler?=nil,
                    complete: CompleteHandler?=nil) {
        add(function: IMPFunction(context: context, kernelName: name), fail: fail, complete: complete)
    }
    
    public func add(vertex: String, fragment: String,
                    fail: FailHandler?=nil,
                    complete: CompleteHandler?=nil) {
        add(shader: IMPShader(context: context, vertexName: vertex, fragmentName: fragment), fail: fail, complete: complete)
    }
    
    public func add(filter: CIFilter,
                    fail: FailHandler?=nil,
                    complete: CompleteHandler?=nil)  {
        appendFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), fail: fail)
    }
    #if os(iOS)
    public func add(mps: MPSUnaryImageKernel, withName: String? = nil,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil)   {
    if let newName = withName {
    mps.label = newName
    }
    guard let _ = mps.label else {
    fatalError(" *** IMPFilter add(mps:withName:): mps kernel should contain defined label property or withName should be specified...")
    }
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: IMPMPSUnaryKernel.make(kernel: mps))
    appendFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), fail: fail)
    }
    
    public func add(mps: IMPMPSUnaryKernelProvider,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil)   {
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: mps)
    appendFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), fail: fail)
    }
    #endif
    
    
    //
    // MARK: - insertion at index
    //
    public func insert(function: IMPFunction,
                       at index: Int,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLKernel.register(function: function)
        insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
    }
    
    public func insert(shader: IMPShader,
                       at index: Int,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLShader.register(shader: shader)
        insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
    }
    
    public func insert(function name: String,
                       at index: Int,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        insert(function: IMPFunction(context:context, kernelName:name),
               at: index, fail: fail, complete: complete)
    }
    
    public func insert(vertex: String, fragment: String,
                       at index: Int,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        insert(shader: IMPShader(context:context, vertexName: vertex, fragmentName:fragment),
               at: index, fail: fail, complete: complete)
    }
    
    public func insert(filter: CIFilter,
                       at index: Int,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
    }
    
    #if os(iOS)
    public func insert(mps: MPSUnaryImageKernel, withName: String? = nil,
    at index: Int,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil) {
    if let newName = withName {
    mps.label = newName
    }
    guard let _ = mps.label else {
    fatalError(" *** IMPFilter insert(mps:withName:): mps kernel should contain defined label property or withName should be specified...")
    }
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: IMPMPSUnaryKernel.make(kernel: mps))
    insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
    }
    
    public func insert(mps: IMPMPSUnaryKernelProvider,
    at index: Int,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil) {
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: mps)
    insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
    }
    #endif
    
    //
    // MARK: - insertion before / after
    //
    
    // Insert CIFilter before/after
    public func insert(filter: CIFilter,
                       before filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        
        let (index, contains) = findFilter(name: filterName, isAfter: false, fail: fail)
        if contains {
            insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
        }
    }
    
    public func insert(filter: CIFilter,
                       after filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        
        let (index, contains) = findFilter(name: filterName, isAfter: true, fail: fail)
        if contains {
            insertFilter(filter: FilterContainer(cifilter: filter, filter: nil, complete:complete), index:index, fail: fail)
        }
    }
    
    // Insert IMPFunction before/after
    public func insert(function: IMPFunction,
                       after filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLKernel.register(function: function)
        insert(filter: filter, after: filterName, fail: fail, complete: complete)
    }
    
    // Insert IMPFunction before/after
    public func insert(shader: IMPShader,
                       after filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLShader.register(shader: shader)
        insert(filter: filter, after: filterName, fail: fail, complete: complete)
    }
    
    public func insert(function: IMPFunction,
                       before filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLKernel.register(function: function)
        insert(filter: filter, before: filterName, fail: fail, complete: complete)
    }
    
    public func insert(shader: IMPShader,
                       before filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let filter = IMPCoreImageMTLShader.register(shader: shader)
        insert(filter: filter, before: filterName, fail: fail, complete: complete)
    }
    
    // Insert IMPFunction by name before/after
    public func insert(function name: String,
                       after filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let function = IMPFunction(context: context, kernelName: name)
        let filter = IMPCoreImageMTLKernel.register(function: function)
        insert(filter: filter, after: filterName, fail: fail, complete: complete)
    }
    
    public func insert(vertex: String, fragment: String,
                       after filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        insert(shader: IMPShader(context:context, vertexName:vertex, fragmentName:fragment),
               after: filterName, fail: fail, complete: complete)
    }
    
    public func insert(function name: String,
                       before filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        let function = IMPFunction(context: context, kernelName: name)
        let filter = IMPCoreImageMTLKernel.register(function: function)
        insert(filter: filter, before: filterName, fail: fail, complete: complete)
    }
    
    public func insert(vertex: String, fragment: String,
                       before filterName: String,
                       fail: FailHandler?=nil,
                       complete: CompleteHandler?=nil) {
        insert(shader: IMPShader(context:context, vertexName:vertex, fragmentName:fragment),
               before: filterName, fail: fail, complete: complete)
    }
    
    // Insert MPS before/after
    #if os(iOS)
    public func insert(mps: MPSUnaryImageKernel, withName: String? = nil,
    after filterName: String,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil) {
    if let newName = withName {
    mps.label = newName
    }
    guard let _ = mps.label else {
    fatalError(" *** IMPFilter insert(mps:withName:): mps kernel should contain defined label property or withName should be specified...")
    }
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: IMPMPSUnaryKernel.make(kernel: mps))
    insert(filter: filter, after: filterName, fail: fail, complete: complete)
    }
    
    public func insert(mps: IMPMPSUnaryKernelProvider,
    after filterName: String,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil) {
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: mps)
    insert(filter: filter, after: filterName, fail: fail, complete: complete)
    }
    
    public func insert(mps: MPSUnaryImageKernel, withName: String? = nil,
    before filterName: String,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil) {
    if let newName = withName {
    mps.label = newName
    }
    guard let _ = mps.label else {
    fatalError(" *** IMPFilter insert(mps:withName:): mps kernel should contain defined label property or withName should be specified...")
    }
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: IMPMPSUnaryKernel.make(kernel: mps))
    insert(filter: filter, before: filterName, fail: fail, complete: complete)
    }
    
    public func insert(mps: IMPMPSUnaryKernelProvider,
    before filterName: String,
    fail: FailHandler?=nil,
    complete: CompleteHandler?=nil) {
    let filter = IMPCoreImageMPSUnaryKernel.register(mps: mps)
    insert(filter: filter, before: filterName, fail: fail, complete: complete)
    }
    #endif
    
    //
    // MARK: - remove filter from chain
    //
    public func remove(function: IMPFunction) {
        remove(filter: function.name)
    }
    
    public func remove(shader: IMPShader) {
        remove(filter: shader.name)
    }
    
    public func remove(filter name: String){
        var index = 0
        for f in coreImageFilterList{
            if let filter = f.cifilter {
                if filter.name == name {
                    coreImageFilterList.remove(at: index)
                    break
                }
            }
            else if let filter = f.filter {
                if let fname = filter.name {
                    if fname == name {
                        coreImageFilterList.remove(at: index)
                        break
                    }
                }
            }
            index += 1
        }
    }
    
    #if os(iOS)
    public func remove(mps: MPSUnaryImageKernel) {
    guard let name = mps.label else {
    fatalError(" *** IMPFilter: remove(mps:) mps kernel should contain defined label property...")
    }
    remove(filter: name)
    }
    
    public func remove(mps: IMPMPSUnaryKernelProvider) {
    remove(filter: mps.name)
    }
    #endif
    
    public func remove(filter: CIFilter) {
        remove(filter: filter.name)
    }
    
    public func remove(filter matchedFilter:IMPFilter){
        var index = 0
        for f in coreImageFilterList{
            if let filter = f.filter {
                if filter == matchedFilter {
                    coreImageFilterList.remove(at: index)
                    break
                }
            }
            index += 1
        }
    }
    
    public func removeAll(){
        coreImageFilterList.removeAll()
    }
    
    //
    // MARK: - internal
    //
    internal func executeNewSourceObservers(source:IMPImageProvider?){
        if let s = source{
            for o in newSourceObservers {
                o(s)
            }
        }
    }
    
    internal func executeDestinationObservers(destination:IMPImageProvider?){
        if observersEnabled {
            if let d = destination {
                for o in destinationObservers {
                    o(d)
                }
            }
        }
    }
    
    internal func executeDirtyObservers(filter:IMPFilter){
        if observersEnabled {
            root?.executeDirtyObservers(filter: self)
            for o in dirtyObservers {
                o(filter,filter.source,filter._destination)
            }
        }
    }
    
    internal func executeEnablingObservers(filter:IMPFilter){
        if observersEnabled {
            for o in enablingObservers {
                o(filter,filter.source,filter._destination)
            }
        }
    }
    
    
    //
    // MARK: - private
    //
    
    private var root:IMPFilter?
    
    private lazy var _destination:IMPImageProvider   = IMPImage(context: self.context)
    private var newSourceObservers:[UpdateHandler]   = [UpdateHandler]()
    private var destinationObservers:[UpdateHandler] = [UpdateHandler]()
    private var dirtyObservers:[FilterHandler]       = [FilterHandler]()
    private var enablingObservers:[FilterHandler]    = [FilterHandler]()
    
    private var coreImageFilterList:[FilterContainer] = [FilterContainer]()
    
    public struct FilterContainer: Equatable {
        
        var cifilter:CIFilter?        = nil
        var filter:IMPFilter?         = nil
        var complete:CompleteHandler? = nil
        
        public static func == (lhs: FilterContainer, rhs: FilterContainer) -> Bool {
            if let lf = lhs.cifilter, let rf = rhs.cifilter {
                return lf.name == rf.name
            }
            else if let lf = lhs.filter, let rf = rhs.filter {
                return lf == rf
            }
            return false
        }
    }
    
    private func appendFilter(filter:FilterContainer,
                              fail: FailHandler?=nil){
        if coreImageFilterList.contains(filter) == false {
            coreImageFilterList.append(filter)
        }
        else{
            fail?(.AlreadyExist)
        }
    }
    
    private func insertFilter(filter:FilterContainer,
                              index: Int,
                              fail: FailHandler?=nil){
        if coreImageFilterList.contains(filter) == false {
            coreImageFilterList.insert(filter, at: index)
        }
        else{
            fail?(.AlreadyExist)
        }
    }
    
    private func findFilter(name: String, isAfter: Bool, fail: FailHandler?=nil) -> (Int,Bool) {
        var index = 0
        var contains = false
        for f in coreImageFilterList{
            if let filter = f.filter{
                if filter.name == name {
                    contains = true
                    if isAfter {
                        index += 1
                    }
                    break
                }
            } else if let filter = f.cifilter {
                if filter.name == name {
                    contains = true
                    if isAfter {
                        index += 1
                    }
                    break
                }
            }
            index += 1
        }
        if !contains {
            fail?(.NotFound)
            return (0,false)
        }
        return (index,true)
    }
    
    private lazy var resampleKernel:IMPFunction = IMPFunction(context: self.context, name: self.name ?? "-" + "Common resampler kernel")
    private lazy var resampleShader:IMPShader = IMPShader(context: self.context, name: self.name ?? "-" + "Common resampler shader")
    
    private lazy var resampler:IMPCIFilter = {
        let v = self.prefersRendering ?
            IMPCoreImageMTLShader.register(shader: self.resampleShader)  :
            IMPCoreImageMTLKernel.register(function: self.resampleKernel)
        v.source = IMPImage(context: self.context)
        //v.destination = IMPImage(context: self.context)
        return v
    }()
}

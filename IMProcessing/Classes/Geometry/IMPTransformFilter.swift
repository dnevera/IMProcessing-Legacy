//
//  IMPTransformFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

/// Transform filter can be imagine as a photo plate tool 
typealias IMPPhotoPlateFilter = IMPTransformFilter

/// Image textured on the model of Rendering Node is a Cube Node with virtual depth == 0
open class IMPPhotoPlateNode: IMPRenderNode {
    
    /// Cropping the plate region
    open var region = IMPRegion() {
        didSet{
            if
                region.left != oldValue.left ||
                    region.right != oldValue.right ||
                    region.top != oldValue.top ||
                    region.bottom != oldValue.bottom
            {
                vertices = IMPPhotoPlate(aspect: aspect, region: region)
            }
        }
    }
    
    var resetAspect:Bool = true
    
    override open var aspect:Float {
        didSet{
            if super.aspect != oldValue || resetAspect {
                super.aspect = aspect
                resetAspect = false
                vertices = IMPPhotoPlate(aspect: aspect, region: self.region)
            }
        }
    }
    
    public init(context: IMPContext, aspectRatio:Float, region:IMPRegion = IMPRegion()){
        super.init(context: context, vertices: IMPPhotoPlate(aspect: aspectRatio, region: self.region))
    }
}

public extension IMPGraphics {
    public convenience init(context: IMPContext, fragment: String) {
        self.init(context: context, vertex: "vertex_transformation", fragment: fragment)
    }
}

/// Photo plate transformation filter
open class IMPTransformFilter: IMPFilter, IMPGraphicsProvider {

    open var backgroundColor:IMPColor = IMPColor.white

    open override var source: IMPImageProvider? {
        didSet {
            updatePlateAspect(region)
        }
    }
    
    open var keepAspectRatio = true
    
    //public var graphics:IMPGraphics!

    fileprivate var graphicsList:[IMPGraphics] = [IMPGraphics]()

    public final func addGraphics(_ graphics:IMPGraphics){
        if graphicsList.contains(graphics) == false {
            graphicsList.append(graphics)
            self.dirty = true
        }
    }
    
    public final func removeGraphics(_ graphics:IMPGraphics){
        if let index = graphicsList.index(of: graphics) {
            graphicsList.remove(at: index)
            self.dirty = true
        }
    }
    
    //required public init(context: IMPContext, vertex:String, fragment:String) {
    //    super.init(context: context)
    //    //graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    //}
    
    public required init(context: IMPContext) {
        super.init(context: context)
        //self.init(context: context, vertex: "vertex_transformation", fragment: "fragment_transformation")
        addGraphics(IMPGraphics(context: context, vertex: "vertex_transformation", fragment: "fragment_transformation"))
    }    
    
    open var viewPortSize: MTLSize? {
        didSet{
            plate.aspect = self.keepAspectRatio ? viewPortSize!.width.float/viewPortSize!.height.float : 1
            dirty = true
        }
    }
    
    open override func main(source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider? {
        var inputSource = source
        for graphics in graphicsList{
            self.context.execute{ (commandBuffer) -> Void in
                
                if let inputTexture = inputSource.texture {
                    
                    var width  = inputTexture.width.float
                    var height = inputTexture.height.float
                    
                    if let s = self.viewPortSize {
                        width = s.width.float
                        height = s.height.float
                    }
                    
                    width  -= width  * (self.plate.region.left   + self.plate.region.right);
                    height -= height * (self.plate.region.bottom + self.plate.region.top);
                    
                    if width.int != provider.texture?.width || height.int != provider.texture?.height
                        ||
                    inputSource === provider
                    {
                        
                        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                            pixelFormat: inputTexture.pixelFormat,
                            width: width.int, height: height.int,
                            mipmapped: false)
                        
                        provider.texture = self.context.device.makeTexture(descriptor: descriptor)
                    }
                    
                    self.plate.render(commandBuffer,
                        pipelineState: graphics.pipeline!,
                        source: source,
                        destination: provider,
                        clearColor: self.clearColor, configure: { (command) in
                            self.configureGraphics(graphics, command: command)
                    })
                }
                inputSource = provider
            }
        }
        return provider
    }
    
    open var aspect:Float {
        return plate.aspect
    }
    
    open var model:IMPTransfromModel {
            return plate.model
    }

    open var identityModel:IMPTransfromModel {
        return plate.identityModel
    }
    
    open func configureGraphics(_ graphics:IMPGraphics, command:MTLRenderCommandEncoder){}
    
    ///  Rotate plate on angle in radians arround axis
    ///
    ///  - parameter vector: angle in radians for x,y,z axis
    open var angle:float3 {
        set {
            plate.angle = newValue
            dirty = true
        }
        get {
            return plate.angle
        }
    }

    ///  Scale plate
    ///
    ///  - parameter vector: x,y,z scale factor
    open var scale:float3 {
        set {
            plate.scale = newValue
            dirty = true
        }
        get {
            return plate.scale
        }
    }
    
    ///  Scale plate with global 2D factor
    ///
    ///  - parameter factor:
    open func scale(factor f:Float){
        plate.scale = float3(f,f,1)
        dirty = true
    }
    
    
    ///  Move plate with vector
    ///
    ///  - parameter vector: vector
    open var translation: float2 {
        set{
            plate.translation = newValue
            dirty = true
        }
        get {
            return plate.translation
        }
    }
    
    ///  Cut the plate with crop region
    ///
    ///  - parameter region: crop region
    open var region:IMPRegion {
        set {
            guard (source != nil) else {return}
            updatePlateAspect(newValue)
            plate.region = newValue
            dirty = true
        }
        get {
            return plate.region
        }
    }
    
    /// Set/get reflection
    open var reflection:(horizontal:IMPRenderNode.ReflectMode, vertical:IMPRenderNode.ReflectMode) {
        set{
            plate.reflectMode = newValue
            dirty = true
        }
        get{
            return plate.reflectMode
        }
    }
        
    lazy var plate:PhotoPlate = {
        return PhotoPlate(context: self.context, aspectRatio:4/3)
    }()
    
    func updatePlateAspect(_ region:IMPRegion)  {
        if let s = source {
            let width  = s.width - s.width  * (region.left   + region.right);
            let height = s.height - s.height * (region.bottom + region.top);
            plate.aspect = self.keepAspectRatio ? width/height : 1
        }
    }
    
    // Plate is a cube with virtual depth == 0
    class PhotoPlate: IMPPhotoPlateNode {}
}


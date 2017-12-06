//
//  IMPImage+CGImage.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
    extension IMPImage {
        var CGImage:CGImageRef?{
            get {
                var imageRect:CGRect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
                return self.CGImageForProposedRect(&imageRect, context: nil, hints: nil)
            }
        }
    }
#endif

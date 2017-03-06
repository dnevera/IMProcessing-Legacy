//
//  ViewController.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 06.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.addSubview(imageView)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


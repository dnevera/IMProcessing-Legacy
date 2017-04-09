//
//  AppDelegate.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    
    @IBOutlet weak var OpenFileMenuItem: NSMenuItem!
    
    @IBOutlet weak var OpenRecentMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func openFileHandler(_ sender: NSMenuItem) {
        IMPFileManager.sharedInstance.openFilePanel(types: ["png", "PNG", "tiff", "tif", "TIF", "TIFF", "jpg", "JPG", "jpeg", "JPEG"])
    }

}


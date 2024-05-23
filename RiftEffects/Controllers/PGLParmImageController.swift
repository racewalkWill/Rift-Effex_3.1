//
//  PGLParmImageController.swift
//  RiftEffects
//
//  Created by Will on 5/6/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

class PGLParmImageController: PGLTwoColumnSplitController {
    // handles segues for iPad/iPhone segue paths
    // iPad does not use the two container view
    // iPhone shows parm and image controlls inside the two containers of the view
    
        // 2024-05-22 changed to use the super class PGLColumns.control and PGLColumns.imageViewer
        // removed duplicate vars var containerImageController,containerParmController
        // two vars pointed to the same controller - memory issue

    deinit {
//        releaseVars()
        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
    }
    
    override func viewDidLoad() {
        var containerImageController: PGLImageController?
        var containerParmController: PGLSelectParmController?
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewDidLoad()

        let storyboard = UIStoryboard(name: "Main", bundle: .main)

        containerParmController = storyboard.instantiateViewController(withIdentifier: "ParmSettingsViewController") as? PGLSelectParmController

        containerImageController = storyboard.instantiateViewController(withIdentifier: "PGLImageController") as? PGLCompactImageController
        if (containerImageController == nil) || (containerParmController == nil) {
            return // give up no controller
        }

        loadViewColumns(controller: containerParmController!, imageViewer: containerImageController! )

        // notice Missing filterImageController calls to
        //   setMoreBtnMenu()
        //  AND navigationController?.isToolbarHidden = true
        // stackImageController has a setUpdateEditButton()

    }
    

    override func viewDidDisappear(_ animated: Bool) {
        guard let containerImageController = imageController()
            else { return }
        guard let containerParmController = columns?.control as? PGLSelectParmController
        else {return }
        containerImageController.releaseVars()
        containerImageController.removeFromParent()


        containerParmController.removeFromParent()
        columns = nil
    }

    @IBAction func parmImageBackBtn(_ sender: UIBarButtonItem) {
        // now in the twoContainer mode on the iphone
            // navigation pop needs to trigger the parent popViewController
            // so that it moves back to the stack controller
        guard let myNav = self.navigationController else { return }
        Logger(subsystem: LogSubsystem, category: LogNavigation).info( "\("#parmImageBackBtn " + String(describing: self))")

        myNav.popViewController(animated: true )

    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        let segueId = segue.identifier
        
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function) + \(String(describing: segueId))")
        /// dispatch back to child parm controller 
        guard let containerParmController = columns?.control as? PGLSelectParmController
        else {return }
        containerParmController.prepare(for: segue, sender: sender)


    }


}

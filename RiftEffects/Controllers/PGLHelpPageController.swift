//
//  PGLHelpPageController.swift
//  Surreality
//
//  Created by Will on 2/4/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//
// from PhotoScroll by Razeware LLC
/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation

import UIKit
import os

    /// Help only shows automatically on first startup
    ///  then shows from ? button tap
class PGLHelpPageController: UIPageViewController {
    // pop up modal 4 pages intro pics with comments
    // PGLImageController checks for first startup and shows this Help
    // PGLImageController turns off first startup boolean

    struct HelpInfo {
        var helpTitle: String
        var iPhoneImage: String
        var iPadImage: String
        var helpText: String


    }
    var helpSections: [ Int:HelpInfo ] = [:]
    var currentIndex: Int!
    var iPhoneFormat = true
    

    fileprivate func loadHelpInfo() {
        helpSections[0] = HelpInfo(helpTitle: "Roadmap", iPhoneImage: "iPhone0-Roadmap", iPadImage: "iPad0-RoadMap",
                                   helpText: "PICK an image from the Library. TAP Effex Filter. SWIPE filter to open Settings.")

        helpSections[1] = HelpInfo(helpTitle: "Guide", iPhoneImage: "iPhone01-Guide", iPadImage: "iPad1-Guide",
                                   helpText: "Tap 'Guide' & follow pointer steps")

        helpSections[2] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone1-SettingsOpen", iPadImage: "iPad2-OpenImagePicker",
                                   helpText: "SWIPE left 'Open' to Settings for that filter  -->")

        helpSections[3] = HelpInfo(helpTitle: "Settings", iPhoneImage: "iPhone2-OpenImagePicker", iPadImage: "iPad3-AddFilter",
                                   helpText: "TAP Image 'Info' button to open the photo picker -->")

        helpSections[4] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone3-AddFilter", iPadImage: "iPad4-MoreInput",
                                   helpText: "TOUCH Effex '+' button to add another effex filter after selected filter -->")

        helpSections[5] = HelpInfo(helpTitle: "Settings", iPhoneImage: "iPhone4-MorePick", iPadImage: "iPad5-EffexHighlight",
                                   helpText: "TAP on Image row - SWIPE to '+Effex' for image from another filter. Or 'Library' for image from saved Library  -->")

        helpSections[6] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone5-EffexHighlight", iPadImage: "iPad6-SaveEffex",
                                   helpText: "TAP a row again to highlight and view only the selected filter effex image -->")

        helpSections[7] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone6-SaveEffex", iPadImage: "iPad7-VarySetting",
                                   helpText: "TAP Save bar button to open text boxes")

        helpSections[8] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone61-SaveTitle", iPadImage: "iPad8-Trash",
                                   helpText: "Type title/album names. TAP 'Save' button saves a copy into Photos. Source images are not changed")

        helpSections[9] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone7-ParmVary", iPadImage: "iPad9-PhotoPick",
                                   helpText: "Settings - Swipe to 'Vary' values over time")

        helpSections[10] = HelpInfo(helpTitle: "Trash", iPhoneImage: "iPhone8-Trash", iPadImage: "iPad10-DemoBtn",
                                    helpText: "Trash button - Start over and discard everything, OR keep selected images and remove all filters, OR keep all effex filters without images ")

        helpSections[11] = HelpInfo(helpTitle: "Photo Picker", iPhoneImage: "iPhone9-PhotoPick", iPadImage: "iPad12-Picker",
                                   helpText: "Touch photo(s) to select, then Done")

        helpSections[12] = HelpInfo(helpTitle: "Effex", iPhoneImage: "iPhone10-DemoBtn", iPadImage: "iPad13-Demo",
                                    helpText: "Demo bar button for samples with images from your Favorites")


    }
    
    override func viewDidLoad() {
        loadHelpInfo()

        super.viewDidLoad()

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        if  (traitCollection.userInterfaceIdiom) == .phone {
            iPhoneFormat = true
        } else {
            iPhoneFormat = false
        }

        if let viewController = viewPhotoCommentController(currentIndex ?? 0) {
          let viewControllers = [viewController]

          setViewControllers(viewControllers,
                             direction: .forward,
                             animated: false,
                             completion: nil)
        }

        dataSource = self


      }

    /// Help only shows automatically on first startup
    override func viewWillDisappear(_ animated: Bool) {

        if ShowHelpOnOpen { UserDefaults.standard.setValue(false, forKey: ShowHelpPageAtStartupKey)
                // set to false after first time true (startup)
                // only show once on first startup... then user should use the ? button for help
                ShowHelpOnOpen = false
        }


      }

    func viewPhotoCommentController(_ index: Int) -> PGLHelpSinglePage? {
      guard
        let storyboard = storyboard,
        let page = storyboard.instantiateViewController(withIdentifier: "PGLHelpSinglePage") as? PGLHelpSinglePage
        else {
          return nil
      }
        page.photoIndex = index
        page.photoName = if iPhoneFormat
                        {helpSections[index]?.iPhoneImage } else {helpSections[index]?.iPadImage}
        page.instructionText = helpSections[index]?.helpText
        page.thisSectionTitle = helpSections[index]?.helpTitle

      return page
    }
  }

  extension PGLHelpPageController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
      if let viewController = viewController as? PGLHelpSinglePage,
        let index = viewController.photoIndex,
        index > 0 {
        return viewPhotoCommentController(index - 1)
      }

      return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
      if let viewController = viewController as? PGLHelpSinglePage,
        let index = viewController.photoIndex,
         (index + 1) < helpSections.count {
        return viewPhotoCommentController(index + 1)
      }

      return nil
    }

    func presentationCount(for pageViewController: UIPageViewController) -> Int {
      return helpSections.count
    }

    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
      return currentIndex ?? 0
    }
  }



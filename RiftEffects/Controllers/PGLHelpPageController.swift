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
        helpSections[0] = HelpInfo(helpTitle: String(localized: "Roadmap", comment: "Help page title"), iPhoneImage: "iPhone0-Roadmap", iPadImage: "iPad0-RoadMap",
                                   helpText: String(localized: "PICK an image from the Library. TAP Effex Filter. SWIPE filter to open Settings.", comment: "Help page instructions"))

        helpSections[1] = HelpInfo(helpTitle: String(localized: "Guide", comment: "Help page title"), iPhoneImage: "iPhone01-Guide", iPadImage: "iPad1-Guide",
                                   helpText: String(localized: "Tap 'Guide' & follow pointer steps", comment: "Help page instructions"))

        helpSections[2] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone1-SettingsOpen", iPadImage: "iPad2-OpenImagePicker",
                                   helpText: String(localized: "SWIPE left 'Open' to Settings for that filter  -->", comment: "Help page instructions"))

        helpSections[3] = HelpInfo(helpTitle: String(localized: "Settings", comment: "Help page title"), iPhoneImage: "iPhone2-OpenImagePicker", iPadImage: "iPad3-AddFilter",
                                   helpText: String(localized: "TAP Image 'Info' button to open the photo picker -->", comment: "Help page instructions"))

        helpSections[4] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone3-AddFilter", iPadImage: "iPad4-MoreInput",
                                   helpText: String(localized: "TOUCH Effex '+' button to add another effex filter after selected filter -->", comment: "Help page instructions"))

        helpSections[5] = HelpInfo(helpTitle: String(localized: "Settings", comment: "Help page title"), iPhoneImage: "iPhone4-MorePick", iPadImage: "iPad5-EffexHighlight",
                                   helpText: String(localized: "TAP on Image row - SWIPE to '+Effex' for image from another filter. Or 'Library' for image from saved Library  -->", comment: "Help page instructions"))

        helpSections[6] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone5-EffexHighlight", iPadImage: "iPad6-SaveEffex",
                                   helpText: String(localized: "TAP a row again to highlight and view only the selected filter effex image -->", comment: "Help page instructions"))

        helpSections[7] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone6-SaveEffex", iPadImage: "iPad7-VarySetting",
                                   helpText: String(localized: "TAP Save bar button to open text boxes", comment: "Help page instructions"))

        helpSections[8] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone61-SaveTitle", iPadImage: "iPad8-Trash",
                                   helpText: String(localized: "Type title/album names. TAP 'Save' button saves a copy into Photos. Source images are not changed", comment: "Help page instructions"))

        helpSections[9] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone7-ParmVary", iPadImage: "iPad9-PhotoPick",
                                   helpText: String(localized: "Settings - Swipe to 'Vary' values over time", comment: "Help page instructions"))

        helpSections[10] = HelpInfo(helpTitle: String(localized: "Trash", comment: "Help page title"), iPhoneImage: "iPhone8-Trash", iPadImage: "iPad10-DemoBtn",
                                    helpText: String(localized: "Trash button - Start over and discard everything, OR keep selected images and remove all filters, OR keep all effex filters without images ", comment: "Help page instructions"))

        helpSections[11] = HelpInfo(helpTitle: String(localized: "Photo Picker", comment: "Help page title"), iPhoneImage: "iPhone9-PhotoPick", iPadImage: "iPad12-Picker",
                                   helpText: String(localized: "Touch photo(s) to select, then Done", comment: "Help page instructions"))

        helpSections[12] = HelpInfo(helpTitle: String(localized: "Effex", comment: "Help page title"), iPhoneImage: "iPhone10-DemoBtn", iPadImage: "iPad13-Demo",
                                    helpText: String(localized: "Demo bar button for samples with images from your Favorites", comment: "Help page instructions"))


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


//
//  PGLInfoPrivacyController.swift
//  WillsFilterTool
//
//  Created by Will on 6/3/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//
import Foundation
import UIKit
import os

class PGLInfoPrivacyController: UIViewController {


    override func viewDidLoad() {
        super.viewDidLoad()
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        PrivacyText.attributedText = readPrivacyPolicy()
        self.navigationItem.title = "https:\\\\rifteffex.com"
            // explicit close - the iPhone landscape sheet does not dismiss on swipe down
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        // Do any additional setup after loading the view.
    }

    func readPrivacyPolicy() -> NSAttributedString {
        var policyText = NSAttributedString(string: "Privacy Policy")
        let typeKey = NSAttributedString.DocumentReadingOptionKey.documentType
        let mainBundle = Bundle.main
        guard let privacyPath = mainBundle.path(forResource: "PrivacyPolicy", ofType: "rtf")
            else { return policyText}
        guard let privacyData = FileManager.default.contents(atPath: privacyPath)
        else { return policyText}
        do {
            policyText = try NSAttributedString.init(data: privacyData, options: [typeKey: NSAttributedString.DocumentType.rtf], documentAttributes: nil)

        } catch {
            Logger(subsystem: LogSubsystem, category: LogCategory).error("Privacy Policy read error \(error.localizedDescription)")

        }
        return adaptedForDevice(policyText)
    }

    /// The RTF files carry no text color (imports as black - invisible in dark mode)
    /// and a negative right indent (\ri-1634, ~82 pt) that leaves almost no line width
    /// on an iPhone. Use the dynamic label color and remove the tail indent.
    func adaptedForDevice(_ policyText: NSAttributedString) -> NSAttributedString {
        let adapted = NSMutableAttributedString(attributedString: policyText)
        let fullRange = NSRange(location: 0, length: adapted.length)
        adapted.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        adapted.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            guard let style = value as? NSParagraphStyle,
                  let mutableStyle = style.mutableCopy() as? NSMutableParagraphStyle
            else { return }
            mutableStyle.tailIndent = 0
            adapted.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
        }
        return adapted
    }

    @IBOutlet weak var PrivacyText: UITextView!


    @IBOutlet weak var infoLinkLabel: UILabel! {
        didSet {
            infoLinkLabel.text = "https:\\rifteffex.com"
        }
    }

    @IBOutlet weak var privacyLabel: UILabel!  {
        didSet {

//          privacyLabel.attributedText = readPrivacyPolicy()



        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

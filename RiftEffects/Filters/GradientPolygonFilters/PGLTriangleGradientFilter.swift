//
//  PGLTriangleGradientFilter.swift
//  RiftEffects
//
//  Created by Will on 3/23/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

let kGradientBlendFilter = "CIDarkenBlendMode"
let kGradientFilterName = "CILinearGradient"
let kGradientAttributePrefix = "linear"
let kGradientCornerPrefix = "corner"
let kGradientWidthKey = "inputGradientWidth"

/// Triangle (or N sided) gradient mask, built by intersecting CILinearGradients - one per side.
/// UI exposes one point parm per polygon corner plus a single shared Width slider.
/// #setVectorValue / #setNumberValue below is the mapping layer that translates a corner
/// move (or a width change) into the inputPoint0/inputPoint1 of the two CILinearGradients
/// that meet at that corner.
class PGLTriangleGradientFilter: PGLSourceFilter, PGLCenterPoint {

    /// number of sides/corners of the polygon - subclasses override to change the shape
    class var polygonSideCount: Int { return 3 }

    var sideCount = 3
    var linearGradients =  [PGLSourceFilter]()
    var blendFilters = [CIFilter]()
    var centerPoint: CGPoint = CGPoint(x: TargetSize.width/2, y: TargetSize.height/2)

    /// corner positions of the polygon - corners[i] and corners[(i+1) % sideCount] define side i
    var corners: [CGPoint] = []
    /// width of the blended edge, shared by every side
    var gradientWidth: CGFloat = 80


    required init?(filter: String, position: PGLFilterCategoryIndex) {

        super.init(filter: filter, position: position)
        sideCount = Self.polygonSideCount
        corners = PGLTriangleGradientFilter.defaultCorners(count: sideCount)

        attributes.append(self.centerPointAttribute())
        for index in 0 ..< sideCount {
            attributes.append(self.cornerPointAttribute(index: index))
        }
        attributes.append(self.gradientWidthAttribute())

        for _ in 1 ..< sideCount {
            blendFilters.append(CIFilter(name: kGradientBlendFilter)! )
        }

        for index in 0 ..< sideCount  {
            if let  childLinearFilter = PGLGradientChildFilter(filter: "CILinearGradient", position: PGLFilterCategoryIndex()) {
                childLinearFilter.parentFilter = self
                childLinearFilter.sideKey = index
                linearGradients.append(childLinearFilter)
            }
        }
        recomputeAllSides()
//        hasAnimation = true
    }

    override class func localizedDescription(filterName: String) -> String {
       return NSLocalizedString("3 sided Gradient for Blend with Mask. Generates the mask shape", comment: "Triangle Gradient custom filter description")
    }

    // MARK: Attribute construction

    func centerPointAttribute() -> PGLFilterAttributeVector {
        let inputDict: [String:Any] = [
            "CIAttributeIdentity" : [200, 200],
            "CIAttributeDefault" : [200, 200],
            "CIAttributeType" : kCIAttributeTypePosition,
            "CIAttributeDisplayName" : "Center" ,
            "kCIAttributeDescription": "Position of the frame",
            "CIAttributeClass":  "CIVector"
        ]
        let newVectorAttribute = PGLFilterAttributeVectorUI(pglFilter: self, attributeDict: inputDict, inputKey: kCIInputCenterKey)
        return newVectorAttribute!
    }

    func cornerPointAttribute(index: Int) -> PGLGradientCornerAttribute {
        let defaultPoint = corners[index]
        let inputDict: [String:Any] = [
            "CIAttributeIdentity" : [Double(defaultPoint.x), Double(defaultPoint.y)],
            "CIAttributeDefault" : [Double(defaultPoint.x), Double(defaultPoint.y)],
            "CIAttributeType" : kCIAttributeTypePosition,
            "CIAttributeDisplayName" : "Corner " + String(index + 1),
            "kCIAttributeDescription": "Position of polygon corner " + String(index + 1),
            "CIAttributeClass":  "CIVector"
        ]
        let newCornerAttribute = PGLGradientCornerAttribute(pglFilter: self, attributeDict: inputDict, inputKey: kGradientCornerPrefix + String(index))!
        newCornerAttribute.cornerIndex = index
        return newCornerAttribute
    }

    func gradientWidthAttribute() -> PGLGradientWidthAttribute {
        let inputDict: [String:Any] = [
            "CIAttributeIdentity" : Float(gradientWidth),
            "CIAttributeDefault" : Float(gradientWidth),
            "CIAttributeSliderMin" : Float(0.0),
            "CIAttributeSliderMax" : Float(300.0),
            "CIAttributeType" : kCIAttributeTypeScalar,
            "CIAttributeDisplayName" : "Width",
            "kCIAttributeDescription": "Width of the blended edge along each side",
            "CIAttributeClass":  "NSNumber"
        ]
        return PGLGradientWidthAttribute(pglFilter: self, attributeDict: inputDict, inputKey: kGradientWidthKey)!
    }

    // MARK: Default layout

    /// a regular polygon inscribed in a circle centered on TargetSize
    class func defaultCorners(count: Int) -> [CGPoint] {
        let center = CGPoint(x: TargetSize.width / 2, y: TargetSize.height / 2)
        let radius = min(TargetSize.width, TargetSize.height) * 0.35
        return (0 ..< count).map { index in
            let angle = -CGFloat.pi / 2 + (2 * CGFloat.pi * CGFloat(index) / CGFloat(count))
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    // MARK: Geometry mapping layer

    func centroid() -> CGPoint {
        let sum = corners.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        return CGPoint(x: sum.x / CGFloat(corners.count), y: sum.y / CGFloat(corners.count))
    }

    /// recompute inputPoint0/inputPoint1 of the linear gradient for side `index`
    /// side `index` connects corners[index] to corners[(index+1) % sideCount]
    func recomputeSide(_ index: Int) {
        guard index >= 0, index < linearGradients.count, corners.count == sideCount else { return }
        let cornerA = corners[index]
        let cornerB = corners[(index + 1) % sideCount]
        let midpoint = CGPoint(x: (cornerA.x + cornerB.x) / 2, y: (cornerA.y + cornerB.y) / 2)

        let dx = cornerB.x - cornerA.x
        let dy = cornerB.y - cornerA.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        // perpendicular to the side, oriented to point away from the polygon centroid
        var normalX = -dy / length
        var normalY = dx / length
        let center = centroid()
        if (normalX * (center.x - midpoint.x) + normalY * (center.y - midpoint.y)) > 0 {
            normalX = -normalX
            normalY = -normalY
        }

        let halfWidth = gradientWidth / 2
        let point0 = CGPoint(x: midpoint.x - normalX * halfWidth, y: midpoint.y - normalY * halfWidth)
        let point1 = CGPoint(x: midpoint.x + normalX * halfWidth, y: midpoint.y + normalY * halfWidth)

        let targetGradient = linearGradients[index]
        targetGradient.setVectorValue(newValue: CIVector(cgPoint: point0), keyName: kCIInputPoint0Key)
        targetGradient.setVectorValue(newValue: CIVector(cgPoint: point1), keyName: kCIInputPoint1Key)
    }

    func recomputeSidesAdjacent(toCorner index: Int) {
        recomputeSide((index - 1 + sideCount) % sideCount)
        recomputeSide(index)
    }

    func recomputeAllSides() {
        for index in 0 ..< sideCount {
            recomputeSide(index)
        }
    }

    /// format is corner# ie corner2  -  answer the corner array index, nil if not a corner key
    func cornerIndex(fromKeyName keyName: String) -> Int? {
        guard keyName.hasPrefix(kGradientCornerPrefix) else { return nil }
        return Int(keyName.dropFirst(kGradientCornerPrefix.count))
    }

    // MARK: Render

    override func outputImageBasic() -> CIImage? {
        //notice that .outputImage() is used for the linearGradients image return
        // BUT .outputImage is used for the blendFilter image return..
        // it's a bug in the filter code !!

        addFilterStepTime()  // if animation then move time forward - drives center/corner Vary via addAnimationStepTime()

        guard sideCount > 0, !linearGradients.isEmpty else { return nil }
        var currentImage = linearGradients[0].outputImage()
        for index in 1 ..< sideCount {
            let nextImage = linearGradients[index].outputImage()
            let blendFilter = blendFilters[index - 1]
            blendFilter.setValue(currentImage, forKey: kCIInputImageKey)
            blendFilter.setValue(nextImage, forKey: kCIInputBackgroundImageKey)
            currentImage = blendFilter.outputImage
        }
        return currentImage
    }

    // MARK: Value routing

    override func setVectorValue(newValue: CIVector, keyName: String) {
        logParm(#function, newValue.debugDescription, keyName)
        if keyName == kCIInputCenterKey {
            // translate every corner by the change from the oldPoint to the newValue
            let oldCenterPoint = centerPoint
            centerPoint = CGPoint(x: newValue.x, y: newValue.y)
            let dx = centerPoint.x - oldCenterPoint.x
            let dy = centerPoint.y - oldCenterPoint.y
            for index in 0 ..< corners.count {
                corners[index] = CGPoint(x: corners[index].x + dx, y: corners[index].y + dy)
            }
            recomputeAllSides()
        } else if let index = cornerIndex(fromKeyName: keyName), index < corners.count {
            corners[index] = CGPoint(x: newValue.x, y: newValue.y)
            recomputeSidesAdjacent(toCorner: index)
        }
        postImageChange()
    }

    override func setNumberValue(newValue: NSNumber, keyName: String) {
        if keyName == kGradientWidthKey {
            gradientWidth = CGFloat(newValue.doubleValue)
            recomputeAllSides()
            postImageChange()
        } else {
            super.setNumberValue(newValue: newValue, keyName: keyName)
        }
    }

    override func valueFor( keyName: String) -> Any? {
        if keyName == kCIInputCenterKey {
            return centerPoint
        }
        if keyName == kGradientWidthKey {
            return gradientWidth
        }
        if let index = cornerIndex(fromKeyName: keyName), index < corners.count {
            return corners[index]
        }
        return super.valueFor(keyName: keyName)
    }
}

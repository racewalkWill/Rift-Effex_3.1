//
//  PGLAttributeVectorNumeric.swift
//  RiftEffects
//
//  Created by Will on 12/11/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import Foundation

class PGLAttributeVectorNumeric: PGLFilterAttribute {
    override func valueInterface() -> [PGLFilterAttribute] {
        // subclasses such as PGLFilterAttributeAffine implement a attributeUI collection
        // single affine parm attribute needs three independent settings rotate, scale, translate


        guard let mySourceFilter = aSourceFilter,
              let newSliderParm  = PGLAttributeVectorNumericUI(pglFilter: mySourceFilter, attributeDict: initDict, inputKey: attributeName!)
        else { return [PGLFilterAttribute]() }
        newSliderParm.parentVectorAttribute = self
        return [ newSliderParm ]


    }


}

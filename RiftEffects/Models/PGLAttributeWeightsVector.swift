//
//  PGLAttributeWeightsVector.swift
//  RiftEffects
//
//  Created by Will on 12/29/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import Foundation

import UIKit

class PGLAttributeWeightsVector: PGLFilterAttributeVector {
        // convolution filters use a vector of weighted numerics
        // 3x3, 5x5, 7x7.. or 1x9

        // this is the parent attribute that displays an individual
        // cell slider for each element of the vector matrix.
        // Used by PGLConvolutionFilter and PGLNumericSliderUI

    var localMatrix: Matrix?

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        if let parentFilterMatrix = (pglFilter as? PGLConvolutionFilter)?.filterMatrix {
            localMatrix = parentFilterMatrix }
        else {
            localMatrix = initMatrix() // but this will be all zeros - empty values
            }
    }

    override func shouldSetDefaultVectorValue() -> Bool {
        return false
    }

    override func moveOnDrawableSizeChange() -> Bool {
        // only some PGLFilterAttributeVectors should move
        return false
    }

    func setWeight(newValue: Double, row: Int, column: Int) {
        if localMatrix == nil {
            return
        }
        localMatrix![row, column] = newValue
        // update matrix into the filter vector
//        NSLog("\( String(describing: self) + "-" + #function) localMatrix.grid \(localMatrix.grid)")
       guard let parentConvolutionFilter =  aSourceFilter as? PGLConvolutionFilter
        else { return  }
        parentConvolutionFilter.setWeights(weightMatrix: localMatrix!)
    }

     func initMatrix() -> Matrix {
         var newMatrix: Matrix
        guard let convolutionFilter = aSourceFilter as? PGLConvolutionFilter
        else { return  Matrix(rows: 0, columns: 0) }
         
         guard  let filterSavedValues = convolutionFilter.valueFor(keyName: attributeName!) as? CIVector
         else { return  Matrix(rows: 0, columns: 0) }

         if convolutionFilter.isSquareMatrix {
             newMatrix = Matrix.FromVector(baseRows: convolutionFilter.matrixSize, baseColumns: convolutionFilter.matrixSize, vector: filterSavedValues)
        }
        else {
            newMatrix = Matrix.FromVector(baseRows: 1, baseColumns: 9, vector: filterSavedValues)
        }

        return newMatrix
    }

    func getValue(row: Int, column: Int) -> CGFloat {
        return localMatrix?[row, column] ?? 0.0 as CGFloat
    }

    override func valueInterface() -> [PGLFilterAttribute] {
        guard let convolution = aSourceFilter as? PGLConvolutionFilter
        else { return [PGLFilterAttribute]() }
        var sliderUI = [PGLNumericSliderUI]()
        if convolution.isSquareMatrix {
            for row in 0..<convolution.matrixSize {
                for column in 0..<convolution.matrixSize {
                    if let newUIRow = PGLNumericSliderUI.init(convolution: self, matrixRow: row, matrixColumn: column)
                    {
                        sliderUI.append(newUIRow) }
                }
            }
        }
        else {
                // 1x9 convolution
            for column in 0..<convolution.matrixSize {
                if let newUIRow = PGLNumericSliderUI.init(convolution: self, matrixRow: 0 , matrixColumn: column)
                { sliderUI.append(newUIRow) }
            }
        }
        return sliderUI
    }

}

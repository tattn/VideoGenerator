//
//  Sendable+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import UIKit
import CoreImage

extension UIImage: @unchecked Sendable {}
extension CIImage: @unchecked Sendable {}

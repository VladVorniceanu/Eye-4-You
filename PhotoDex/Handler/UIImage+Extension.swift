//
//  UIImage+Extension.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 22.06.2024.
//

import UIKit

extension UIImage {
    func rotated(byDegrees degrees: CGFloat) -> UIImage? {
        let radians = degrees * CGFloat.pi / 180
        let rotatedRect = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians))
        
        UIGraphicsBeginImageContext(rotatedRect.size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: rotatedRect.width / 2, y: rotatedRect.height / 2)
        context.rotate(by: radians)
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}

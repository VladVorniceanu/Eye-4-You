////
////  CameraView.swift
////  PhotoDex
////
////  Created by Vlad Vorniceanu on 04.04.2024.
////
//
//import Foundation
//import SwiftUI
//import AVFoundation
//
//struct CameraView: UIViewControllerRepresentable {
//    
//    let cameraViewController: CameraManager
//    let didFinishProcessingPhoto: (Result<AVCapturePhoto, Error>) -> ()
//    
//    func makeUIViewController(context: Context) -> UIViewController {
//        cameraViewController.start(delegate: context.coordinator) { error in
//            if let err = error {
//                didFinishProcessingPhoto(.failure(err))
//                return
//            }
//        }
//    }
//    
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//    }
//    
//    typealias UIViewControllerType = UIViewController
//    
//}
////
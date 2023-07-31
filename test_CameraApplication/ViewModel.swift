//
//  ViewModel.swift
//  test_CameraApplication
//
//  Created by Mac Pro on 31.07.2023.
//


import AVKit
import Photos

class ViewModel {
    
    enum CaptureStatus {
        case photo, video, recording
    }
    
    var captureSession: AVCaptureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice!
    var frontCamera: AVCaptureDevice!
    var backInput: AVCaptureInput!
    var frontInput: AVCaptureInput!
    var currentDevice: AVCaptureDevice!
    
    var movieOutput: AVCaptureMovieFileOutput!
    
    var stillImageOutput: AVCapturePhotoOutput!
    
    var captureStatus: CaptureStatus = .photo
    
    func setupInputs() {
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
        } else {
            print("no back camera")
            return
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            print("no front camera")
            return
        }
        
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            print("could not create input device from back camera")
            return
        }
        backInput = bInput
        if !captureSession.canAddInput(backInput) {
            print("could not add back camera input to capture session")
            return
        }
        
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            print("could not create input device from front camera")
            return
        }
        frontInput = fInput
        if !captureSession.canAddInput(frontInput) {
            print("could not add front camera input to capture session")
        }
        
        captureSession.addInput(backInput)
    }
    
    func setupOutput() {
        movieOutput = AVCaptureMovieFileOutput()
        stillImageOutput = AVCapturePhotoOutput()
        stillImageOutput.connections.first?.videoOrientation = .portrait
        movieOutput.connections.first?.videoOrientation = .portrait
        
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        } else {
            fatalError("could not add photo output")
        }
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        } else {
            fatalError("could not add video output")
        }
    }
    
    
    func stopRecording(completion: @escaping (Error?) -> Void) {
        guard self.captureSession.isRunning else {
            return
        }
        self.movieOutput.stopRecording()
    }
}

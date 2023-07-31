//
//  ViewController.swift
//  test_CameraApplication
//
//  Created by Mac Pro on 31.07.2023.
//

import UIKit
import AVKit
import Photos

class ViewController: UIViewController {
    
    
    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var statusSegment: UISegmentedControl!
    @IBOutlet weak var flipCameraButton: UIButton!
    
    var viewModel = ViewModel()
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.captureSession)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let containsPreviewLayer = view.layer.sublayers?.contains( previewLayer), containsPreviewLayer {
            return
        }
        setupAndStartCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = self.view.frame
    }
    
    override func viewWillLayoutSubviews() {
        self.previewLayer.frame = self.view.bounds
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            let orientation = self.interfaceOrientation(toVideoOrientation: UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait)
            connection.videoOrientation = orientation
            viewModel.stillImageOutput.connections.first?.videoOrientation = orientation
        }
    }
    
    func interfaceOrientation(toVideoOrientation orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            break
        }
        return .portrait
    }
    
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.frame
        
        view.bringSubviewToFront(takePhotoButton)
        view.bringSubviewToFront(statusSegment)
        view.bringSubviewToFront(flipCameraButton)
    }
    
    func setupAndStartCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.viewModel.captureSession = AVCaptureSession()
            self.viewModel.captureSession.beginConfiguration()
            
            if self.viewModel.captureSession.canSetSessionPreset(.photo) {
                self.viewModel.captureSession.sessionPreset = .photo
            }
            self.viewModel.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            
            self.viewModel.setupInputs()
            
            DispatchQueue.main.async {
                self.setupPreviewLayer()
            }
            
            self.viewModel.setupOutput()
            self.viewModel.captureSession.commitConfiguration()
            self.viewModel.captureSession.startRunning()
        }
    }
    
    func recordVideo(completion: @escaping (URL?, Error?) -> Void) {
        guard self.viewModel.captureSession.isRunning else {
            return
        }
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let id = Int.random(in: 0...1000)
        let fileUrl = paths[0].appendingPathComponent("\(id).mp4")
        try? FileManager.default.removeItem(at: fileUrl)
        viewModel.movieOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }
    
    func takePhoto() {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .off
        
        viewModel.stillImageOutput.isHighResolutionCaptureEnabled = true
        viewModel.stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    
    @IBAction func didChangeCaptureType(_ sender: Any) {
        
        guard let sender = sender as? UISegmentedControl else { return }
        if sender.selectedSegmentIndex == 0 {
            viewModel.captureStatus = .photo
        } else {
            viewModel.captureStatus = .video
        }
    }
    
    @IBAction func didTapFlip(_ sender: Any) {
        
        if let firstInput =  viewModel.captureSession.inputs.first {
            if firstInput == viewModel.backInput {
                viewModel.captureSession.beginConfiguration()
                viewModel.captureSession.removeInput(viewModel.backInput)
                viewModel.captureSession.addInput(viewModel.frontInput)
                viewModel.captureSession.commitConfiguration()
            } else {
                viewModel.captureSession.beginConfiguration()
                viewModel.captureSession.removeInput(viewModel.frontInput)
                viewModel.captureSession.addInput(viewModel.backInput)
                viewModel.captureSession.commitConfiguration()
            }
        }
    }
    
    @IBAction func didTakePhoto(_ sender: Any) {
        
        switch viewModel.captureStatus {
        case .photo:
            takePhoto()
        case .video:
            takePhotoButton.setBackgroundImage(UIImage.init(systemName: "stop.circle.fill"), for: .normal)
            statusSegment.isHidden = true
            flipCameraButton.isHidden = true
            viewModel.captureStatus = .recording
            recordVideo { url, error in
                
            }
        case .recording:
            takePhotoButton.setBackgroundImage(UIImage.init(systemName: "camera.circle.fill"), for: .normal)
            statusSegment.isHidden = false
            flipCameraButton.isHidden = false
            viewModel.captureStatus = .video
            viewModel.stopRecording { error in
                
            }
        }
    }
}


extension ViewController: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            guard let image = UIImage(data: imageData) else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            }) { saved, error in
                if saved {
                    let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                    let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alertController.addAction(defaultAction)
                    DispatchQueue.main.async {
                        self.present(alertController, animated: true, completion: nil)
                    }
                    
                }
            }
        } else {
            //do something
        }
    }
}


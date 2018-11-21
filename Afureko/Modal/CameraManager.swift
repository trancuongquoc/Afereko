//
//  CameraController.swift
//  AfterRecording
//
//  Created by Quoc Cuong on 11/1/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import AVFoundation
import UIKit

protocol CameraManagerDelegate: class {
    func cameraManager(didFinishRecordingVideoTo outputVideoURL: URL)
    
    func cameraManager(didToggleTorchModeWith mode: AVCaptureDevice.TorchMode)
    
    func cameraManager(didUpdateRecordingDurationValueTo newValue: Float64)
    
    func cameraManager(isRecording: Bool)
    
    func cameraManagerDidStopCaptureSession()
}

class CameraManager: NSObject {
    
    static var instancesOfSelf = [CameraManager]()
    
    private var permissionGranted = false
    private var sessionQueue = DispatchQueue(label: "session queue")
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var currentCameraPosition: CameraPosition? {
        didSet {
            currentCamera = (currentCameraPosition == .rear) ? rearCamera : frontCamera
        }
    }
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var movieFileOutput: AVCaptureMovieFileOutput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var torchMode = AVCaptureDevice.TorchMode.off
    
    var outputURL: URL!
    
    weak var delegate: CameraManagerDelegate?
    
    var timer: RepeatingTimer?
    let maximumRecordingDuration: Float64 = 20
    
    var recordingTime: Float64 = 0 {
        didSet {
            delegate?.cameraManager(didUpdateRecordingDurationValueTo: recordingTime)
        }
    }
    
    var hasReachedMaximumDuration: Bool = false {
        didSet {
            if hasReachedMaximumDuration {
                stopRecording()
                stopCaptureSession()
                delegate?.cameraManagerDidStopCaptureSession()
            }
        }
    }
    
    override init() {
        super.init()
        CameraManager.instancesOfSelf.append(self)
        print("CameraManager instance is initialized")
    }
    
    class func destroySelf(object: CameraManager)
    {
        instancesOfSelf = instancesOfSelf.filter {
            $0 !== object
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] (granted) in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func prepare(commpletionHandler: @escaping (Error?) -> Void) {
        func checkPermission() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                permissionGranted = true
            case .notDetermined:
                requestPermission()
            default:
                permissionGranted = false
            }
        }
        
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            guard let cameras = AVCaptureDevice.devices(for: .video) as? [AVCaptureDevice], !cameras.isEmpty else {
                throw CameraControllerError.noCamerasAvailable
            }
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                self.currentCameraPosition = .rear
                
            } else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
                
            } else { throw CameraControllerError.noCamerasAvailable }
            
            if let microphone = AVCaptureDevice.default(for: .audio) {
                let micInput = try AVCaptureDeviceInput(device: microphone)
                
                if captureSession.canAddInput(micInput) { captureSession.addInput(micInput) }
                else { throw CameraControllerError.inputsAreInvalid }
            }
        }
        
        func configureMovieFileOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            movieFileOutput = AVCaptureMovieFileOutput()
            
            guard let output = movieFileOutput else { return }
            
            captureSession.removeOutput(output)
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output) }
            
            captureSession.startRunning()
        }
        
        sessionQueue.sync {
            do {
                checkPermission()
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configureMovieFileOutput()
            } catch {
                DispatchQueue.main.async {
                    commpletionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                commpletionHandler(nil)
            }
        }
    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.frame = view.bounds
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        view.layer.addSublayer(self.previewLayer!)
    }
    
    func startRecording() {
        if movieFileOutput?.isRecording == false && !hasReachedMaximumDuration {
            let connection = movieFileOutput?.connection(with: .video)
            if (connection!.isVideoOrientationSupported) {
                connection?.videoOrientation = currentVideoOrientation()
            }
            
            if connection!.isVideoStabilizationSupported {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
            
            outputURL = tempURL(for: ".mp4")
            movieFileOutput?.movieFragmentInterval = CMTime.invalid
            movieFileOutput?.startRecording(to: outputURL, recordingDelegate: self)
            delegate?.cameraManager(isRecording: true)
            startTrackingRecordingTime()
        } else {
            stopRecording()
        }
    }
    
    func stopRecording() {
        if movieFileOutput?.isRecording == true {
            movieFileOutput?.stopRecording()
            delegate?.cameraManager(isRecording: false)
            stopTrackingRecordTime()
        }
    }
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        
        return orientation
    }
    
    func switchCamera() throws {
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        func switchToFrontCamera() throws {
            guard let inputs = captureSession.inputs as? [AVCaptureInput], let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput), let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
                
            } else { throw CameraControllerError.invalidOperation }
        }
        
        func switchToRearCamera() throws {
            guard let inputs = captureSession.inputs as? [AVCaptureInput], let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput), let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
                
            } else { throw CameraControllerError.invalidOperation }
        }
        
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
        case .rear:
            try switchToFrontCamera()
        }
        
        captureSession.commitConfiguration()
    }
    
    func toogleTorch() {
        if let currentDevice = currentCamera {
            if currentDevice.hasTorch {
                let torchState = currentCamera?.toggleTorch()
                delegate?.cameraManager(didToggleTorchModeWith: torchState!)
            }
        } else {
            print("Torch is not available.")
        }
    }
    
    func stopCaptureSession() {
        captureSession?.stopRunning()
    }
    
    //Things need to be done before leaving.
    func cleanup()  {
        stopCaptureSession()
        captureSession = nil
        movieFileOutput = nil
        previewLayer = nil
        frontCamera  = nil
        rearCamera = nil
        currentCameraPosition = nil
        frontCameraInput = nil
        rearCameraInput = nil
        CameraManager.destroySelf(object: self)
    }
    
    deinit {
        print("CameraManager instance is deinitialized")
    }
}

extension CameraManager {     //MARK: - Track Time
    func startTrackingRecordingTime() {
        guard !hasReachedMaximumDuration else { return }
        timer = RepeatingTimer(timeInterval: 0.01)
        timer?.eventHandler = { [unowned self] in
            self.updateVideoTime()
        }
        timer?.resume()
    }
    
    @objc func updateVideoTime() {
        hasReachedMaximumDuration = recordingTime > maximumRecordingDuration
        hasReachedMaximumDuration ? (recordingTime = maximumRecordingDuration) :  (recordingTime += 0.01)
    }
    
    func stopTrackingRecordTime() {
        timer?.suspend()
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
            delegate?.cameraManager(didFinishRecordingVideoTo: outputFileURL)
        }
    }
}


extension CameraManager {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
}

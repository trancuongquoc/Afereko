//
//  ViewController.swift
//  Afureko
//
//  Created by Quoc Cuong on 10/16/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import UIKit
import AVFoundation

class RecordingVideoController: UIViewController {
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var capturePreviewView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var nextButton: UIBarButtonItem!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var miximumDurationLabel: UILabel!
    
    weak var cameraManager: CameraManager!
    var outputVideoURLs = [URL]()
    
    override var prefersStatusBarHidden: Bool { return true }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.lock(with: "Loading")
        
        func prepare() {
            cameraManager = CameraManager()
            cameraManager.delegate = self
            
            outputVideoURLs = []
            
            DispatchQueue.main.async { [unowned self] in
                self.miximumDurationLabel.text = "/\(self.cameraManager.maximumRecordingDuration.intoString())"
                self.progressLabel.text = "0.00"
                self.progressBar.setProgress(0, animated: false)
            }
            
            //Disable some uneccessary buttons
            disableUserInteractions(for: [self.recordButton, self.switchCameraButton, self.flashButton], barButtons: [self.nextButton])
        }
        
        func configureCameraController() {
            cameraManager.prepare() { [unowned self] (error) in
                if let error = error {
                    print(error)
                }
                
                try? self.cameraManager.displayPreview(on: self.capturePreviewView)
                
                //Re-enable buttons once setup completed.
                enableUserInteractions(for: [self.recordButton, self.switchCameraButton, self.flashButton], barButtons: [self.nextButton])
                self.view.unlock()
            }
        }
        
        prepare()
        configureCameraController()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if cameraManager.torchMode == .on {
            cameraManager.toogleTorch()
        }
        
        cameraManager.cleanup()
    }
    
    @IBAction func recordButtonTouchDown(_ sender: UIButton) {
        DispatchQueue.main.async { [unowned self] in
            self.cameraManager.startRecording() 
        }
    }
    
    @IBAction func recordButtonTouchUp(_ sender: UIButton) {
        self.cameraManager.stopRecording()
    }
    
    @IBAction func recordButtonTouchUpInside(_ sender: UIButton) {
        self.cameraManager.stopRecording()
    }
    
    @IBAction func nextButtonHandle(_ sender: UIButton) {
        if !outputVideoURLs.isEmpty {
            performSegue(withIdentifier: "toPlayback", sender: outputVideoURLs)
        }
    }
    
    @IBAction func toggleFlash(_ sender: UIButton) {
        cameraManager.toogleTorch()
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        do {
            try cameraManager.switchCamera()
        } catch {
            print(error)
        }
        
        switch cameraManager.currentCameraPosition {
        case .some(.front):
            switchCameraButton.setImage(UIImage(named: "Front Camera Icon"), for: .normal)
        case .some(.rear):
            switchCameraButton.setImage(UIImage(named: "Rear Camera Icon"), for: .normal)
        case .none:
            return
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toPlayback" {
            let destination = segue.destination as! PlaybackController
            destination.outputVideoURLs = sender as! [URL]
        }
    }
    
    deinit {
        print("RecordingVideoController deinitialized.")
    }
}

//MARK: - CameraManagerDelegate
extension RecordingVideoController: CameraManagerDelegate {
    func cameraManagerDidStopCaptureSession() {
        disableUserInteractions(for: [switchCameraButton, flashButton, recordButton], barButtons: nil)
    }
    
    func cameraManager(didToggleTorchModeWith mode: AVCaptureDevice.TorchMode) {
        var imageLiteral: String = "Flash Off Icon"
        
        switch mode {
        case .on:
            imageLiteral = "Flash On Icon"
        case .off:
            imageLiteral = "Flash Off Icon"
        case .auto:
            imageLiteral = "flashauto"
        }
        
        DispatchQueue.main.async { [unowned self] in
            self.flashButton.setImage(UIImage(named: imageLiteral), for: .normal)
        }
    }
    
    func cameraManager(didUpdateRecordingDurationValueTo newValue: Float64) {
        let progressValue = Float(newValue / cameraManager.maximumRecordingDuration)
        DispatchQueue.main.async { [unowned self] in
            self.progressLabel.text = newValue.intoString()
            self.progressBar.setProgress(progressValue, animated: true)
        }
    }
    
    func cameraManager(isRecording: Bool) {
        if isRecording {
            disableUserInteractions(for: [switchCameraButton], barButtons: [nextButton])
        } else {
            enableUserInteractions(for: [switchCameraButton], barButtons: [nextButton])
        }
        
    }
   
    func cameraManager(didFinishRecordingVideoTo outputVideoURL: URL) {
        outputVideoURLs.append(outputVideoURL)
        enableUserInteractions(for: [self.switchCameraButton], barButtons: [self.nextButton])
    }
}






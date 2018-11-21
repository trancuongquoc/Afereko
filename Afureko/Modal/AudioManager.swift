//
//  AudioManager.swift
//  Afureko
//
//  Created by Quoc Cuong on 11/8/18.
//  Copyright © 2018 Quoc Cuong. All rights reserved.
//

import AVFoundation
import UIKit

protocol AudioManagerDelegate: class {
    func audioManager(didFinishRecordingAudioTo outputAudioURL: URL)
    func audioManager(didUpdateRecordingTimeTo newValue: Float64)
}

class AudioManager: NSObject {
    static var instancesOfSelf = [AudioManager]()
    private var sessionQueue = DispatchQueue(label: "audioSession queue")
    
    private var permissionGranted = false
    var audioRecorder: AVAudioRecorder!
    var isRecording = false
    var outputURL: URL!
    
    weak var delegate: AudioManagerDelegate?
    var timer: RepeatingTimer?
    var maximumRecordingDuration: Float64 = 0

    var recordingTime: Float64 = 0 {
        didSet {
            delegate?.audioManager(didUpdateRecordingTimeTo: recordingTime)
        }
    }
    
    var hasReachedMaximumDuration: Bool = false {
        didSet {
            if hasReachedMaximumDuration {
                finishAudioRecording(success: true)
            }
        }
    }
    override init() {
        super.init()
        AudioManager.instancesOfSelf.append(self)
        print("AudioManager instance is initialized")
    }
    
    func setMaximumRecordingDuration(to value: Float64) { maximumRecordingDuration = value }
    
    class func destroySelf(object: AudioManager)
    {
        instancesOfSelf = instancesOfSelf.filter {
            $0 !== object
        }
    }
    
    func configure(commpletionHandler: @escaping (Error?) -> Void) {
        func requestPermission() {
            sessionQueue.suspend()
            AVAudioSession.sharedInstance().requestRecordPermission { [unowned self] (granted) in
                self.permissionGranted = granted
                self.sessionQueue.resume()
            }
        }
        
        func checkPermission() {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                permissionGranted = true
            case .denied:
                permissionGranted = false
            case .undetermined:
                requestPermission()
            default:
                permissionGranted = false
            }
        }
        
        func configureRecorder() throws {
            guard permissionGranted else { print("Grant permisson to access microphone first.")
                return
            }
            
            let session = AVAudioSession.sharedInstance()
            
            do {
                try session.perform(NSSelectorFromString("setCategory:withOptions:error:"), with: AVAudioSession.Category.playAndRecord, with:  [AVAudioSession.CategoryOptions.duckOthers])
                try session.setActive(true)
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
                ]
                outputURL = tempURL(for: ".m4a")
                audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
                audioRecorder.delegate = self
                audioRecorder.isMeteringEnabled = true
                audioRecorder.prepareToRecord()
            } catch let error {
                throw error
            }
        }
        
        sessionQueue.sync {
            do {
                checkPermission()
                try configureRecorder()
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
    
    func startRecording() {
        if isRecording {
            finishAudioRecording(success: true)
        } else {
            audioRecorder.record()
            startTrackingRecordingTime()
            isRecording = true
        }
    }
    
    func finishAudioRecording(success: Bool) {
        if success {
            audioRecorder.stop()
            stopTrackingRecordTime()
            isRecording = false
            print("recorded successfully.")
        } else {
            print("recording failed.")
        }
    }
    
    deinit {
        print("AudioManager instance got deinitialized.")
    }
    
    func cleanup() {
        audioRecorder = nil
        AudioManager.destroySelf(object: self)
    }
}

extension AudioManager {     //MARK: - Track Time
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

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishAudioRecording(success: false)
        } else {
            delegate?.audioManager(didFinishRecordingAudioTo: outputURL)
        }
    }
}


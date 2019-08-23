//
//  ViewController.swift
//  MistyInterface
//
//  Created by Radan Ganchev on 15.05.19.
//  Copyright © 2019 Astea Solutions. All rights reserved.
//

import UIKit
import AVKit
import Alamofire

class ViewController: UIViewController, AVAudioRecorderDelegate {
    
    private let serverUrl = "http://172.27.25.156:3000"
    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    private let audioFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav");

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var pulseView: UIView!
    @IBOutlet weak var pulseViewWidth: NSLayoutConstraint!
    
    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder?
    private var initialPulseViewWidth: CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initialPulseViewWidth = pulseView.bounds.width
        pulseView.isHidden = true
        recordButton.isEnabled = false
        
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            
            try recordingSession.setCategory(.record, mode: .default, options: .allowBluetooth)
            try recordingSession.setActive(true)
            try recordingSession.setPreferredInput(recordingSession.availableInputs?.first { $0.portType == .bluetoothHFP })
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    self.recordButton.isEnabled = allowed;
                }
            }
        } catch {
            print("Recording failed!", error.localizedDescription)
        }
    }

    @IBAction func micTouchDown(_ sender: UIButton) {
        startRecording()
    }
    
    @IBAction func micTouchUp(_ sender: UIButton) {
        audioRecorder?.stop()
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        finishRecording(success: flag)
    }
    
    @objc func updateMeter() {
        if let audioRecorder = audioRecorder {
            audioRecorder.updateMeters()
            let audioPower = audioRecorder.averagePower(forChannel: 0)
            let pulseWidth = initialPulseViewWidth + CGFloat(max(80 + audioPower, 0))
            print(pulseWidth)
            DispatchQueue.main.async {
                self.pulseViewWidth.constant = pulseWidth
                self.pulseView.layer.cornerRadius = pulseWidth / 2
                self.pulseView.isHidden = false
            }
            Thread.sleep(forTimeInterval: 0.02)
            updateMeter()
        } else {
            DispatchQueue.main.async {
                self.pulseView.isHidden = true
            }
        }
    }
    
    private func startRecording() {
        do {
            Alamofire.request("\(serverUrl)/listen", method: .post)
            audioRecorder = try AVAudioRecorder(url: audioFileURL, format: audioFormat)
            audioRecorder!.isMeteringEnabled = true
            audioRecorder!.delegate = self
            audioRecorder!.record()
            performSelector(inBackground: #selector(updateMeter), with: self)
        } catch {
            print(error)
            finishRecording(success: false)
        }
    }
    
    private func finishRecording(success: Bool) {
        audioRecorder = nil
        if success {
            Alamofire.upload(
                multipartFormData: { $0.append(self.audioFileURL, withName: "speech") },
                to: "\(serverUrl)/listen/done",
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.response { print($0) }
                    case .failure(let encodingError):
                        print(encodingError)
                    }
                }
            )
        } else {
            print("Recording failed!")
        }
    }
    
}


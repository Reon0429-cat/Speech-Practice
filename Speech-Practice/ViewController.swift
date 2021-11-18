//
//  ViewController.swift
//  Speech-Practice
//
//  Created by 大西玲音 on 2021/11/18.
//

import UIKit
import Speech
import AVFoundation

typealias ResultHandler<T> = (Result<T, Error>) -> Void

final class SpeechRecorder {
    
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func startRecord(completion: @escaping ResultHandler<String?>) {
        if let recognitionTask = self.recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { buffer, time in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            completion(.failure(error))
        }
        let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "ja_JP"))!
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            DispatchQueue.main.async {
                let text = result?.bestTranscription.formattedString
                completion(.success(text))
            }
        }
    }
    
    func stopRecord() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }
    
}

final class ViewController: UIViewController {
    
    @IBOutlet private weak var textView: UITextView!
    @IBOutlet private weak var recordButton: UIButton!
    
    private let speechRecorder = SpeechRecorder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
                case .authorized:
                    break
                default:
                    DispatchQueue.main.async {
                        self.recordButton.isEnabled = false
                    }
            }
        }
        
    }
    
    @IBAction private func recordButtonDidTapped(_ sender: Any) {
        if recordButton.isSelected {
            speechRecorder.stopRecord()
            recordButton.setTitle("Start", for: .normal)
        } else {
            speechRecorder.startRecord { result in
                switch result {
                    case .failure(let error):
                        print("DEBUG_PRINT: ", error.localizedDescription)
                    case .success(let text):
                        self.textView.text = text
                }
            }
            recordButton.setTitle("Stop", for: .normal)
            textView.text = ""
        }
        recordButton.isSelected.toggle()
    }
    
}


//
//  ViewController.swift
//  Speech-Practice
//
//  Created by 大西玲音 on 2021/11/18.
//

import UIKit
import Speech
import AVFoundation

final class ViewController: UIViewController {
    
    @IBOutlet private weak var textView: UITextView!
    @IBOutlet private weak var startButton: UIButton!
    
    private var audioFile: AVAudioFile!
    private var croppedFiles = [File]()
    private var croppedFileCount = 0
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechText = ""
    private var currentIndex = 0

    private struct File {
        var url: URL
        var startTime: Double
        var endTime: Double
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SFSpeechRecognizer.requestAuthorization { status in
            
        }
        
    }
    
    private func cropFile() {
        if let audioPath = Bundle.main.path(forResource: "sample", ofType: "m4a") {
            let audioFileURL = URL(fileURLWithPath: audioPath)
            audioFile = try! AVAudioFile(forReading: audioFileURL)
            let recordedTime = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            let oneFileTime = Double(60)
            var startTime = Double(0)
            while startTime < recordedTime {
                let fullPath = NSHomeDirectory() + "/Library/croppedFile_" + String(croppedFiles.count) + ".m4a"
                if FileManager.default.fileExists(atPath: fullPath) {
                    try! FileManager.default.removeItem(atPath: fullPath)
                }
                let fullPathURL = URL(fileURLWithPath: fullPath)
                let endTime: Double = {
                    if startTime + oneFileTime <= recordedTime {
                        return startTime + oneFileTime
                    }
                    return recordedTime
                }()
                let file = File(url: fullPathURL, startTime: startTime, endTime: endTime)
                croppedFiles.append(file)
                startTime += oneFileTime
            }
            croppedFiles.forEach { file in
                exportAsynchronously(file: file)
            }
        }
    }
    
    private func exportAsynchronously(file: File) {
        let startCMTime = CMTimeMake(value: Int64(file.startTime), timescale: 1)
        let endCMTime = CMTimeMake(value: Int64(file.endTime), timescale: 1)
        let exportTimeRange = CMTimeRangeFromTimeToTime(start: startCMTime, end: endCMTime)
        let asset = AVAsset(url: audioFile.url)
        if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) {
            exporter.outputFileType = .m4a
            exporter.timeRange = exportTimeRange
            exporter.outputURL = file.url
            exporter.exportAsynchronously {
                switch exporter.status {
                    case .completed:
                        self.croppedFileCount += 1
                        if self.croppedFiles.count == self.croppedFileCount {
                            DispatchQueue.main.async {
                                self.initalizeSpeechFramework()
                            }
                        }
                    case .failed, .cancelled:
                        guard let errotText = exporter.error?.localizedDescription else { return }
                        print("DEBUG_PRINT: ", errotText)
                    default:
                        break
                }
            }
        }
    }
    
    private func initalizeSpeechFramework() {
        recognitionRequest = SFSpeechURLRecognitionRequest(url: croppedFiles[currentIndex].url)
        guard let localeIdentifier = NSLocale.preferredLanguages.first,
              let request = recognitionRequest else { return }
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
            if let error = error {
                print("DEBUG_PRINT: ", error)
                return
            }
            if let result = result {
                self.textView.text = self.speechText + result.bestTranscription.formattedString
                if result.isFinal {
                    self.finishOrRestartSpeechFramework()
                }
            }
        })
    }
    
    private func finishOrRestartSpeechFramework() {
        recognitionTask?.cancel()
        recognitionTask?.finish()
        speechText = textView.text
        currentIndex += 1
        if currentIndex < croppedFiles.count {
            initalizeSpeechFramework()
        }
    }
    
    @IBAction private func startButtonDidTapped(_ sender: Any) {
        textView.text = ""
        speechText = ""
        cropFile()
    }
    
}


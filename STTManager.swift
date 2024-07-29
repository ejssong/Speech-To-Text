//
//  STTManager.swift
//  BiometricIDAuth
//
//  Created by ejsong on 7/29/24.
//

import Foundation
import Speech

import RxSwift
import RxCocoa

public enum STTState {
    case initial
    case recording
    case paused
    
    var subTitle: String{
        switch self {
        case .initial, .paused: return "말하려면 누르세요"
        case .recording: return "일시정지하려면 누르세요"
        }
    }
}

final public class STTManager: NSObject, SFSpeechRecognizerDelegate {
    let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: Locale.preferredLanguages.first ?? "ko-KR"))
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()

    private var textBuffer: String = ""
    
    var _text: BehaviorRelay<String> = .init(value:"")
    
    var state: BehaviorRelay<STTState> = .init(value: .initial)
    
    var disposeBag = DisposeBag()
    
    override public init() {
        super.init()
        setDelegate()
        setAudio()
    }
    
    private func setDelegate() {
        speechRecognizer?.delegate = self
    }
    
    private func setAudio() {
        do {
            try audioSession.setCategory(.record, options: [.mixWithOthers, .defaultToSpeaker, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setMode(.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
    }
    
    // 마이크 녹음 권한 요청
    private func getRecordPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission() { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
    
    // STT 권한 요청
    private func getSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    //권한 요청 팝업
    private func openPermissionPopup() {
        DispatchQueue.main.async {
            let popupModel = PopupDefaultInfoModel(
                type: .simple,
                attribute: (title: nil,
                            message: "마이크 사용 권한이 없습니다.\n설정에서 권한을 활성화 해주세요",
                            cancelBtnIsHidden : false,
                            buttonTitle: "설정 이동"))
            
            let popupView = PopupView(model: popupModel)
            popupView.confirmAction = {
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                      UIApplication.shared.canOpenURL(settingsUrl) else { return }
                
                UIApplication.shared.open(settingsUrl)
            }
        
            UIApplication.getMostTopViewController()?.view.addSubview(popupView)
            popupView.snp.equalToSuperview()
        }
    }
    
    //마이크 녹음 권한 요청 및 STT 권한 요청
    func getPermission() {
        Task {
            let recordStatus = await getRecordPermission()
            let sttStatus = await getSpeechPermission()
            
            if recordStatus && sttStatus == .authorized {
                startRecording()
            }else {
                openPermissionPopup()
            }
        }
    }
    
    private func makeRecognitionRequest() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        //음성 인식 요청 생성
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            cleanup()
            return
        }
        
        //부분적 결과 보고 설정
        recognitionRequest.shouldReportPartialResults = false
        recognitionRequest.requiresOnDeviceRecognition = true
        
        //음성 인식 작업 설정
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] (result, error) in
            
            guard let self = self else { return }
            
            if self.state.value == .recording && result != nil {
                guard var text = result?.bestTranscription.formattedString else { return }
                self._text.accept(text)
                self.pauseRecording()
            }
        })
    }

    public func startRecording() {
        makeRecognitionRequest()
        state.accept(.recording)
        
        let inputNode = audioEngine.inputNode

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate != 0 else {
            print("sample Rate Error!")
            pauseRecording()
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            pauseRecording()
        }
    }
    
    public func pauseRecording() {
        state.accept(.paused)
        cleanup()
    }
    
    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }

    deinit {
        cleanup()
        do {
            try audioSession.setActive(false)
            
        } catch {
            print("AudioSession did not deactivate.")
        }
    }
}

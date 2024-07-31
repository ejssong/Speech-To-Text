# :bulb: Speech-To-Text (STT) ?  

> 음성 오디오를 텍스트로 자동 변환하는 과정
> 
> `import Speech`  프레임워크를 통해서 구현 할 수 있다. 

## STT 권한 요청 (Info.plist)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/9deec5fb-bf45-487a-a66f-e0a0eea8c0b9">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/219bfb47-cad9-4e0b-8110-62679ac6efc8">
  <img alt="sttInfoplist" src="https://github.com/user-attachments/assets/219bfb47-cad9-4e0b-8110-62679ac6efc8">
</picture>

## SFSpeechRecognizerDelegate
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/9c6d9617-2133-4751-bd5f-9e26d6031362">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/040e7851-e0cd-4db6-b9df-b233ec8da79e">
  <img alt="SFSpeechRecognizerDelegate" src="https://github.com/user-attachments/assets/040e7851-e0cd-4db6-b9df-b233ec8da79e">
</picture>

> → 주어진 SFSpeechRecognizer 객체가 변경 되면 호출 된다.

## SFSpeechRecognizer
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/e10ad776-6471-4e75-bf2e-67d51b810a1b">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/754ad06f-ca8f-4f33-aed7-9ba8d4f3a688">
  <img alt="STTSFSpeechRecognizer" src="https://github.com/user-attachments/assets/754ad06f-ca8f-4f33-aed7-9ba8d4f3a688">
</picture>

> → 실제 음성 인식 시작 시 결과 값이 리턴 되는 함수이다.
> 
> 주석에서 말하는 것과 같이,  `shouldReportPartialResults` 옵션에 따라 부분적 혹은 전체적인 결과 값을 받을 지 선택해 처리 할 수 있다.

## STT 로직
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/2011e79d-fc70-4eb3-b491-854ecbd9eaee">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/de546d4e-9c4f-4a1a-a215-1a93811f3729">
  <img width = 600 height = 750 alt="sttLogic" src="https://github.com/user-attachments/assets/de546d4e-9c4f-4a1a-a215-1a93811f3729">
</picture>

## 문제 및 해결
> 기존 스트리밍 청취 중 STT 사용 시 에러 떨어지면서 앱 크래시
> 
>  `com.apple.coreaudio.avfaudio, reason: 'required condition is false: isFormatSampleRateAndChannelCountValid(format)`
> 
> 해결 방안 : sample Rate이 0 으로 떨어지면 위 에러와 같이 크래시 나기 때문에 guard 문으로 체크 후 리턴 시켜준다.

```Swift
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let recordingFormat = inputNode.outputFormat(forBus: 0)

guard recordingFormat.sampleRate != 0 else { return }
```

> SampleRate 이 0으로 STT 실행 안되는 문제
> 
> → AVAudioSession.sharedInstance() 의 싱글톤 인스턴스를 가져와서 활성화 시켜준다.
> 
> 해결 방안 : 녹음 시작 시 카테고리 변경 해주고, 멈추면 기존에 사용하던 카테고리로 활성화 시켜 준다.
> 
> 기존에 AVAudioSession 을 사용하고 있는 경우라면, 모드가 바뀔때 마다 다시 세팅해 줘야한다.

```Swift
do {
  try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth, .interruptSpokenAudioAndMixWithOthers])
  try audioSession.setMode(.default)
  try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
} catch {
  print("audioSession properties weren't set because of an error.")
}
```

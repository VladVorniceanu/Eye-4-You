# Eye 4 You — On-Device Assistive Vision for iOS

> **Master's Thesis (2026)** — ASE București  
> **Author:** Vlad-Ioan Vorniceanu

## Summary

**Eye 4 You** is an iOS application I conceived and built as part of my Master's degree studies. Its purpose is to act as an **assistive tool for visually impaired users**, providing real-time scene understanding entirely on the device — no cloud calls, no data ever leaving the phone.

The app combines object detection, semantic classification, human pose estimation, and text-to-speech danger announcements into a single, privacy-preserving pipeline powered by Core ML and Vision.

---

## Motivation

Visually impaired users face a gap between expensive dedicated hardware and generic smartphone assistants that rely on cloud connectivity. Eye 4 You fills that gap by running a full visual analysis pipeline locally on an iPhone's Neural Engine — delivering low latency, offline capability, and complete privacy.

---

## Features

- **Live Detection** — real-time YOLO object detection over the camera stream with bounding-box overlays. Detected path hazards (people, vehicles, obstacles) are announced via TTS.
- **Capture & Analyze** — take a photo, review it, then run the full analysis pipeline (object detection + semantic enrichment + pose estimation).
- **Gallery Analysis** — pick an existing image from the photo library and run the same pipeline.
- **Danger Announcements** — `DangerAnnouncer` accumulates detection hits in a sliding window and speaks audible warnings before they become a collision risk, with per-label cooldowns to avoid repetition.
- **Body Pose Overlay** — Vision-based human pose estimation with keypoint visualization, toggleable on demand.

---

## ML Pipeline

All inference is on-device using Core ML, orchestrated through Vision:

| Model | Role |
|-------|------|
| **YOLO11n** (`yolo11n.mlpackage`) | Object detection — returns bounding boxes and class labels across 80 COCO classes. NMS runs in Swift. |
| **MobileNetV2** (`MobileNetV2.mlpackage`) | Semantic enrichment — classifies the top-3 YOLO detections by cropping their region and re-scoring for richer labels. |
| **Vision Body Pose** | Human pose estimation — skeleton keypoints rendered as an overlay. |

Compute units for YOLO are set to `.cpuAndNeuralEngine` for real-time performance. For photos, all three pipelines run concurrently via `async let`. For live frames, analysis is throttled to a configurable FPS via `CACurrentMediaTime`.

---

## Architecture

```
MainMenuView
├── Live Detection  →  CameraViewModel → CameraManager → CustomMLModel.analyzeLiveFrame
│                                                      → DangerAnnouncer (TTS)
├── Capture Photo   →  CameraDelegate  → PhotoReview  → MLAnalysisViewModel
│                                                      → CustomMLModel.analyzePhoto
└── Gallery Pick    →  PHPicker        → PhotoReview  → MLAnalysisViewModel
                                                       → CustomMLModel.analyzePhoto
```

`CustomMLModel` is a singleton facade that owns both VNCoreML model instances and serializes all inference on a concurrent `.userInitiated` dispatch queue. All model state is protected by `NSLock`.

---

## Technologies

- **Swift / SwiftUI** — 100% Swift, MVVM architecture
- **Core ML** — on-device model inference (YOLO11n, MobileNetV2)
- **Vision** — VNCoreMLRequest, body pose detection
- **AVFoundation** — live camera session, photo capture
- **AVSpeechSynthesizer** — TTS danger announcements
- **OSLog** — structured logging via `AppLogger`

---

## How to Run

1. Clone the repository and open `PhotoDex.xcodeproj` in Xcode.
2. Select a **real iPhone** — the Neural Engine and camera are required; Simulator has limited support.
3. Build and run. Grant camera and photo library permissions on first launch.
4. ML models warm up in the background on the main menu; "Live Detection" becomes available once they are ready.

---

## Privacy

Eye 4 You processes everything on-device. No images, detections, or user data are ever transmitted to a server. This is a core design constraint, not an afterthought.

---

## License

Code and resources are published under the repository's default license. Bundled ML model weights may carry separate upstream licenses — check source licenses before reusing them in commercial projects.

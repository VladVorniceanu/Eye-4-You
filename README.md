# PhotoDex — iOS Application for *On-Device* Image Analysis (Proof of Concept)

> **Bachelor’s Thesis (2024)** — *Mobile Application: Support for Assisted Learning*  
> **Author:** Vlad-Ioan Vorniceanu • **Scientific Coordinator:** Assoc. Prof. PhD Mihai Doinea

## Summary

**PhotoDex** is my first iOS application developed individually, created as part of my bachelor’s thesis (2024). The project was designed as a **Proof of Concept** for the idea that the current iOS ecosystem (Core ML + Vision) enables running **complex data processing and Machine Learning models directly on the device** (*on-device*), without relying on external services.

The application analyzes photos and live camera frames for:
- **object detection** within the scene,
- **person identification/localization** and body pose estimation (Body Pose),
- presenting results in an interface focused on **speed, privacy, and practical usability**.

---

## Motivation and Context

The evolution of digital photography (high resolutions, large volumes of visual data) increases the need for tools that can **understand image content** quickly and locally. At the same time, privacy and latency make *cloud-only* solutions less suitable for real-time use cases.

PhotoDex addresses these needs through an architecture that runs **local ML inference**, in real time, on iPhone/iPad.

---

## Objectives

1. **Image capture for analysis**  
   Integration of a camera module within the application, enabling an end-to-end flow.

2. **Local image processing (on-device ML)**  
   Integration and execution of ML models using **Core ML**, orchestrated through **Vision**.

3. **LIVE frame analysis**  
   Real-time analysis of the camera video stream, with results displayed as overlays.

---

## Main Features

- **LIVE frame analysis** (camera stream)
- **Image capture** from the camera
- **Image selection from gallery**
- **Analysis of captured/selected images** and display of results (detections / labels / pose)

---

## Architecture (overview)

The logical flow is built around a local processing pipeline:

1. **Capture** via `CameraManager` and `CameraDelegate`, followed by confirmation to initiate analysis.
2. **Inference** through Vision requests, using integrated Core ML models (e.g., *YOLOv5s* and *MobileNetV2*), alongside **Body Pose Detection**.
3. **Result fusion**: the combination of outputs (detections + classification/semantics + pose) is rendered in the UI; Body Pose keypoints can be displayed on demand.

> Note: the models and exact integration details are those included in the project (within the app folder / Core ML resources).

---

## Technologies Used

- **Swift / iOS**
- **Core ML** — integration and execution of ML models on-device
- **Vision** — pre- and post-processing, analysis requests, and Body Pose Detection
- **AVFoundation** (implicitly, for camera capture), where necessary

---

## Slides from Thesis Presentation

### Introduction / context
<img width="2880" height="1620" alt="slide_2" src="https://github.com/user-attachments/assets/688c0fc3-9482-4047-850d-9cd381a9c706" />

### Objectives and benefits
<img width="2880" height="1620" alt="slide_3" src="https://github.com/user-attachments/assets/11a9e915-7218-4703-b4d4-7fe83dee666d" />

### Main features
<img width="2880" height="1620" alt="slide_5" src="https://github.com/user-attachments/assets/0906e554-d749-432a-9a72-189258c3d71b" />

### Architecture (flow diagram)
<img width="2880" height="1620" alt="slide_6" src="https://github.com/user-attachments/assets/2fa72704-b5e3-48c6-b61f-bd002b19472c" />

---

## How to Run the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/VladVorniceanu/Licenta2024.git
   ```
2. Open the project in Xcode:
   - `PhotoDex.xcodeproj`
3. Select a **real iPhone** (recommended for camera + ML performance) and run.
4. On first launch, grant camera permission (if requested by the app).

> Note: In the Simulator, camera access and ML performance may be limited.

---

## Demonstrative Value (Proof of Concept)

PhotoDex practically demonstrates that:
- ML inference and visual analysis can be performed **locally**, with low latency,
- privacy is improved by avoiding sending images to servers,
- mobile applications can integrate “heavy” pipelines (detection + pose analysis) into usable UX flows.

---

## Limitations and Future Directions

- systematic comparative evaluations (accuracy / FPS / energy consumption) across multiple devices;
- UI/UX improvements for specific educational use cases;
- expansion of detectable classes and result filtering strategies;
- additional performance optimizations (quantization, batching, frame throttling).

---

## License and Notes

- The code and resources in this repository are published according to the repo settings.
- Included ML models may have separate licenses; check source licenses if reusing models/weights in commercial projects.

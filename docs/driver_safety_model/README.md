# On-Device Driver Safety Model

This folder contains a minimal pipeline to create a placeholder TensorFlow Lite model for on-device inference. The app expects `assets/models/driver_safety.tflite`.

- `make_dummy_model.py`: Generates a tiny TFLite model with a [1,N] float input and [1,3] float output (brake, turn, accel). It does not implement real classification; it outputs a linear projection for demo/testing.
- After generating, copy the `.tflite` into `assets/models/` and run `flutter pub get` to ensure the asset is bundled.

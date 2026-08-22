# google_mlkit_text_recognition (Make Searchable / OCR) references optional
# per-script recognizer classes (Chinese/Devanagari/Japanese/Korean) that
# aren't present at all, since we only depend on the base package and use
# TextRecognitionScript.latin — R8 can't verify code it can't find, so tell
# it these are safe to ignore rather than failing the build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

from flask import Flask, request, jsonify
import os
from vosk import Model, KaldiRecognizer
import wave
from pydub import AudioSegment
import json

app = Flask(__name__)

print("Loading Vosk model...")
model_path = r"C:\Users\sunra\OneDrive\Documents\SRM\researchpapers\vosk-model-small-en-in-0.4"
if not os.path.exists(model_path):
    print(f"Model not found at {model_path}. Please download it from https://alphacephei.com/vosk/models")
    exit(1)
model = Model(model_path)
print("Vosk model loaded successfully")

@app.route('/transcribe', methods=['POST'])
def transcribe_audio():
    if 'file' not in request.files:
        print("No file uploaded")
        return jsonify({"error": "No file uploaded"}), 400
    
    audio_file = request.files['file']
    audio_path = "temp_audio.aac"
    wav_path = "temp_audio.wav"
    
    print(f"Saving audio to: {audio_path}")
    audio_file.save(audio_path)
    print(f"File saved, size: {os.path.getsize(audio_path)} bytes")
    
    try:
        print(f"Converting AAC to WAV: {wav_path}")
        audio = AudioSegment.from_file(audio_path, format="aac").set_channels(1).set_frame_rate(16000)
        audio.export(wav_path, format="wav")
        print(f"WAV file created, duration: {audio.duration_seconds}s")
        
        print(f"Transcribing file: {wav_path}")
        wf = wave.open(wav_path, "rb")
        try:
            if wf.getnchannels() != 1 or wf.getframerate() != 16000:
                print("Audio format error: Must be mono, 16kHz")
                return jsonify({"error": "Invalid audio format"}), 500
            
            rec = KaldiRecognizer(model, wf.getframerate())
            while True:
                data = wf.readframes(4000)
                if len(data) == 0:
                    break
                rec.AcceptWaveform(data)
            
            result = rec.Result()
            transcribed_text = json.loads(result).get("text", "").strip().lower()  # Ensure lowercase
            print(f"Transcribed text: '{transcribed_text}'")
        finally:
            wf.close()
    except Exception as e:
        print(f"Error in transcription: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if os.path.exists(audio_path):
            os.remove(audio_path)
            print(f"Removed: {audio_path}")
        if os.path.exists(wav_path):
            os.remove(wav_path)
            print(f"Removed: {wav_path}")

    return jsonify({"transcription": transcribed_text})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
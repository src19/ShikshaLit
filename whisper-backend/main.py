from flask import Flask, request, jsonify
import os
import whisper
from pydub import AudioSegment

app = Flask(__name__)
model = whisper.load_model("small")  # ~769 MB, download once

@app.route('/transcribe', methods=['POST'])
def transcribe_audio():
    audio_file = request.files['file']
    audio_path = "temp_audio.aac"
    wav_path = "temp_audio.wav"
    audio_file.save(audio_path)
    audio = AudioSegment.from_file(audio_path, format="aac").set_channels(1).set_frame_rate(16000)
    audio.export(wav_path, format="wav")
    result = model.transcribe(wav_path, language="en")
    transcribed_text = result["text"].strip().lower()
    os.remove(audio_path)
    os.remove(wav_path)
    return jsonify({"transcription": transcribed_text})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
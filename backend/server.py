from flask import Flask, request, jsonify
from ultralytics import YOLO
import cv2
import numpy as np

app = Flask(__name__)

# Load YOLO model
MODEL_PATH = "best.pt"
model = YOLO(MODEL_PATH)

@app.route('/detect', methods=['POST'])
def detect_alphabet():
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    file = request.files['image'].read()
    npimg = np.frombuffer(file, np.uint8)
    image = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    results = model([image])

    predictions = []
    for result in results:
        if result.boxes is not None:
            boxes = result.boxes.xywh.numpy()
            confidences = result.boxes.conf.numpy()
            classes = result.boxes.cls.numpy()

            for box, conf, cls in zip(boxes, confidences, classes):
                prediction = {
                    "x": float(box[0]),
                    "y": float(box[1]),
                    "width": float(box[2]),
                    "height": float(box[3]),
                    "confidence": float(conf),
                    "class": result.names[int(cls)],
                    "class_id": int(cls),
                    "detection_id": None
                }
                predictions.append(prediction)

    # Sort predictions by X-axis for correct letter order
    predictions = sorted(predictions, key=lambda p: p["x"])

    # Extract detected letters
    alphabet_value = "".join([p["class"] for p in predictions])

    return jsonify({
        "predictions": predictions,
        "detected_text": alphabet_value
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

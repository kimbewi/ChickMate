from flask import Flask, Response
import cv2

app = Flask(__name__)
video = cv2.VideoCapture(0)  # Use 0 for the default webcam

def generate_frames():
    while True:
        success, frame = video.read()  # Read a frame from the webcam
        if not success:
            break
        else:
            # Encode the frame as JPEG
            ret, buffer = cv2.imencode('.jpg', frame)
            frame_bytes = buffer.tobytes()
            
            # Yield the frame in the multipart format
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

@app.route('/video_feed')
def video_feed():
    # Return the streaming response
    return Response(generate_frames(), 
                    mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    # Run the app, making it accessible from any IP on the network
    app.run(host='0.0.0.0', port=8000)
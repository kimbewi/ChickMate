# the ff code is for laptop/raspi server to stream webcam and microphone via WebRTC
import asyncio
import json
import logging
import cv2
import pyaudio
import websockets
import time
import fractions
import numpy
from av import VideoFrame, AudioFrame
from aiortc import (
    RTCPeerConnection,
    RTCSessionDescription,
    VideoStreamTrack,
    AudioStreamTrack,
    RTCIceCandidate,
)
from aiortc.rtcrtpreceiver import RTCRtpReceiver

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Media Capture Classes ---

class MyCameraTrack(VideoStreamTrack):
    """A video track that captures from your webcam."""

    def __init__(self):
        super().__init__()
        logger.info("Opening camera...")
        self.cap = cv2.VideoCapture(0)  # Open camera
        if not self.cap.isOpened():
            logger.error("Could not open camera")
            self.cap = None
            return
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        logger.info("Camera opened")

    async def recv(self):
        pts, time_base = await self.next_timestamp()
        
        # Check if camera is open
        if not self.cap or not self.cap.isOpened():
            logger.warning("Camera is not open, returning empty frame")
            # Create a blank black frame to keep the stream alive
            empty_frame_data = numpy.zeros((480, 640, 3), dtype=numpy.uint8)
            video_frame = VideoFrame.from_ndarray(empty_frame_data, format="rgb24")
            video_frame.pts = pts
            video_frame.time_base = time_base
            return video_frame

        ret, frame = self.cap.read()
        if not ret:
            logger.warning("Failed to read frame from camera")
            return await self.recv() # Try again

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Create an empty frame (Fix for MemoryError)
        video_frame = VideoFrame(width=frame_rgb.shape[1], height=frame_rgb.shape[0], format="rgb24")
        # Copy the numpy array data directly into the frame's memory plane
        video_frame.planes[0].update(frame_rgb.tobytes())
        
        video_frame.pts = pts
        video_frame.time_base = time_base

        return video_frame

    # This method is called when the connection closes
    def stop(self):
        super().stop()
        if self.cap:
            logger.info("Releasing camera")
            self.cap.release()
            self.cap = None


class MyMicrophoneTrack(AudioStreamTrack):
    """An audio track that captures from your microphone."""

    _start_time = None
    _timestamp = 0

    def __init__(self):
        super().__init__()
        self.p = pyaudio.PyAudio()
        self.FORMAT = pyaudio.paInt16
        self.CHANNELS = 1
        self.RATE = 48000
        self.FRAMES_PER_BUFFER = 960  # 20ms of audio

        self.stream = self.p.open(
            format=self.FORMAT,
            channels=self.CHANNELS,
            rate=self.RATE,
            input=True,
            frames_per_buffer=self.FRAMES_PER_BUFFER,
            input_device_index=1,  # Use your correct index
        )
        logger.info("Microphone stream opened (Index 1)")

    async def recv(self):
        if self._start_time is None:
            self._start_time = time.time()

        try:
            data = self.stream.read(self.FRAMES_PER_BUFFER, exception_on_overflow=False)
        except IOError as e:
            logger.warning(f"PyAudio read error: {e}")
            data = b"\x00" * self.FRAMES_PER_BUFFER * self.CHANNELS * 2

        audio_frame = AudioFrame(format="s16", layout="mono", samples=self.FRAMES_PER_BUFFER)
        audio_frame.planes[0].update(
            numpy.frombuffer(data, dtype=numpy.int16).reshape(1, -1)
        )

        self._timestamp += self.FRAMES_PER_BUFFER
        audio_frame.pts = self._timestamp
        audio_frame.sample_rate = self.RATE
        audio_frame.time_base = fractions.Fraction(1, self.RATE)

        return audio_frame

    def stop(self):
        super().stop()
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None
        if self.p:
            self.p.terminate()
            self.p = None
        logger.info("Microphone stream stopped")


# --- WebRTC and Signaling ---

pc = RTCPeerConnection()


@pc.on("track")
def on_track(track):
    logger.info(f"Receiving track: {track.kind}")


async def run_signaling(websocket):
    global pc  
    logger.info("Connected to signaling server")

    # Add tracks to the peer connection
    pc.addTrack(MyCameraTrack())
    pc.addTrack(MyMicrophoneTrack())

    try:
        async for message in websocket:
            data = json.loads(message)

            if data["type"] == "offer":
                logger.info("Received offer, setting remote description")
                await pc.setRemoteDescription(
                    RTCSessionDescription(sdp=data["sdp"], type=data["type"])
                )

                logger.info("Creating answer")
                answer = await pc.createAnswer()
                await pc.setLocalDescription(answer)

                await websocket.send(
                    json.dumps({"type": "answer", "sdp": pc.localDescription.sdp})
                )

            elif data["type"] == "candidate":
                logger.info("Received ICE candidate (ignoring)")
                pass

    except websockets.exceptions.ConnectionClosed:
        logger.info("Signaling connection closed")
    except Exception as e:
        logger.error(f"Error in signaling: {e}")
    finally:
        logger.info("Cleaning up peer connection")
        # When pc.close() is called, it will now trigger
        # the .stop() methods on BOTH tracks.
        await pc.close()
        # We need a new PC object for the next connection
        pc = RTCPeerConnection()


async def main():
    # !!! IMPORTANT: Replace with your Tailscale IP !!!
    uri = "ws://100.76.87.115:8765"

    logger.info(f"Attempting to connect to signaling server at {uri}")
    while True:
        try:
            async with websockets.connect(uri) as websocket:
                await run_signaling(websocket)
        except Exception as e:
            logger.error(f"Failed to connect to signaling: {e}. Retrying in 5s...")
            await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(main())
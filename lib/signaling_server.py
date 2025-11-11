# the ff code is for server (raspi, laptop, etc.) to facilitate WebRTC signaling
import asyncio
import websockets
import json
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
CLIENTS = set()

async def handler(websocket):
    """
    Handle a new client connection. Add them to the CLIENTS set
    and forward their messages to all other clients.
    """
    CLIENTS.add(websocket)
    logging.info(f"Client connected. Total clients: {len(CLIENTS)}")
    try:
        # Listen for messages from this client
        async for message in websocket:
            logging.info(f"Received message: {message[:70]}...")
            
            # Create a list of other clients to forward the message to
            # This prevents sending the message back to the sender
            other_clients = [client for client in CLIENTS if client != websocket]
            
            if other_clients:
                # Use asyncio.gather to send all messages concurrently
                await asyncio.gather(*[client.send(message) for client in other_clients])
                    
    except websockets.exceptions.ConnectionClosed as e:
        logging.info(f"Client disconnected: {e}")
    except Exception as e:
        logging.error(f"An error occurred with a client: {e}")
    finally:
        # Remove client when they disconnect
        CLIENTS.remove(websocket)
        logging.info(f"Client removed. Total clients: {len(CLIENTS)}")

async def main():
    # Run the server on your local network
    # Port 8765 is a common choice for WebSockets
    logging.info("Signaling server starting on ws://0.0.0.0:8765")
    async with websockets.serve(handler, "0.0.0.0", 8765):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
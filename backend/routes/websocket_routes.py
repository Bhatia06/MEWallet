from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from core.websocket_manager import manager
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["WebSocket"])

@router.websocket("/connect/{user_type}/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    user_type: str,
    user_id: str,
):
    """
    WebSocket endpoint for real-time updates
    user_type: 'user' or 'merchant'
    user_id: user_id or merchant_id
    """
    await manager.connect(websocket, user_id, user_type)
    
    try:
        # Send connection success message
        await websocket.send_json({
            "event": "connected",
            "message": f"{user_type.capitalize()} {user_id} connected successfully"
        })
        
        # Keep connection alive and handle incoming messages
        while True:
            # Receive messages from client (heartbeat, etc.)
            data = await websocket.receive_json()
            
            # Handle ping/pong for keeping connection alive
            if data.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id, user_type)
        logger.info(f"{user_type.capitalize()} {user_id} disconnected")
    except Exception as e:
        logger.error(f"WebSocket error for {user_type} {user_id}: {str(e)}")
        manager.disconnect(websocket, user_id, user_type)

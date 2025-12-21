from fastapi import WebSocket
from typing import Dict, List, Set
import json
import logging

logger = logging.getLogger(__name__)

class ConnectionManager:
    """Manages WebSocket connections for users and merchants"""
    
    def __init__(self):
        # Store active connections: {user_id: [websocket1, websocket2, ...]}
        self.user_connections: Dict[str, List[WebSocket]] = {}
        # Store active merchant connections: {merchant_id: [websocket1, websocket2, ...]}
        self.merchant_connections: Dict[str, List[WebSocket]] = {}
        
    async def connect(self, websocket: WebSocket, user_id: str, user_type: str):
        """Add a new WebSocket connection"""
        await websocket.accept()
        
        if user_type == "user":
            if user_id not in self.user_connections:
                self.user_connections[user_id] = []
            self.user_connections[user_id].append(websocket)
            logger.info(f"User {user_id} connected. Total connections: {len(self.user_connections[user_id])}")
        else:  # merchant
            if user_id not in self.merchant_connections:
                self.merchant_connections[user_id] = []
            self.merchant_connections[user_id].append(websocket)
            logger.info(f"Merchant {user_id} connected. Total connections: {len(self.merchant_connections[user_id])}")
    
    def disconnect(self, websocket: WebSocket, user_id: str, user_type: str):
        """Remove a WebSocket connection"""
        try:
            if user_type == "user":
                if user_id in self.user_connections:
                    self.user_connections[user_id].remove(websocket)
                    if not self.user_connections[user_id]:
                        del self.user_connections[user_id]
                    logger.info(f"User {user_id} disconnected")
            else:  # merchant
                if user_id in self.merchant_connections:
                    self.merchant_connections[user_id].remove(websocket)
                    if not self.merchant_connections[user_id]:
                        del self.merchant_connections[user_id]
                    logger.info(f"Merchant {user_id} disconnected")
        except Exception as e:
            logger.error(f"Error disconnecting: {str(e)}")
    
    async def send_to_user(self, user_id: str, message: dict):
        """Send message to all connections of a specific user"""
        if user_id in self.user_connections:
            disconnected = []
            for websocket in self.user_connections[user_id]:
                try:
                    await websocket.send_json(message)
                    logger.info(f"Sent message to user {user_id}: {message.get('event')}")
                except Exception as e:
                    logger.error(f"Error sending to user {user_id}: {str(e)}")
                    disconnected.append(websocket)
            
            # Clean up disconnected websockets
            for ws in disconnected:
                self.disconnect(ws, user_id, "user")
    
    async def send_to_merchant(self, merchant_id: str, message: dict):
        """Send message to all connections of a specific merchant"""
        if merchant_id in self.merchant_connections:
            disconnected = []
            for websocket in self.merchant_connections[merchant_id]:
                try:
                    await websocket.send_json(message)
                    logger.info(f"Sent message to merchant {merchant_id}: {message.get('event')}")
                except Exception as e:
                    logger.error(f"Error sending to merchant {merchant_id}: {str(e)}")
                    disconnected.append(websocket)
            
            # Clean up disconnected websockets
            for ws in disconnected:
                self.disconnect(ws, merchant_id, "merchant")
    
    def is_user_connected(self, user_id: str) -> bool:
        """Check if a user has any active connections"""
        return user_id in self.user_connections and len(self.user_connections[user_id]) > 0
    
    def is_merchant_connected(self, merchant_id: str) -> bool:
        """Check if a merchant has any active connections"""
        return merchant_id in self.merchant_connections and len(self.merchant_connections[merchant_id]) > 0
    
    async def broadcast_payment_to_merchant(self, merchant_id: str, payment_data: dict):
        """Broadcast payment notification to merchant"""
        message = {
            "event": "payment_received",
            "data": payment_data
        }
        await self.send_to_merchant(merchant_id, message)
    
    async def broadcast_balance_add_to_merchant(self, merchant_id: str, balance_data: dict):
        """Broadcast balance add notification to merchant"""
        message = {
            "event": "balance_added",
            "data": balance_data
        }
        await self.send_to_merchant(merchant_id, message)
    
    async def broadcast_payment_request_to_user(self, user_id: str, request_data: dict):
        """Broadcast payment request to user"""
        message = {
            "event": "payment_requested",
            "data": request_data
        }
        await self.send_to_user(user_id, message)
    
    async def broadcast_balance_update_to_user(self, user_id: str, balance_data: dict):
        """Broadcast balance update to user"""
        message = {
            "event": "balance_updated",
            "data": balance_data
        }
        await self.send_to_user(user_id, message)

# Global connection manager instance
manager = ConnectionManager()

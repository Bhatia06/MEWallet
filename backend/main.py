from fastapi import FastAPI, Request, status, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.exceptions import RequestValidationError
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from contextlib import asynccontextmanager
from merchant_routes import router as merchant_router
from user_routes import router as user_router
from transaction_routes import router as transaction_router
from balance_request_routes import router as balance_request_router
from link_request_routes import router as link_request_router
from oauth_routes import router as oauth_router
from routes.pay_request_routes import router as pay_request_router
from database import test_connection
import uvicorn

# Rate limiter setup
limiter = Limiter(key_func=get_remote_address)

# Lifespan event handler
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("MEWallet API starting")
    if test_connection():
        print("Database connection successful")
    else:
        print("Database connection failed. Check your .env file")
    
    yield
    
    # Shutdown
    print("MEWallet API is shutting down...")

# Create FastAPI app
app = FastAPI(
    title="MEWallet API",
    description="Digital Wallet API for Merchant-User transactions",
    version="1.0.0",
    lifespan=lifespan
)

# Add rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Middleware to block browser access to API endpoints
@app.middleware("http")
async def block_browser_access(request: Request, call_next):
    """Block direct browser access to API endpoints"""
    path = request.url.path
    
    # Allow health check and root endpoint
    if path in ["/", "/health", "/docs", "/redoc", "/openapi.json"]:
        return await call_next(request)
    
    # Check if request is from a browser (has Accept: text/html)
    accept_header = request.headers.get("accept", "")
    user_agent = request.headers.get("user-agent", "")
    
    # Block if it looks like a browser request
    if "text/html" in accept_header and "Mozilla" in user_agent:
        return HTMLResponse(
            content="""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Access Denied - MEWallet API</title>
                <style>
                    body { font-family: Arial, sans-serif; background: #1a1d29; color: #f5f5dc; 
                           display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                    .container { text-align: center; max-width: 600px; padding: 40px; }
                    h1 { color: #ff6b6b; font-size: 48px; margin-bottom: 20px; }
                    p { font-size: 18px; line-height: 1.6; }
                    .code { background: #252838; padding: 20px; border-radius: 8px; margin-top: 20px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>⛔ Access Denied</h1>
                    <p>Direct browser access to API endpoints is not allowed.</p>
                    <p>This API is designed to be accessed programmatically through the MEWallet mobile application.</p>
                    <div class="code">
                        <p><strong>Error Code:</strong> 403 Forbidden</p>
                        <p><strong>Endpoint:</strong> {}</p>
                    </div>
                </div>
            </body>
            </html>
            """.format(path),
            status_code=403
        )
    
    return await call_next(request)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle validation errors"""
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "detail": "Validation error",
            "errors": exc.errors()
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions"""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "An internal error occurred",
            "error": str(exc)
        }
    )


@app.get("/", tags=["Root"])
@limiter.limit("10/minute")
async def root(request: Request):
    """Root endpoint"""
    return {
        "message": "Welcome to MEWallet API",
        "version": "1.0.0",
        "status": "active"
    }


@app.get("/health", tags=["Health"])
@limiter.limit("30/minute")
async def health_check(request: Request):
    """Health check endpoint"""
    db_status = test_connection()
    return {
        "status": "healthy" if db_status else "degraded",
        "database": "connected" if db_status else "disconnected"
    }


app.include_router(merchant_router)
app.include_router(user_router)
app.include_router(transaction_router)
app.include_router(balance_request_router)
app.include_router(link_request_router)
app.include_router(oauth_router)
app.include_router(pay_request_router)


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )

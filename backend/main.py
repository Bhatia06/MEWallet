from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from merchant_routes import router as merchant_router
from user_routes import router as user_router
from transaction_routes import router as transaction_router
from balance_request_routes import router as balance_request_router
from database import test_connection
import uvicorn

# Create FastAPI app
app = FastAPI(
    title="MEWallet API",
    description="Digital Wallet API for Merchant-User transactions",
    version="1.0.0"
)

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
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to MEWallet API",
        "version": "1.0.0",
        "status": "active"
    }


@app.get("/health", tags=["Health"])
async def health_check():
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

@app.on_event("startup")
async def startup_event():
    """Run on startup"""
    print("🚀 MEWallet API is starting...")
    if test_connection():
        print("✅ Database connection successful")
    else:
        print("❌ Database connection failed - check your .env file")


# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    """Run on shutdown"""
    print("👋 MEWallet API is shutting down...")


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )

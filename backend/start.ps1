# MEWallet Backend Startup Script
# Run this script to start the backend server

Write-Host "🚀 Starting MEWallet Backend Server..." -ForegroundColor Cyan
Write-Host ""

# Check if virtual environment exists
if (-Not (Test-Path "venv")) {
    Write-Host "❌ Virtual environment not found!" -ForegroundColor Red
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    Write-Host "✅ Virtual environment created!" -ForegroundColor Green
}

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& ".\venv\Scripts\Activate.ps1"

# Check if .env exists
if (-Not (Test-Path ".env")) {
    Write-Host ""
    Write-Host "⚠️  WARNING: .env file not found!" -ForegroundColor Yellow
    Write-Host "Creating .env from template..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host ""
    Write-Host "❌ IMPORTANT: Please edit .env file and add your Supabase credentials!" -ForegroundColor Red
    Write-Host "   1. Open .env file" -ForegroundColor Yellow
    Write-Host "   2. Add your SUPABASE_URL" -ForegroundColor Yellow
    Write-Host "   3. Add your SUPABASE_ANON_KEY" -ForegroundColor Yellow
    Write-Host "   4. Generate SECRET_KEY (run: python -c 'import secrets; print(secrets.token_hex(32))')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Check if dependencies are installed
Write-Host "Checking dependencies..." -ForegroundColor Yellow
$pipList = pip list
if (-Not ($pipList -match "fastapi")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
    Write-Host "✅ Dependencies installed!" -ForegroundColor Green
}

# Start the server
Write-Host ""
Write-Host "✅ Starting MEWallet API Server..." -ForegroundColor Green
Write-Host ""
Write-Host "📡 Server will run at: http://localhost:8000" -ForegroundColor Cyan
Write-Host "📚 API Docs available at: http://localhost:8000/docs" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

python main.py

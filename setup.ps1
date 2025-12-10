# MEWallet - First Time Setup Script

Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     MEWallet - First Time Setup           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Python
Write-Host "Step 1: Checking Python installation..." -ForegroundColor Yellow
$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Python found: $pythonVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Python not found! Please install Python 3.8 or higher." -ForegroundColor Red
    exit
}

# Step 2: Check Flutter
Write-Host ""
Write-Host "Step 2: Checking Flutter installation..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Flutter found!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Flutter not found! Install Flutter to build the mobile app." -ForegroundColor Yellow
}

# Step 3: Setup Backend
Write-Host ""
Write-Host "Step 3: Setting up backend..." -ForegroundColor Yellow
Set-Location backend

if (-Not (Test-Path "venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

& ".\venv\Scripts\Activate.ps1"

Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

if (-Not (Test-Path ".env")) {
    Write-Host "Creating .env file..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
}

Write-Host "✅ Backend setup complete!" -ForegroundColor Green

Set-Location ..

# Step 4: Setup Mobile App
Write-Host ""
Write-Host "Step 4: Setting up mobile app..." -ForegroundColor Yellow

if ($LASTEXITCODE -eq 0) {
    Set-Location mobile_app
    Write-Host "Installing Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    Write-Host "✅ Mobile app setup complete!" -ForegroundColor Green
    Set-Location ..
} else {
    Write-Host "⚠️  Skipping mobile app setup (Flutter not installed)" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          Setup Complete!                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Set up Supabase:" -ForegroundColor Yellow
Write-Host "   • Go to https://supabase.com" -ForegroundColor White
Write-Host "   • Create a new project" -ForegroundColor White
Write-Host "   • Run backend/schema.sql in SQL Editor" -ForegroundColor White
Write-Host "   • Get your URL and Anon Key from Settings → API" -ForegroundColor White
Write-Host ""
Write-Host "2. Configure Backend:" -ForegroundColor Yellow
Write-Host "   • Edit backend/.env file" -ForegroundColor White
Write-Host "   • Add your SUPABASE_URL and SUPABASE_ANON_KEY" -ForegroundColor White
Write-Host "   • Generate SECRET_KEY (see .env.example for command)" -ForegroundColor White
Write-Host ""
Write-Host "3. Configure Mobile App:" -ForegroundColor Yellow
Write-Host "   • Edit mobile_app/lib/utils/config.dart" -ForegroundColor White
Write-Host "   • Set baseUrl to your backend URL" -ForegroundColor White
Write-Host ""
Write-Host "4. Start the Backend:" -ForegroundColor Yellow
Write-Host "   cd backend" -ForegroundColor White
Write-Host "   .\start.ps1" -ForegroundColor White
Write-Host ""
Write-Host "5. Run the Mobile App:" -ForegroundColor Yellow
Write-Host "   cd mobile_app" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor White
Write-Host ""
Write-Host "📚 For detailed instructions, see:" -ForegroundColor Cyan
Write-Host "   • README.md - Complete documentation" -ForegroundColor White
Write-Host "   • QUICKSTART.md - Quick setup guide" -ForegroundColor White
Write-Host "   • GUIDE.md - Technical details" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

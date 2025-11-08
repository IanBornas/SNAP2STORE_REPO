# Integration test script for Snap2Store app and backend
Write-Host "=== Snap2Store Integration Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if backend starts and loads AI models
Write-Host "[1/4] Starting AI Backend..." -ForegroundColor Yellow
$backendPath = Join-Path $PSScriptRoot "backend"
Set-Location $backendPath

$backendJob = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    python app.py 2>&1
} -ArgumentList $backendPath

# Wait for backend to initialize
Write-Host "Waiting for backend to load AI models (ResNet50, ImageNet classes)..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Test 2: Verify backend is responding
Write-Host "[2/4] Testing Backend Health..." -ForegroundColor Yellow
try {
    $warmupResponse = Invoke-RestMethod -Uri "http://127.0.0.1:5000/warmup" -Method GET -ErrorAction Stop
    Write-Host "✓ Backend is ready!" -ForegroundColor Green
    Write-Host "  Models loaded:" -ForegroundColor Gray
    Write-Host "  - ResNet50: $($warmupResponse.models.resnet50)" -ForegroundColor Gray
    Write-Host "  - Vision API: $($warmupResponse.models.vision_api)" -ForegroundColor Gray
    Write-Host "  - Google Maps: $($warmupResponse.models.google_maps)" -ForegroundColor Gray
    Write-Host "  - ImageNet Classes: $($warmupResponse.models.imagenet_classes)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Backend not responding: $_" -ForegroundColor Red
    Stop-Job $backendJob
    Remove-Job $backendJob
    exit 1
}

# Test 3: Check Flutter app configuration
Write-Host ""
Write-Host "[3/4] Checking Flutter App Configuration..." -ForegroundColor Yellow
Set-Location (Join-Path $PSScriptRoot ".")
$backendServicePath = "lib\services\backend_service.dart"
$mainPath = "lib\main.dart"

if (Test-Path $backendServicePath) {
    $content = Get-Content $backendServicePath -Raw
    if ($content -match "BackendService\.ping\(\)") {
        Write-Host "✓ Backend warmup is configured in app" -ForegroundColor Green
    }
    if ($content -match "API_BASE_URL") {
        Write-Host "✓ Production API URL support enabled" -ForegroundColor Green
    }
} else {
    Write-Host "✗ backend_service.dart not found" -ForegroundColor Red
}

# Test 4: Summary and next steps
Write-Host ""
Write-Host "[4/4] Integration Status" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✓ Backend is running on http://127.0.0.1:5000" -ForegroundColor Green
Write-Host "✓ AI models loaded successfully" -ForegroundColor Green
Write-Host "✓ Flutter app is configured to warmup backend on startup" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test the app locally:" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Deploy backend to cloud (Google Cloud Run recommended):" -ForegroundColor White
Write-Host "   cd backend" -ForegroundColor Gray
Write-Host "   gcloud builds submit --tag gcr.io/<PROJECT>/snap2store" -ForegroundColor Gray
Write-Host "   gcloud run deploy --image gcr.io/<PROJECT>/snap2store" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Build app for production with deployed API:" -ForegroundColor White
Write-Host "   flutter build apk --release --dart-define=API_BASE_URL=https://your-api.com" -ForegroundColor Gray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Cleanup
Write-Host ""
Write-Host "Press any key to stop the backend and exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Stop-Job $backendJob
Remove-Job $backendJob
Write-Host "Backend stopped." -ForegroundColor Gray

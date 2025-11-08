# Snap2Store - Deployment Guide

This guide covers deploying your Flutter app with the AI backend to production.

## 🎯 Overview

Your app has two components:
1. **Flutter Mobile App** - Runs on Android devices
2. **AI Backend (Flask)** - Processes images and finds stores

The backend must be deployed to a cloud service with HTTPS. The app is built with the deployed API URL baked in.

## ✅ What's Already Done

- ✓ Backend warmup on app startup (triggers AI model loading)
- ✓ Production API URL support via `--dart-define`
- ✓ Graceful fallback if backend is offline
- ✓ Docker containerization ready
- ✓ Health check endpoint at `/warmup`

## 📦 Step 1: Deploy the AI Backend

### Option A: Google Cloud Run (Recommended)

**Why:** Auto-scaling, pay-per-use, built-in HTTPS, great for Docker containers.

```powershell
# 1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install

# 2. Login and set project
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# 3. Navigate to backend folder
cd backend

# 4. Build and deploy
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/snap2store-backend

gcloud run deploy snap2store-backend \
  --image gcr.io/YOUR_PROJECT_ID/snap2store-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_VISION_API_KEY=YOUR_KEY,GOOGLE_MAPS_API_KEY=YOUR_KEY,FLASK_DEBUG=false,PORT=5000" \
  --min-instances 0 \
  --max-instances 10
```

**Cost:** Free tier includes 2 million requests/month. Cold starts ~2-3 seconds (warmed by app startup).

**Your API URL:** `https://snap2store-backend-xxxxx-uc.a.run.app`

### Option B: Render.com (Easiest)

**Why:** Zero config, free tier, auto-deploy from Git.

1. Push your repo to GitHub
2. Go to https://render.com → New Web Service
3. Connect your GitHub repo
4. Settings:
   - **Root Directory:** `Flutter_app/backend`
   - **Environment:** Docker
   - **Environment Variables:**
     - `GOOGLE_VISION_API_KEY`: Your key
     - `GOOGLE_MAPS_API_KEY`: Your key
     - `FLASK_DEBUG`: false
     - `PORT`: 5000
5. Deploy

**Your API URL:** `https://snap2store.onrender.com`

**Cost:** Free tier available (spins down after 15 min inactivity, ~20s cold start).

### Option C: Railway.app

Similar to Render, very simple:

```powershell
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

## 📱 Step 2: Build the Android App

### 2.1 Create Signing Key (One-time)

```powershell
# Generate keystore (save the passwords!)
keytool -genkeypair -v `
  -keystore $HOME\snap2store-release-key.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias snap2store
```

### 2.2 Configure Signing

Create `android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=snap2store
storeFile=C:\\Users\\YourName\\snap2store-release-key.jks
```

Add to `android/app/build.gradle.kts` (around line 10):

```kotlin
// Load signing config
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        create("release") {
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 2.3 Build APK or App Bundle

Replace `YOUR_API_URL` with your deployed backend URL:

**For Play Store (App Bundle):**
```powershell
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-backend.run.app
```

Output: `build\app\outputs\bundle\release\app-release.aab`

**For Direct Install (APK):**
```powershell
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-backend.run.app
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

**For Smaller APKs (split by CPU architecture):**
```powershell
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://your-backend.run.app
```

## 🚀 Step 3: Distribute Your App

### Option A: Google Play Store

1. Create a Google Play Console account ($25 one-time fee)
2. Create a new app
3. Upload the `.aab` file to Internal Testing track first
4. Test with real users
5. Promote to production when ready

### Option B: Direct Distribution (APK)

- Send the APK file to users
- Users must enable "Install from Unknown Sources" in Android settings
- Good for beta testing, not ideal for wide distribution

## 🧪 Testing Before Deployment

Run the integration test script:

```powershell
cd Flutter_app
.\test_integration.ps1
```

This will:
1. Start the backend
2. Verify AI models load
3. Test the warmup endpoint
4. Confirm Flutter app configuration

Or test manually:

```powershell
# Terminal 1: Start backend
cd Flutter_app\backend
python app.py

# Terminal 2: Run Flutter app
cd Flutter_app
flutter run
```

The app will automatically ping the backend on startup and show logs in debug console:
```
[App] Starting AI backend warmup...
[BackendService] Warming up AI backend at http://10.0.2.2:5000...
[BackendService] ✓ Backend is ready and responding
[BackendService] Models loaded: {resnet50: true, vision_api: true, ...}
[App] AI backend warmup completed: SUCCESS
```

## 🔧 Production Checklist

Before deploying:

- [ ] Update `applicationId` in `android/app/build.gradle.kts` from `com.example.flutter_app` to your own (e.g., `com.yourcompany.snap2store`)
- [ ] Set app version in `pubspec.yaml` (e.g., `version: 1.0.0+1`)
- [ ] Add app icon and splash screen
- [ ] Test on a real Android device, not just emulator
- [ ] Set Google Maps API key in `android/local.properties`: `GOOGLE_MAPS_API_KEY=your_key`
- [ ] Enable HTTPS only (no cleartext traffic) - Android 9+ blocks HTTP by default
- [ ] Test with backend deployed to cloud, not localhost

## 🌐 How It Works in Production

1. User opens app
2. App calls `BackendService.ping()` → hits `https://your-backend.com/warmup`
3. Backend loads AI models (ResNet50, ImageNet classes) if not already loaded
4. Warmup returns success, app is ready
5. User takes a photo
6. App calls `POST https://your-backend.com/analyze` with image
7. Backend uses Google Vision API (or ResNet50 fallback) to detect media
8. App displays results and nearby stores

## 🐛 Troubleshooting

**"Backend warmup failed"**
- Check your `API_BASE_URL` is correct
- Verify backend is deployed and accessible
- Check backend logs for errors

**"Cleartext HTTP not permitted"**
- Use HTTPS in production
- For local testing with HTTP, add network security config (see Android docs)

**App can't connect to backend**
- Verify backend is running: visit the URL in a browser
- Check firewall/CORS settings
- Ensure `--dart-define=API_BASE_URL` was passed during build

**Cold starts are slow**
- Use Cloud Run with min-instances > 0 (costs more)
- The app's warmup ping helps reduce first-request latency

## 💰 Cost Estimate

**Typical usage (1000 active users):**
- Google Cloud Run: ~$5-20/month
- Google Vision API: ~$3/1000 images (free tier: 1000/month)
- Google Maps API: ~$5/1000 requests (free tier: $200 credit/month)
- Play Store: $25 one-time

**Total:** ~$10-30/month after free tiers.

## 📞 Support

If you encounter issues:
1. Check the integration test: `.\test_integration.ps1`
2. Review backend logs in your cloud provider's dashboard
3. Enable verbose logging: Set `FLASK_DEBUG=true` (development only)
4. Check Flutter console for `[BackendService]` and `[App]` logs

---

**Ready to deploy?** Start with Option B (Render.com) for the backend—it's the fastest way to get a working HTTPS API. Then build your APK and test on a real device!

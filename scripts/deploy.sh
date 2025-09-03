#!/bin/bash

# FitFusion Production Deployment Script
# This script builds and deploys the app to Firebase

set -e  # Exit on any error

echo "🚀 Starting FitFusion Production Deployment..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Run: firebase login"
    exit 1
fi

# Verify we're deploying to the correct project
echo "📋 Current Firebase project:"
firebase use

read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
rm -rf build/

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Run tests
echo "🧪 Running tests..."
flutter test || {
    echo "❌ Tests failed! Deployment cancelled."
    exit 1
}

# Build for web
echo "🏗️ Building Flutter web app..."
flutter build web --release --no-source-maps

# Build and deploy Cloud Functions
echo "☁️ Building and deploying Cloud Functions..."
cd functions
npm ci
npm run build
cd ..

# Deploy Firestore security rules
echo "🔒 Deploying Firestore security rules..."
firebase deploy --only firestore:rules,firestore:indexes

# Deploy Cloud Functions
echo "⚡ Deploying Cloud Functions..."
firebase deploy --only functions

# Deploy to Firebase Hosting
echo "🌐 Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo "✅ Deployment completed successfully!"
echo "🌍 Your app is now live at: https://fitfusion-prod-2024.web.app"

# Run post-deployment checks
echo "🔍 Running post-deployment health checks..."
curl -f https://fitfusion-prod-2024.web.app/healthCheck || echo "⚠️ Health check failed"

echo "🎉 FitFusion is now live in production!"
echo "📊 Don't forget to monitor the app at: https://console.firebase.google.com"
#!/bin/bash

# FitFusion Firebase Setup Script
# This script helps set up Firebase for production

set -e  # Exit on any error

echo "🔧 FitFusion Firebase Production Setup"
echo "======================================"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "📥 Installing Firebase CLI..."
    npm install -g firebase-tools
fi

# Login to Firebase
echo "🔑 Logging in to Firebase..."
firebase login

# Initialize Firebase project
echo "🚀 Initializing Firebase project..."
echo "Please select the following options when prompted:"
echo "- Choose 'Use an existing project' and select 'fitfusion-prod'"
echo "- Select: Firestore, Functions, Hosting"
echo "- Use TypeScript for Functions"
echo "- Install dependencies for Functions"
echo "- Use 'build/web' as public directory for Hosting"
echo "- Configure as single-page app: Yes"
echo "- Set up automatic builds: No"

firebase init

# Set up environment variables for Functions
echo "⚙️ Setting up environment configuration..."
cd functions

# Create .env file for local development
cat > .env << EOF
# FitFusion Environment Variables
NODE_ENV=production
SENDGRID_API_KEY=your_sendgrid_api_key_here
SUPPORT_EMAIL=support@fitfusion.app
EOF

echo "📧 Please update functions/.env with your actual API keys"

cd ..

# Create Firebase configuration for different environments
echo "🌍 Setting up environment configurations..."

# Production project
firebase use --add fitfusion-prod --alias production

# Development project (optional)
echo "Would you like to set up a development environment? (y/N)"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    firebase use --add fitfusion-dev --alias development
fi

# Install Flutter dependencies
echo "📱 Setting up Flutter dependencies..."
flutter pub get

# Generate Firebase configuration
echo "🔥 Generating Firebase configuration..."
echo "Run the following command to configure your Firebase project:"
echo "flutterfire configure --project=fitfusion-prod"

echo ""
echo "✅ Setup completed!"
echo ""
echo "Next steps:"
echo "1. Run 'flutterfire configure --project=fitfusion-prod'"
echo "2. Update functions/.env with your actual API keys"
echo "3. Configure custom domain in Firebase Console"
echo "4. Set up email templates in Firebase Console"
echo "5. Run './scripts/deploy.sh' to deploy to production"
echo ""
echo "📖 For detailed setup instructions, see FIREBASE_SETUP.md"
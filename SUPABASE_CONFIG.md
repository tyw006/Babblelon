# Supabase Configuration Guide

## Email Verification Redirect URLs

### Current Issue
Email verification links are redirecting to `localhost:3000` which doesn't work in production.

### Solution: Configure Redirect URLs

1. **Go to Supabase Dashboard**:
   - Navigate to your BabbleOn project: `https://supabase.com/dashboard/project/odhtvjzaopqurehepkry`

2. **Update Authentication Settings**:
   - Go to Authentication → Settings → URL Configuration
   
3. **Set Redirect URLs**:
   
   **For Development:**
   ```
   Site URL: http://localhost:3000
   Redirect URLs: 
   - babblelon://auth/callback
   - http://localhost:3000/auth/callback
   ```
   
   **For Production:**
   ```
   Site URL: https://yourdomain.com (or your app's deep link scheme)
   Redirect URLs:
   - babblelon://auth/callback
   - https://yourdomain.com/auth/callback
   ```

4. **Add URL Scheme to Flutter App**:
   
   **Android (`android/app/src/main/AndroidManifest.xml`):**
   ```xml
   <activity
       android:name=".MainActivity"
       android:exported="true"
       android:launchMode="singleTop"
       android:theme="@style/LaunchTheme">
       
       <!-- Deep Link Intent Filter -->
       <intent-filter android:autoVerify="true">
           <action android:name="android.intent.action.VIEW" />
           <category android:name="android.intent.category.DEFAULT" />
           <category android:name="android.intent.category.BROWSABLE" />
           <data android:scheme="babblelon" />
       </intent-filter>
       
       <!-- Existing intent filters -->
       <intent-filter>
           <action android:name="android.intent.action.MAIN"/>
           <category android:name="android.intent.category.LAUNCHER"/>
       </intent-filter>
   </activity>
   ```
   
   **iOS (`ios/Runner/Info.plist`):**
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLName</key>
           <string>babblelon.auth</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>babblelon</string>
           </array>
       </dict>
   </array>
   ```

5. **Handle Deep Links in Flutter**:
   - Add `url_launcher` and `uni_links` packages to handle URL schemes
   - Listen for auth callbacks in your main app

## Alternative: Disable Email Confirmation (Development Only)

For development/testing, you can temporarily disable email confirmation:

1. Go to Authentication → Settings → Email Auth
2. Uncheck "Enable email confirmations"
3. Users will be immediately confirmed upon signup

**⚠️ Important**: Re-enable email confirmation for production!

## Verification

After configuring:
1. Test signup flow
2. Check that verification emails have correct redirect URLs
3. Confirm that deep links open your app correctly
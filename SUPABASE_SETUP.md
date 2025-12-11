# Supabase Setup Instructions for iOS

## Step 1: Add Supabase Swift SDK

1. Open `LilyHillFarm.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. In the search bar, paste: `https://github.com/supabase/supabase-swift`
4. Click **Add Package**
5. Select the following products to add:
   - `Supabase`
   - `PostgREST`
   - `Auth`
   - `Storage`
   - `Realtime`
6. Click **Add Package**

**Note:** The Supabase Swift SDK requires iOS 15.0 or later.

---

## Step 2: Configure Environment Variables

### Option A: Using Xcode Scheme (Recommended for Development)

1. In Xcode, go to **Product → Scheme → Edit Scheme...**
2. Select **Run** in the left sidebar
3. Click the **Arguments** tab
4. Under **Environment Variables**, add:
   - Name: `SUPABASE_URL`
     Value: `https://your-project.supabase.co` (from your Supabase project settings)
   - Name: `SUPABASE_ANON_KEY`
     Value: Your Supabase anon/public key (from Project Settings → API)
5. Click **Close**

### Option B: Using Info.plist (Not Recommended - Keys visible in binary)

Add to `Info.plist`:
```xml
<key>SUPABASE_URL</key>
<string>https://your-project.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>your-anon-key-here</string>
```

### Option C: Using .xcconfig File (Recommended for Production)

1. Create a new file: `Config.xcconfig`
2. Add:
   ```
   SUPABASE_URL = https:/$()/your-project.supabase.co
   SUPABASE_ANON_KEY = your-anon-key-here
   ```
3. Add the file to project settings under Configurations

---

## Step 3: Get Your Supabase Credentials

1. Go to [https://app.supabase.com](https://app.supabase.com)
2. Select your project (HERD)
3. Go to **Settings** (⚙️) → **API**
4. Copy:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon public key** (looks like `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

**⚠️ Never commit your anon key to version control!**

Add to `.gitignore`:
```
# Supabase config
Config.xcconfig
*.xcconfig
```

---

## Step 4: Update App to Use Authentication

The following files have been created for you:

- `Services/SupabaseConfig.swift` - Configuration and constants
- `Services/SupabaseClient.swift` - Main Supabase client wrapper
- `Views/Auth/AuthView.swift` - Login/signup UI

### Update LilyHillFarmApp.swift

Replace the app entry point with:

```swift
import SwiftUI

@main
struct LilyHillFarmApp: App {
    @StateObject private var supabase = SupabaseClient.shared
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch supabase.authState {
                case .loading:
                    ProgressView("Loading...")
                case .authenticated:
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                case .unauthenticated:
                    AuthView()
                }
            }
        }
    }
}
```

---

## Step 5: Test Authentication

1. Build and run the app (Cmd+R)
2. You should see the AuthView with login/signup
3. Try signing up with an email and password
4. Check Supabase dashboard → Authentication → Users to verify

---

## Step 6: Set Up Storage Bucket

1. In Supabase dashboard, go to **Storage**
2. Create a new bucket:
   - Name: `cattle-photos`
   - Public: ✅ Yes (photos will be publicly accessible)
3. Set up storage policies:

```sql
-- Allow authenticated users to upload photos
CREATE POLICY "Authenticated users can upload photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'cattle-photos');

-- Allow authenticated users to delete their own photos
CREATE POLICY "Users can delete their own photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'cattle-photos');

-- Allow public read access
CREATE POLICY "Public photo access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'cattle-photos');
```

---

## Step 7: Verify RLS Policies

Make sure your Supabase tables have proper RLS (Row Level Security) policies:

```sql
-- Example: Cattle table RLS
ALTER TABLE cattle ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own cattle"
ON cattle FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own cattle"
ON cattle FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own cattle"
ON cattle FOR UPDATE
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own cattle"
ON cattle FOR DELETE
TO authenticated
USING (user_id = auth.uid());
```

Repeat for all tables: `health_records`, `calving_records`, `pregnancy_records`, `stage_transitions`, `processing_records`, `sale_records`, `mortality_records`, `photos`, `tasks`.

---

## Step 8: Test Connection

Add this test to `DeveloperMenuView.swift` or create a test button:

```swift
Button("Test Supabase Connection") {
    Task {
        do {
            let breeds = try await SupabaseClient.shared.breeds
                .select()
                .execute()
                .value

            print("✅ Successfully fetched \(breeds.count) breeds")
        } catch {
            print("❌ Connection failed: \(error)")
        }
    }
}
```

---

## Next Steps

Once Supabase is set up and authenticated:

1. ✅ Update Core Data schema (see `IOS_SUPABASE_MIGRATION_GUIDE.md`)
2. ✅ Implement sync repositories for each entity
3. ✅ Add Realtime subscriptions for live updates
4. ✅ Migrate photo storage to Supabase Storage
5. ✅ Add Task management feature

---

## Troubleshooting

### "Supabase not configured" warning

- Make sure you've set `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables
- Restart Xcode after adding environment variables
- Check that the values are correct (no trailing slashes in URL)

### Build errors about missing Supabase

- Make sure you added the Supabase Swift SDK via Swift Package Manager
- Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)
- Try removing and re-adding the package

### Auth errors

- Check that your Supabase project has email auth enabled
- Go to Authentication → Providers → Email and make sure it's enabled
- Check email confirmation settings if needed

### RLS Policy errors

- Make sure you're authenticated before making database requests
- Check that RLS policies are set up correctly
- Use Supabase SQL Editor to test queries directly

---

## Resources

- [Supabase Swift SDK Docs](https://github.com/supabase/supabase-swift)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase Storage](https://supabase.com/docs/guides/storage)

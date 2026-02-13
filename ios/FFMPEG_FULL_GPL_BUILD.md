# Use your ffmpeg-kit full-gpl (libx264) on iOS

The app uses **full-gpl** from your local ffmpeg-kit. You need to **build the iOS xcframeworks once** before `pod install` will succeed.

## One-time build (from your Mac)

1. Open Terminal.

2. Go to your ffmpeg-kit repo:
   ```bash
   cd /Users/user/Desktop/Flutter/ffmpeg_kit/ffmpeg-kit
   ```

3. Build iOS full-gpl xcframeworks (takes a while, needs Xcode):
   ```bash
   ./ios.sh --full --enable-gpl -x
   ```
   - `--full` = all libraries  
   - `--enable-gpl` = GPL libs (libx264, etc.)  
   - `-x` = output as xcframework  

4. When it finishes, you should see:
   ```
   prebuilt/bundle-apple-xcframework-ios/
     ffmpeg.xcframework
     ffmpegkit.xcframework
     ...
   ```

5. Then in your app:
   ```bash
   cd /Users/user/Desktop/Flutter/capcut_clone/ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter run
   ```

After that, you can use **libx264** (e.g. transition merge) with your local full-gpl build. You only need to run the build again if you change ffmpeg-kit or want a different version.

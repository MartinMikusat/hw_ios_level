# App Store release: outstanding work

The app is complete. The privacy manifest, the export compliance key, and the opaque app icon are in the project. The support and privacy pages are in the `website` project on its `staging` branch.

## Before you submit

1. Merge the `staging` branch of the `website` project into `main`.
2. Open these URLs and make sure that they load:
   - `https://www.halwayland.com/apps/hw_level/support`
   - `https://www.halwayland.com/apps/hw_level/privacy`
3. Read the privacy policy text. Change it if it does not match your intent.
4. Make sure that the Apple Developer Program membership is active for team `5242LK8KGW`.
5. Register the bundle ID `com.halwayland.hw-level`.

## App Store Connect

1. Create the app record with the name `hw_level`. If the name is taken, choose another name for the listing only. The home-screen name stays `hw_level`.
2. Set the category to Utilities.
3. Enter the support URL and the privacy policy URL from above.
4. Write the subtitle, description, keywords, and "what's new" text.
5. Answer App Privacy with "Data Not Collected".
6. Complete the age rating questionnaire.
7. Add this review note: the app needs a physical iPhone with a motion sensor. It has no login.
8. Upload screenshots for the 6.9-inch iPhone size. Take them on the physical iPhone. The simulator has no motion sensor and shows only "Motion Unavailable". Show the flat view, a landscape view, and Settings.

## Build and upload

1. Archive a Release build of the `hw_level` scheme.
2. Validate the archive in the Xcode Organizer. Fix each error that it reports.
3. Upload the build. The build number must be higher for each new upload.
4. Install the build with TestFlight on your own iPhone and test it.
5. Submit the build for review.

## Known limits

- No Release archive has been validated against Apple's upload checks.
- With Light chosen while the iPhone is in dark mode, the launch screen can flash dark before the app starts.
- Review risk: guideline 4.2 (minimum functionality) can apply to simple utility apps. State the automatic modes, per-edge calibration, and feedback in the description.

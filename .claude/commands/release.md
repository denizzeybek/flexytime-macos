Build, sign, notarize and create DMG for Flexytime distribution.

Steps:
1. First check if NOTARIZE_PASSWORD environment variable is set. If not, stop and tell the user to set it:
   `export NOTARIZE_PASSWORD="xxxx-xxxx-xxxx-xxxx"` (app-specific password from appleid.apple.com)
2. Run the full release pipeline:
   ```
   ./scripts/package-release.sh --notarize --apple-id "zeybekdeniz@icloud.com" --team-id "3C44584K6T" --app-password "$NOTARIZE_PASSWORD"
   ```
3. After completion, verify the DMG is signed and notarized:
   ```
   spctl -a -vvv build/Flexytime/Flexytime.app
   ```
4. Report the final DMG path and size to the user.

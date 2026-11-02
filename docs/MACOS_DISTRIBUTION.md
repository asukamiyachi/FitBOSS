# FitBOSS macOS DMG distribution

**Current status:** internal DMG artifacts only. There is no GitHub Release yet. Do not enable a clickable download button to an absent asset.

## Workflow and user experience

1. macOS CI builds FitBOSS.app, runs Swift tests and packages a compressed DMG.
2. The DMG includes FitBOSS.app and a real symbolic link named Applications pointing to /Applications.
3. In internal development, the DMG is uploaded as an Actions artifact only, never as a GitHub Release.
4. Once Developer ID signing, Apple notarization and stapling pass, an explicitly approved manual workflow can attach an asset named **FitBOSS.dmg** to a Release with a semantic version tag.
5. After the first public asset is verified, change the README from the grey non-clickable Coming soon badge to the prepared direct-download Markdown link. Stable target:
   https://github.com/asukamiyachi/FitBOSS/releases/latest/download/FitBOSS.dmg
6. A Mac user downloads the DMG, opens it and manually drags the app onto Applications. README links cannot silently install software.

## Internal test commands

```bash
swift test
bash Scripts/build-app.sh
bash Scripts/create-dmg.sh
hdiutil verify .build/dist/FitBOSS.dmg
```

Workflow: .github/workflows/macos-dmg.yml. No secrets or release permissions; an ad-hoc signature is acceptable *only* for an internal artifact.

## Public release prerequisites — manual, fail closed

Workflow: .github/workflows/publish-macos.yml. It requires:
- manual workflow_dispatch on main, confirm_publish=true and a valid existing tag vX.Y.Z pointing to the exact main commit;
- matching CFBundleShortVersionString in Resources/Info.plist;
- DEVELOPER_ID_CERT_P12_BASE64, DEVELOPER_ID_CERT_PASSWORD, DEVELOPER_ID_APPLICATION;
- APPSTORE_API_PRIVATE_KEY, APPSTORE_API_KEY_ID, APPSTORE_ISSUER_ID;
- a Developer ID Application certificate, hardened runtime and secure timestamp;
- Apple notarytool Accepted, stapler validate and Gatekeeper check;
- no pre-existing Release for this tag;
- optional additional manual approval via a protected GitHub environment macos-release.

The workflow must **not** run on push or PR and must not create a Release if any prerequisite is missing. It uses contents:write only in the publication job. Never commit Apple certificates, API keys or tokens.

**Optional Firebase integration:** The main branch now includes an optional Firebase/Google client foundation, but the default build is camera/local-history only. Production distribution of the online version requires a separate Firebase-enabled build, GoogleService-Info.plist, URL schemes, Keychain entitlements and Developer ID signing review. This release job builds the default offline version and must not silently ship an online app with missing configuration.

## Security and operational notes

- The internal DMG is for internal testing; macOS Gatekeeper may block it because it is not notarized.
- No Apple secrets are currently asserted to exist in the repository.
- Merging this PR never deploys Firebase or publishes a GitHub Release. Do not dispatch the manual release job without a separate explicit authorization.
- CI cannot verify real camera performance or end-user drag-and-drop behavior; test these manually before a public release.

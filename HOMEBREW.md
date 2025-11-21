# Homebrew Distribution Guide

This document explains how to distribute NetSpeedMonitor via Homebrew.

## Installation for Users

### Via Homebrew Tap (Recommended)
```bash
brew tap guerrerocarlos/tap
brew install --cask netspeedmonitor
```

### Direct Cask Installation
```bash
brew install --cask guerrerocarlos/tap/netspeedmonitor
```

## Setup for Maintainers

### 1. Create a Homebrew Tap Repository

Create a new GitHub repository named `homebrew-tap` at:
```
https://github.com/guerrerocarlos/homebrew-tap
```

### 2. Add the Cask Formula

Copy the cask formula from this repo:
```bash
# In your homebrew-tap repository
mkdir -p Casks
cp /path/to/NetSpeedMonitor/Casks/netspeedmonitor.rb Casks/
git add Casks/netspeedmonitor.rb
git commit -m "Add NetSpeedMonitor cask"
git push
```

### 3. Release Process

1. **Build and create a release**:
   ```bash
   # Tag a new version
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **GitHub Actions will automatically**:
   - Build the app bundle
   - Create a release with NetSpeedMonitor.zip
   - Calculate SHA256 checksum
   - Publish the release

3. **Update the Homebrew cask**:
   - Copy the SHA256 from the GitHub release notes
   - Update `Casks/netspeedmonitor.rb` in the homebrew-tap repo:
     ```ruby
     version "1.0.0"
     sha256 "paste_sha256_here"
     ```
   - Commit and push the changes

### 4. Testing the Cask

Test locally before publishing:
```bash
# Audit the cask
brew audit --cask --new Casks/netspeedmonitor.rb

# Test installation
brew install --cask Casks/netspeedmonitor.rb

# Test uninstallation
brew uninstall --cask netspeedmonitor
```

## Cask Structure

The cask formula (`Casks/netspeedmonitor.rb`) includes:

- **version**: Semantic version number
- **sha256**: Checksum of the zip file (for security)
- **url**: Download URL from GitHub releases
- **name**: Display name
- **desc**: Short description
- **homepage**: Project homepage
- **livecheck**: Automatic version checking
- **depends_on**: System requirements (macOS 14+)
- **app**: App bundle to install
- **zap**: Files to remove on complete uninstall

## Automatic Updates

The cask includes a `livecheck` block that allows Homebrew to:
- Check for new releases automatically
- Notify users when updates are available
- Update the cask formula automatically (via homebrew-cask-upgrade)

## Directory Structure

```
NetSpeedMonitor/                    # This repository
├── Casks/
│   └── netspeedmonitor.rb         # Cask formula (to be copied to tap repo)
└── .github/
    └── workflows/
        └── release.yml             # Automated build and release

homebrew-tap/                       # Separate tap repository
└── Casks/
    └── netspeedmonitor.rb         # Live cask formula
```

## Quick Release Checklist

- [ ] Update version in git tag
- [ ] Push tag to trigger GitHub Actions
- [ ] Wait for release to be published
- [ ] Copy SHA256 from release notes
- [ ] Update homebrew-tap repository with new version and SHA256
- [ ] Test installation: `brew reinstall --cask netspeedmonitor`
- [ ] Verify the app launches correctly

## Troubleshooting

### Quarantine Issues
If users see a security warning, they can remove the quarantine attribute:
```bash
sudo xattr -rd com.apple.quarantine /Applications/NetSpeedMonitor.app
```

### Cask Audit Failures
Common issues:
- Wrong SHA256: Recalculate with `shasum -a 256 NetSpeedMonitor.app.zip`
- URL not accessible: Ensure GitHub release is published and public
- Version mismatch: Ensure tag matches version in cask

### Update Not Detected
```bash
# Clear Homebrew cache
brew cleanup
brew update

# Reinstall
brew reinstall --cask netspeedmonitor
```

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Creating a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Cask Formula Reference](https://docs.brew.sh/Cask-Cookbook#stanza-reference)

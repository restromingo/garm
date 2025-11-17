# Lid Angle Sensor

> **Fork of [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor)** with added **Accordion Mode** 🪗
> 
> This fork adds a bisonoric accordion mode where you can play notes using keyboard keys while controlling the bellows by opening/closing the MacBook lid.

> by restromingo
---

Hi, I'm Sam Gold. Did you know that you have ~rights~ a lid angle sensor in your MacBook? [The ~Constitution~ human interface device utility says you do.](https://youtu.be/wqnHtGgVAUE?t=21)

This is a little utility that shows the angle from the sensor and, optionally, plays a wooden door creaking sound if you adjust it reeaaaaaal slowly.

## 🪗 Accordion Mode (New!)

This fork adds an **Accordion Mode** feature:

- **12 accordion buttons** mapped to keyboard keys
- **Bisonoric behavior**: Each button plays different notes when bellows are opening (pull) vs closing (push)
- **Bellows control**: Sound only plays when the lid is moving (velocity > 1 deg/s)
- **Volume control**: Faster movement = louder sound
- **Two sound modes**: Synthesized sine waves or sample-based playback (гармошка.wav)
- **Polyphonic**: Play multiple notes simultaneously

**How to use:**
1. Select "Accordion" mode in the app
2. Press keyboard keys (1-9, 0, -, =) to play notes
3. Open/close the MacBook lid to control the bellows
4. Toggle between synthesized and sample-based sound using the checkbox

## FAQ

**What is a lid angle sensor?**

Despite what the name would have you believe, it is a sensor that detects the angle of the lid.

**Which devices have a lid angle sensor?**

It was introduced with the 2019 16-inch MacBook Pro. If your laptop is newer, you probably have it. [People have reported](https://github.com/samhenrigold/LidAngleSensor/issues/13) that it **does not work on M1 devices**, I have not yet figured out a fix.

**My laptop should have it, why doesn't it show up?**

I've only tested this on my M4 MacBook Pro and have hard-coded it to look for a specific sensor. If that doesn't work, try running [this script](https://gist.github.com/samhenrigold/42b5a92d1ee8aaf2b840be34bff28591) and report the output in [an issue](https://github.com/samhenrigold/LidAngleSensor/issues/new/choose).

Known problematic models:

- M1 MacBook Air
- M1 MacBook Pro

**Can I use this on my iMac?**

~~Not yet tested. Feel free to slam your computer into your desk and make a PR with your results.~~

[It totally works](https://github.com/samhenrigold/LidAngleSensor/issues/33). If it doesn't work for you, try slamming your computer harder?

**Why?**

A lot of free time. I'm open to full-time work in NYC or remote. I'm a designer/design-engineer. https://samhenri.gold

**No I mean like why does my laptop need to know the exact angle of its lid?**

Oh. I don't know.

**Can I contribute?**

I guess.

**Why does it say it's by Lisa?**

I signed up for my developer account when I was a kid, used my mom's name, and now it's stuck that way forever and I can't change it. That's life.

**How come the audio feels kind of...weird?**

I'm bad at audio.

**Where did the sound effect come from?**

LEGO Batman 3: Beyond Gotham. But you knew that already.

**Can I turn off the sound?**

Yes, never click "Start Audio". But this energy isn't encouraged.

## Installation

### Download Pre-built App (Easiest - No Xcode Required) ⭐

**Method 1: Using Install Script (Easiest)**

1. **Clone the repository:**
   ```bash
   git clone https://github.com/restromingo/garm.git
   cd garm
   ```

2. **Run the install script:**
   ```bash
   chmod +x install-app.sh
   ./install-app.sh
   ```

   The script will automatically:
   - Extract the app
   - Sign the app (no quarantine needed)
   - Install to `/Applications`

**Method 2: Manual Installation**

1. **Download the app:**
   - Download `releases/LidAngleSensor-accordion.zip` from this repository
   - Or clone the repo: `git clone https://github.com/restromingo/garm.git`

2. **Extract and install:**
   ```bash
   cd garm/releases
   unzip LidAngleSensor-accordion.zip
   # Sign app (optional, but recommended)
   codesign --force --deep --sign - LidAngleSensor.app
   # Move to Applications
   mv LidAngleSensor.app /Applications/
   ```

3. **Launch the app:**
   - Open `/Applications/LidAngleSensor.app`
   - The app is pre-signed, so it should work without issues

**Method 3: Using Finder (GUI)**

1. **Download and extract:**
   - Download `releases/LidAngleSensor-accordion.zip`
   - Double-click to extract

2. **Install:**
   - Drag `LidAngleSensor.app` to `/Applications` folder

3. **Launch:**
   - The app is pre-signed and should work without issues
   - If macOS blocks it: Right-click → Open → Click "Open"
   - Or: System Settings → Privacy & Security → Click "Open Anyway"

**Troubleshooting "App is damaged" error:**

The app is pre-signed with an ad-hoc signature, so it should work without issues. If macOS still blocks it:

1. **Right-click method (easiest):**
   - Right-click the app → Open → Click "Open" in the dialog
   - This bypasses Gatekeeper for this specific app

2. **Or allow in System Settings:**
   - System Settings → Privacy & Security → Click "Open Anyway" next to the app

3. **Or remove quarantine (if needed):**
   ```bash
   xattr -cr /Applications/LidAngleSensor.app
   ```

### Build from Source (Requires Xcode)

1. **Clone this repository:**
   ```bash
   git clone https://github.com/restromingo/garm.git
   cd garm
   ```

2. **Run the install script:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   
   If you need administrator privileges:
   ```bash
   sudo ./install.sh
   ```

3. **Launch the app** from `/Applications/LidAngleSensor.app`

### Manual Installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/restromingo/garm.git
   cd garm
   ```

2. **Build the project:**
   ```bash
   xcodebuild -project LidAngleSensor.xcodeproj \
              -scheme LidAngleSensor \
              -configuration Release \
              build \
              CODE_SIGN_IDENTITY="" \
              CODE_SIGNING_REQUIRED=NO
   ```

3. **Find the built app:**
   ```bash
   find ~/Library/Developer/Xcode/DerivedData -name "LidAngleSensor.app" -type d | grep Release
   ```

4. **Copy to Applications:**
   - Open Finder and navigate to the path from step 3
   - Drag `LidAngleSensor.app` to `/Applications`

### Building with Xcode

1. Open `LidAngleSensor.xcodeproj` in Xcode
2. Select the `LidAngleSensor` scheme and `Release` configuration
3. Press `Cmd+B` to build
4. Find the `.app` file in the Products folder and copy it to `/Applications`

### Requirements

- macOS (tested on macOS with M4 MacBook Pro)
- Xcode installed (tested on Xcode 26) or Xcode Command Line Tools
- MacBook with lid angle sensor (2019 16-inch MacBook Pro or newer, **does not work on M1 devices**)

### Troubleshooting

**Installation script fails:**

1. **Xcode not found:**
   ```bash
   # Install Xcode from App Store, or install Command Line Tools:
   xcode-select --install
   ```

2. **Xcode license not accepted:**
   ```bash
   sudo xcodebuild -license accept
   ```

3. **Build fails:**
   - Open the project in Xcode: `open LidAngleSensor.xcodeproj`
   - Build manually: `Product > Build` (Cmd+B)
   - Check for specific error messages

4. **Permission denied when copying to /Applications:**
   - The script will try with `sudo` automatically
   - Or copy manually: Find the `.app` file and drag it to `/Applications` in Finder

5. **App not found after build:**
   - Check: `find ~/Library/Developer/Xcode/DerivedData -name "LidAngleSensor.app"`
   - Build output shows the exact path

**The app doesn't work:**

- Make sure your MacBook has a lid angle sensor (2019 16-inch MacBook Pro or newer)
- **M1 MacBooks are not supported** - this is a known limitation
- Try running the original [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) first to verify your hardware works

## Building

According to [this issue](https://github.com/samhenrigold/LidAngleSensor/issues/12), building requires having Xcode installed. I've only tested this on Xcode 26. YMMV.

## Related projects

- [Python library that taps into this sensor](https://github.com/tcsenpai/pybooklid)

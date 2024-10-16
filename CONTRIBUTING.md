# Contributing to Loop

Welcome to Loop. If you're here, you may be interested in contributing to this awesome project. Well, let's get to it!

If at any time you need help, contact us on [Discord](https://discord.gg/2CZ2N6PKjq) or create an issue on GitHub.

## Areas of focus

You can improve Loop by doing some of the following:

1. Add your language to Loop, or if you see someone make a grammatical error or mistake, help fix it!
2. Have an idea that you can proactively add, or see an area where some code can be changed? Submit an issue and explain what you wish to do, and if it's greenlit, push your changes into a PR!
3. Got an icon? We LOVE icons, especially good ones! Make a great icon the team likes, and it *may* be included for everyone to use.
4. Got a bug to report? Head over to the issues tab; here, you'll be walked through what you need!

# Local development

## Issues

First, we need to get a scope of what you're changing, adding, improving, or wanting.

1. Create an issue and clearly articulate your issue, change, or improvement you want to make.
2. Wait for a response from a maintainer; if it's accepted, you're off to the races!

Now, you need to make these changes. HOW?

Well, it's very easy: fork the repo, push your changes to the fork, and submit a PR!

## Forking

Forking creates a personal copy of the Loop repository under your GitHub account. This allows you to make changes without affecting the original project. To fork, go to the Loop repository page on GitHub and click the "Fork" button at the top right of your screen. Once forked, you'll see:

```sh
Loop
forked from MrKai77/Loop
```

## Cloning your fork

Now, you've forked our repo. What next? Don't stress. First, go to where you want to code and execute some quick command lines! Here's how to do it!

```sh
cd downloads # Or the directory where you wish to clone Loop
git clone https://github.com/{your-name}/Loop.git
# Remember to replace {your-name} with your actual GitHub username!
# For example: https://github.com/MrKai77/Loop.git
cd Loop
open Loop.xcodeproj
```

Once you've got your fork, it'll auto-open in Xcode!

## What code? Xcode

Now, let's tackle Xcode. If you followed the method above, you should be automatically opened into Xcode. Once in Xcode, you'll need to change the cert!

### Before You Begin

*Skip this section if you already have an Apple Developer account.*

0. Enroll your account in the Developer Program at [developer.apple.com](https://developer.apple.com/). A free account works just fine; you don't need a paid one.
1. Install Xcode.
2. Add your Developer account to Xcode. To do this, click `Xcode → Preferences` in the menu bar, and in the window that opens, click `Accounts`. You can add your account there.
3. After adding your account, it will appear in the list of Apple IDs on the left side of the screen. Select your account.
4. At the bottom of the screen, click `Manage Certificates...`.
5. On the bottom left, click the **+** icon and select `Apple Development`.
6. When a new item labeled `Apple Development Certificates` appears in the list, press `Done` to close the account manager.

### Signing Loop

1. Wait until all dependencies are resolved. This should take a couple of minutes at most.
2. In the file browser on the left, click `Loop` at the very top. It's the icon with the App Store logo.
3. In the pane that opens on the right, click `Signing & Capabilities` at the top.
4. Under `Signing`, change the `Team` dropdown to your ID.
5. Under `Signing → macOS`, change the `Signing Certificate` to `Development`.

### Building

Now that you've signed Loop with your developer account, it's time to build! First, validate if the current build works <kbd>⌘</kbd> + <kbd>R</kbd> (this command will run Loop). If the build was successful, you should see an alert that Loop requires Accessibility permissions; if you change any code related to Loop's movement or core code, you will need to enable this. For cases of simple code changes, this is not needed. You can run both Loop (the one you already have) and the Loop developmental version you are running at the same time!

### SwiftFormat

**IMPORTANT:** You MUST have [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) installed via `brew`. SwiftFormat will run on each build attempt to ensure consistent code formatting. **DO NOT** turn this off. When you submit your PR, another check will run to validate your formatting. If the format is incorrect, your request will be rejected.

To install SwiftFormat:

1. Install Homebrew (if not already installed):

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

   **NOTE: DO NOT INSTALL `brew` WITH SUDO**

2. Install SwiftFormat:

   ```sh
   brew install SwiftFormat
   ```

For more information on Homebrew, visit [brew.sh](https://brew.sh).

Now, some **important** notes. All of the code you write **MUST** include comprehensive comments. Proper documentation helps other contributors understand your code and makes maintenance easier. An example of this would be:

```swift
    /// Determines if two colors are similar based on a threshold.
    /// - Parameters:
    ///   - color: The color to compare with the receiver.
    ///   - threshold: The maximum allowed difference between color components.
    /// - Returns: A Boolean value indicating whether the two colors are similar.
    func isSimilar(to color: NSColor, threshold: CGFloat = 0.1) -> Bool {
        // Convert both colors to the RGB color space for comparison.
        guard let color1 = usingColorSpace(.deviceRGB),
              let color2 = color.usingColorSpace(.deviceRGB) else { return false }
        // Compare the red, green, and blue components of both colors.
        return abs(color1.redComponent - color2.redComponent) < threshold &&
            abs(color1.greenComponent - color2.greenComponent) < threshold &&
            abs(color1.blueComponent - color2.blueComponent) < threshold
    }
```

Code lines such as the following will not be accepted

```diff
- // func check
+ // Checks for similar colors and returns a Boolean
```

## How to PR?

You have a few ways of pushing your changes from Xcode into GitHub. You should see an 'integrate' option at the top of the code editor. You can push via that, via CLI, or even open VSCode and push through that.

Recommended:

```sh
# Add your changes to git staging
git add .

# Commit your changes with a meaningful message
git commit -m "Your detailed commit message"
# If you're committing, you must use the following emojis at the start:
# 🐞 Bug fixes must include a bug emoji.
# ✨ Added features must include a star emoji.
# 🌐 Localization must include a globe emoji.
# An example of this would be:
# git commit -m "✨ Add wallpaper theming"

# Push your changes to your fork
git push origin develop

# Then, go to GitHub, navigate to your fork, and you'll see a button to 'Create pull request'.
# Click it, fill in the details, and submit your PR.
# IF your PR needs changes, you MUST push it as a draft PR.
```

# Icons

## Before we get started

We love icons, just look at how many we already have! We love talented designers, and we love people who express their creativity for Loop.

But as Loop grows and the app quality improves, some previous icons may be removed, making room for new icons. Do not feel disheartened, as you've shaped Loop. If your icon is selected, you will still have a section in our readme with your name and previous icon(s).

## How do I submit my icon?

If you read the local development section, you'll see where this is going!

### Create an issue

Once you're in your issue, drop in your icons you've made for Loop and the team will review each and every icon. You can upload a single `.icns` file, or a `.png`. Upload this into the given box, if the icon is submitted you'll see some feedback and your name added to the readme. If it gets rejected, then you may get some feedback in the areas we wish to focus on. If your icon has been dismissed, remember, this isn't your only chance. Come back more invigorated and show us your best! You don't need to be a professional designer, you just need to capture the feel of Loop in your design.

Now, for the Issue section, this is **NOT** for you to request an icon. Here, it is only for sharing an icon you, a friend, or someone else has made, or to link it to an external post (say, Twitter) to a user who's made this icon. If you're requesting an icon in this section, your issue will be closed.

# Localisation

We wish to localise (localize) Loop in every language possible!

For quick, and easy localisation, we use [Crowdin](https://crowdin.com/project/loop-i18n).

## How to localise?

1. Go to the [Loop Crowdin page](https://crowdin.com/project/loop-i18n).
2. Click the `Join the team` button.
3. Login or signup with your GitHub account.
4. Add a message to the top of the page, and click `Request Access`.
5. Wait for the account to be approved.
6. Start translating!

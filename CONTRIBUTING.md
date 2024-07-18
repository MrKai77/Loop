# Contributing to Loop

Welcome to Loop. If you're here, you may be interested in adding to this awesome project. Well, let's get to it!

If at any time you need help, contact us on [Discord](https://discord.gg/2CZ2N6PKjq) or make an issue on GitHub.

## Areas of focus

You can improve Loop by doing some of the following:

1. Add your language to Loop, or if you see someone make a grammatical error or mistake, help fix it!
2. Got an idea that you can proactively add, or see somewhere where some code can be changed? Submit an Issue and explain what you wish to do, and if it's greenlit, push your changes into a PR!
3. Got an icon? We LOVE icons, good icons! Make a good icon the team likes and it *may* be included for everyone to use.
4. Got a bug to report? Head over to the issues tab; here, you'll be walked through what you need!

# Local development

## Issues

First, we need to get a scope of what you're changing, adding, improving, or wanting.

1. Create an Issue and clearly articulate your issue, change, or improvement you want to make.
2. Wait for a response from a maintainer; if it's accepted, you're off to the races!

Now, you need to make these changes. HOW?

Well, it's very easy, fork the repo, push your changes to the fork, and submit a PR!

## Forking

To fork, you can go to Loop, and see the "Fork" button at the top of your screen, click that, and change nothing. Once forked you'll see

```sh
Loop
forked from MrKai77/Loop
```

## Getting your fork

Now, you've forked our repo. What next? Don't stress, first go to where you want to code, and push some quick command lines! Here's how I do it!

```sh
cd downloads
git clone https://github.com/{your-name}/Loop.git
cd Loop
open Loop.xcodeproj
```

Once you've got your fork, it'll auto open in Xcode!

## What code? Xcode

Now, for the terror of Xcode, you should be automatically opened into Xcode if you followed the method above, once in Xcode, you'll need to change the cert!

### Before You Begin

*Skip this section if you already have an Apple Developer account.*

0. Enroll your account in the Developer Program at [developer.apple.com](https://developer.apple.com/). A free account works just fine; you don't need a paid one.
1. Install Xcode.
2. Add your Developer account to Xcode. To do this, click `Xcode → Preferences` in the Menu bar, and in the window that opens, click `Accounts`. You can add your account there.
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

### Next

Now that you've signed with Loop with your developmental account, it's time to build! First, validate if the current build works `⌘R` (this command is run, this will build and launch loop all in one). If the build was successful, you should see an alert that Loop requires Accessibility permissions; if you change any code related to Loop's movement or core code, you will need to enable this. For cases of simple code changes, this is not needed. You can run both Loop (the one you already have) and the Loop developmental version you are running at the same time!

**HOWEVER**, it must be made aware that Loop **MAY** fail to build if you run it again. How do we fix this? Clear the build cache, press `⌘⇧K` (command + shift + k); you **MAY** need to do this every time you hit the run command. It has to do with some leftover user cache that makes Loop fail to build. We've tried to fix it to no avail.

**IF YOUR BULD FAILS** You've got a few options

1. Review the issue, if it's giving `Luminare cannot be found` remove Luminare from the Frameworks list, and readd it.
2. If there is a `nonzero codesign` issue, follow the above steps and clear your build cache.
3. If it's a code issue, review your code and adjust accordingly.

Now, you're on your own. We hope you'll make some nice Swift code. On each build you attempt, `SwiftLint` will run. **DO NOT** turn this off. When you submit your PR, this will run another check to validate you have the correct formatting. If the format is wrong, your request will be rejected.

**IMPORTANT:** You MUST have `SwiftLint` installed via `brew`. If you know how to use brew, then it's as simple as

```sh
brew install swiftlint
```

If you are unfamiliar with `brew`, [brew](https://brew.sh) is a macOS package manager which you can use to install apps (`--casks`) or command line tools (CLTs) called `formulae`.

First, install brew and follow the onscreen instructions (**DO NOT INSTALL BREW WITH SUDO**).

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then, after you've installed brew, you can now install any command line tool or app. So, install `swiftlint` next, and you'll then be able to build Loop.

Now, some **important** notes. All of the code you make **MUST** have FULL code comments. An example of this would be

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
+ // Checks for similar colors and returns an Boolean
```

## How to PR?

You have a few ways of pushing your changes from Xcode into GitHub. You should see "integrate" at the top of the code. You can push via that, via CLI, or even open VSCode and push through that.

Recommended:

```sh
# Add your changes to git staging
git add .

# Commit your changes with a meaningful message
git commit -m "Your detailed commit message"

# Push your changes to your fork
git push origin develop

# Then, go to GitHub, navigate to your fork, and you'll see a button to 'Create pull request'.
# Click it, fill in the details, and submit your PR.
# IF your PR needs changes you MUST push it as a draft PR
```

# Icons

## Before we get started

We love icons, just look at how many we already have! We love talented designers, and we love people who express their creativity for Loop.

But, as Loop grows, and so does the app quality, previous icons may be removed, making room for new icons. Do not feel disheartened, as you've shaped Loop. If your icon is selected, you will still have a section in our readme with your name and previous icon(s).

## How do I submit my icon?

If you read the local development section, you'll see where this is going!

### Create an issue

Once you're in your issue, drop in your icons you've made for Loop and the team will review each and every icon. You can upload a single `.icns` file, or a `.png`. Upload this into the given box, if the icon is submitted you'll see some feedback and your name added to the readme. If it gets rejected, then you may get some feedback in the areas we wish to focus on. If your icon has been dismissed, remember, this isn't your only chance. Come back more invigorated and show us your best! You don't need to be a professional designer, you just need to capture the feel of Loop in your design.

Now, for the Issue section, this is **NOT** for you to request an icon. Here, it is only for sharing an icon you, a friend, or someone else has made, or to link it to an external post (say, Twitter) to a user who's made this icon. If you're requesting an icon in this section, your issue will be closed.

# Localisation

We wish to localise (localize) Loop in every language possible!

We use `Localizable.strings` to localise Loop, meaning it's very simple to localise Loop in any language you want.

If you need some help, images are provided at the bottom for context.

## How to Localise?

By now, you'll be familiar. Submit a `localisation` issue, fill out which language you wish to add, change, improve, and complete any required checkboxes.

Once assigned and committed to the localised language, you may ask for the catalog to localise, or manually do it!

### Asking for a Catalog

1. In your issue, just ask @MrKai77 or @SenpaiHunters for your required language in your issue, and they'll be able to provide you with the needed file.
2. Next, you need Xcode installed. Once installed, open the language file, for example, `ko.xliff`.
3. Once you've got it, now head over to the right-hand side and add your language localised.

TIP: If you're unable to fully localise the file, just leave the unlocalised strings, and add notes to your issue on what's missed so others can localise it further.

### I Don't Need Help

1. Fork and clone Loop (how to do given above).
2. Open Loop and the `Localizable.strings` file.
3. Add your language using the `+` button at the bottom.
4. Fill in your language.

    - Incomplete translations? Leave a note in your issue to further help other localisers.

5. Also fill in `InfoPlist.strings` that will be auto-generated.
6. Finally, push your changes to your branch and format the name such as `🌐 [add/change] name`, e.g., `🌐 Add Korean localisation` or `🌐 Update English (United Kingdom`.

### Images

<img src="/assets/docs/localise.png" alt="Localise Xcode example">
<img src="/assets/docs/localise_plist.png" alt="Localise plist Xcode example">
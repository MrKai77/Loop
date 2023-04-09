<div align="center">
	<img src="Loop/Assets.xcassets/AppIcon-Default.appiconset/icon_512x512@2x@2x-1024.png" width="250px">
	<h1>Loop</h1>
	<p><em>The elegant, mouse-oriented window manager</em></p>
</div>

<p align="center">
    <a href="https://github.com/mrkai77/loop/stargazers">
        <img alt="Stargazers" src="https://img.shields.io/github/stars/mrkai77/loop?style=for-the-badge&logo=starship&color=F6C177&logoColor=D9E0EE&labelColor=302D41"></a>
    <a href="https://github.com/mrkai77/loop/releases/latest">
        <img alt="Releases" src="https://img.shields.io/github/release/mrkai77/loop.svg?style=for-the-badge&logo=github&color=EBBCBA&logoColor=D9E0EE&labelColor=302D41"/></a>
    <a href="https://github.com/mrkai77/loop/issues">
        <img alt="Issues" src="https://img.shields.io/github/issues/mrkai77/loop?style=for-the-badge&logo=gitbook&color=C4A7E7&logoColor=D9E0EE&labelColor=302D41"></a>
</p>

Introducing Loop, the revolutionary MacOS app that simplifies window management for you! With Loop, you can effortlessly choose your window direction using a radial menu triggered by a simple key press, and customize it according to your preferences with personalized colors and settings.

Gone are the days of frustratingly juggling between multiple windows and applications on your screen. With Loop, you can easily move, resize, and arrange your windows with just a few clicks, saving you valuable time and energy.

The best part? Loop is incredibly intuitive and user-friendly, so even if you're not tech-savvy, you can still enjoy its benefits without any hassle. Plus, its sleek and modern design adds a touch of elegance to your desktop.

<div align="center">
    <img src="resources/screenshots/Loop Demo.gif" width="100%">
</div>


# Installation

**Compatible with MacOS 12 and later**

Simply download the latest release [here](https://github.com/MrKai77/Loop/releases/latest)! After downloading the application, simply move it to the Applications folder and grant accessibility access to start using it!  
Installation with Homebrew is planned :3


# Features

- Window resizing with *style*
- Customizable app colors
- Fully customizable radial menu
- Option to change circular menu to rounded rectangle
- Additional keybindings for non-mouse use
- Custom trigger key for Loop
- Unlock new app icons with increased Loop usage

# Usage

1. After installation, launch Loop from your Applications folder.
1. Press the designated hotkey (see [here](#triggering-loop)) to trigger the radial menu.
1. Move your mouse to the direction you want your window to move.
1. Release the hotkey to apply the window movement.
1. To customize Loop's settings, click on the Loop icon in the menu bar and select "Settings". From there, you can customize the hotkey, colors, and other settings to your liking.

That's it! With Loop, window management is a breeze.

# Triggering Loop

You can set your own custom trigger key for Loop! Currently, the available options for triggering loop are:
- `Left Control`
- `Left Option`
- `Right Option`
- `Right Command`
- `Caps Lock` ([Additional setup needed](#using-caps-lock))
- `Function`

### Using Caps Lock

<div align="left">
    <img src="resources/screenshots/Remap Caps Lock.gif">
</div>

To set Caps Lock as the trigger key, remap it to Control in System Settings, and repeat the process for every connected keyboard. Note that Loop won't be triggered by the actual Control key, despite the remapping.

# Additional Notes

This project is licensed under the [Apache-2.0 license](LICENSE).

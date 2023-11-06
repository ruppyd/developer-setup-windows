# Developer Setup for Windows OS

This Powershell script installs and configures a development environment on a Windows PC.  Common developer tools are installed such as Git, Powershell 7, Windows Terminal, VSCode, and .NET SDK.

## Installation

> Prerequisite: script must run as Administrator and on Windows Powershell.

```
PS> DevSetup.ps1 -FullName "Your Name" -Email "youremail@domain.com"
```

Add the `-NerdConfig` switch parameter to spice up your Powershell 7 terminal with Oh My Posh:

```
PS> DevSetup.ps1 -FullName "Your Name" -Email "youremail@domain.com" -NerdConfig
```

## Roadmap

- Add the ability for the user to supplement installation of packages via winget.
- Add Powershell profile for VSCode to use Oh My Posh.

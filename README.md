# MTerminal-Jailed

An iOS 11.0-11.1.2 compatible fork of MTerminal using Ian Beer's tfp0 exploit, as seen [here](https://twitter.com/DennisBednarz/status/944187358328639489).

It's terrible, the code is terrible, and I'm terrible, but *it works*.

- [Demonstration](https://twitter.com/AppleBetasDev)
- [My Twitter](https://twitter.com/AppleBetasDev)
- [Credits](#credits)

## What I've done

This project takes two other works and combines them into a terminal for iOS 11.0-11.1.2. So people don't credit me for the exploit or original terminal, here's the work I've actually done:

- Made UI changes for iOS 11 (safe area, screen sizes like iPhone X, some keyboard fixes)
- Made it into an Xcode project (for easier debugging on jailed devices)
- Added tfp0 that runs on open
- Changed around script locations to work for what we have right now (since everything is in /bootstrap)

Read the [credits](#credits) to see who is responsible fo the rest of the work.

## What it can do

Right now, it's still very limited. It can run basic commands, but even things like logging in aren't fully implemented as they should be in the terminal (it starts `/bootstrap/bin/sh`, which is actually `zsh` with this binpack) as root.

## Compatibility

You must be using iOS 11.0-11.1.2 for the terminal to work, as that's what the async_wake exploit requires.

## Exploit

If you want to read more about the exploit and the version of async_awake-fun this terminal uses, read [the fork I used here](https://github.com/stek29/async_awake-fun)

## Credits

I only added these two projects together in order to make a jailed terminal. All credits go to these people and projects:

- [stek29](https://twitter.com/stek29) for their [async_awake-fun fork](https://github.com/stek29/async_awake-fun))
- [nullpixel](https://twitter.com/nullriver) for his [async_awake-fun fork](https://github.com/nullpixel/async_awake-fun))
- [ninjaprawn](https://twitter.com/theninjaprawn) for [async_awake-fun](https://github.com/ninjaprawn/async_awake-fun)
- [Ian Beer](https://twitter.com/i41nbeer?lang=en) for creating [async_wake](https://bugs.chromium.org/p/project-zero/issues/detail?id=1417#c3) (the exploit)
- [lordscotland](https://bitbucket.org/lordscotland/) for the [original MTerminal project](http://cydia.saurik.com/package/com.officialscheduler.mterminal/) for jailbroken devices

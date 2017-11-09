# Nimrod
Leightweight rync for project folders. Sync on save. Integrated with WebSocket controlled CI.

|||
|---|---|
|Language|CoffeeScript|
|Authors|Marc Fiedler - @mf|
|Copyright|(c)2017 Blackout Technologies [http://blackout.ai]|
|Current Package Version| 0.11.0|
|Current System Version| 1.0.2|

Nimrod is the build manager for all Blackout Technologies projects. Its designed to be easy and fast to use.
This package is the Atom extension of the Build env.
Nimrod uses `rsync` to sync your dev folders with your production/dev server.

## Robot compatibility
Since version `0.4.0` the Nimrod package is also able to synch data and
project to robots from SoftBank Robotics. Mainly: `Pepper`, `Nao` and `Romeo`

# Usage
Setup the `nimrod.json` file in the root of your project folder, add the profile information
in the settings screen and your code will be synched to your server.

Just add your username and server and nimrod will sync the files to your remote location.

![settings](https://raw.githubusercontent.com/Blackout-Technologies/Nimrod/master/img/settings.png)

> NOTE: Nimrod will ignore .git files on sync

## Configuration
A config file named `package.json` must be present in the project folder. In order
to have rsync work you at least need to fill out the `profile` settings in the
nimrod config and have an enviroment variable defined with the same name then in
your sync profile.

### Example
```json
{
    "sync": {
        "mf": [
            "Server",
            "Pepper",
            "Nao",
            "Romeeo"
        ]
    }
}
```

# Dependencies
This package requires your machine to have access to `rsync`.
> it has only been tested on macOS Sierra ~>10.12

## Additional Dependendies:
* ws ~> '3.0'

# Roadmap
* Include websocket based CI for remote building via keyboard shortcut

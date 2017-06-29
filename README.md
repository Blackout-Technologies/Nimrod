# Nimrod
Leightweight rync for project folders. Executes on save.

> Nimrod, a biblical figure described as a king of Shinar, was, according to the Book of Genesis and Books of Chronicles, the son of Cush, the great-grandson of Noah. The Bible states that he was "a mighty hunter before the Lord [and] .... began to be mighty in the earth". Extra-biblical traditions associating him with the Tower of Babel led to his reputation as a king who was rebellious against God.

Nimrod is the build manager for all Blackout Technologies projects. Its designed to be easy and fast to use.
This package is the Atom extension of the Build env.
Nimrod uses `rsync` to sync your dev folders with your production/dev server.

|||
|---|---|
|Language|CoffeeScript|
|Authors|Marc Fiedler - @mf|
|Copyright|(c)2017 Blackout Technologies [http://blackout.ai]|
|Current Package Version| 0.3.0|
|Current System Version| 0.1.4|

# Usage
Setup the `nimrod.json` file in the root of your project folder, add the profile information
in the settings screen and your code will be synched to your server.

Just add your username and server and nimrod will sync the files to your remote location.

![settings](https://raw.githubusercontent.com/Blackout-Technologies/Nimrod/master/img/settings.png)

> NOTE: Nimrod will ignore .git files on sync

## Configuration
A config file named `nimrod.json` must be present in the project folder. In order
to have rsync work you at least need the `target` and `resourceName` fields filled.

### Example
```json
{
    "resource": {
        "name": "JetStream",
        "version": "1.0.0",
        "description": "Blackout Technologies Utility Library, Python2 and Python3 compatible",
        "resourceName": "JetStream",
        "target": "development/Libs/JetStream"
    },
    "system": {
        "version": "0.1.4"
    }
}
```

# Dependencies
This package requires your machine to have access to `rsync`.
> it has only been tested on macOS Sierra ~>10.12

# Roadmap
* Include websocket based CI for remote building via keyboard shortcut

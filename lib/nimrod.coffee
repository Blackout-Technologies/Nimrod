child_process = require 'child_process'
path = require 'path'
fs = require 'fs'
ws = require 'ws'
{spawn, exec} = require 'child_process'

NimrodView = require './nimrod-view'
{CompositeDisposable,Directory,File} = require 'atom'

module.exports = Nimrod =
    nimrodView: null
    modalPanel: null
    subscriptions: null
    socket: null
    panel: null

    config:
        profileName:
            type: 'string'
            title: 'Profile name'
            default: ''
        customNamespace:
            type: 'string'
            default: 'blackout.ai'
            title: 'Your custom namespace'
        showNotifications:
            type: 'boolean'
            default: true
            title: 'Show info notifications'

    activate: (state) ->
        @nimrodView = new NimrodView(state.nimrodViewState)
        @modalPanel = atom.workspace.addModalPanel(item: @nimrodView.getElement(), visible: false)
        @registered = false

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        # register observer for saveing of a file
        @subscriptions.add atom.workspace.observeTextEditors (editor)=>
            @subscriptions.add editor.onDidSave (event)=>
                try
                    @executeOn(event.path)
                catch error
                    console.log error

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @nimrodView.destroy()

    serialize: ->
        nimrodViewState: @nimrodView.serialize()

    syncToServer: (data, dir)->
        # Sync data to remote server
        notifications = atom.config.get('nimrod.showNotifications')
        userNamespace = atom.config.get('nimrod.customNamespace')
        profileName = atom.config.get('nimrod.profileName')

        console.log "Syncing in progress "+userNamespace+"["+profileName+"]...."

        packageNameTmp = data.name.split('/')
        packageName = packageNameTmp[packageNameTmp.length - 1]

        target = ""
        if userNamespace != undefined
            target = target+'/'+userNamespace

        if data.module != undefined
            target = target+'/'+data.module

        target = target+'/'+packageName

        console.dir data.sync[profileName]
        if data.sync != undefined and data.sync[profileName] != undefined
            if notifications is true
                atom.notifications.addInfo('Synching Targets')

            for serverKey of data.sync[profileName]
                server = data.sync[profileName][serverKey]

                if server != undefined
                    # spawn rsync process
                    console.log "Sync: "+dir+" -> "+server.location+':.'+target+'/'
                    sync = spawn 'rsync', ['-r', '--exclude', '.git', dir+'/',
                        server.location+':.'+target+'/']

                    sync.stderr.on 'data', (data) ->
                        console.error(data.toString().trim())
                        if notifications is true
                            atom.notifications.addError("Sync failed")

                    sync.on 'close', (code) ->
                        if code == 0
                            if notifications is true
                                atom.notifications.addSuccess("Sync success")
                            else
                                console.error "No command executed."
                        else
                            if notifications is true
                                atom.notifications.addError("Sync failed")
        else
            atom.notifications.addError("Your sync profile could not be loaded.")

    getConfig: (callback)->
        # find the rood folder of the current path.
        # the root folder will be determined by the existance
        # of the nimrod.json
        currentPath = atom.workspace.getActivePaneItem().buffer.file.path
        dir = new File(currentPath).getParent()
        file = undefined
        while (true)
            confFile = dir.getPath() + path.sep + "package.json"
            file = new File(confFile)
            exists = file.existsSync()
            isRoot = dir.isRoot()
            if isRoot and exists is false
                atom.notifications.addError('Nimrod could not find its config file, please make sure the nimrod.json exists in the root folder of your project')
                return
            break if isRoot or exists
            dir = dir.getParent()

        # NOTE: each time the user saves, the nimrod.json can
        # potentially have changed, so there is for now nothing
        # else we can do but to reload the file every time someone
        # saves a file.
        syncProfile = atom.config.get('nimrod.syncProfile')
        syncServer = atom.config.get('nimrod.syncServer')
        robotIpAddr = atom.config.get('nimrod.syncServer')

        if syncProfile == '' and syncServer == '' and robotIpAddr == ''
            atom.notifications.addWarning("No profiles for Nimrod setup yet. Visit the settings to set up your profile.")
            return

        # open the file, and return its content to the callback
        fs.readFile confFile, (err,data)=>
            if data
                try
                    parsed = JSON.parse(data)
                catch e
                    alert("Your config file is not a valid JSON")
                    return

                configData = parsed
                callback configData, dir.getPath()
            else
                atom.notifications.addError("Unable to read Config file!")

    executeOn: (currentPath)->
        @getConfig ((config, dir) ->
            # try syncing data to the remote Server
            @syncToServer(config, dir)
        ).bind this

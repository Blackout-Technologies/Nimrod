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

    config:
    	syncProfile:
    		type: 'string'
    		default: ''
    		title: 'Profile for Synchronisation'

    	syncServer:
    		type: 'string'
    		default: ''
    		title: 'Server for Synchronisation'

    	showNotifications:
    		type: 'boolean'
    		default: 'true'
    		title: 'Display notifications'

    	robotIp:
    		type: 'string'
    		default: ''
    		title: 'Robot name or IP address'

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

        # Register command that toggles this view
        @subscriptions.add atom.commands.add 'atom-workspace', 'nimrod:toggle': => @toggle()

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @nimrodView.destroy()

    serialize: ->
        nimrodViewState: @nimrodView.serialize()

    connectToCloud: (callback) ->
        @getConfig ((config, dir) ->
            if config.resource.ci != undefined
                port = config.resource.ci.port
                target = config.resource.target
                if @socket == null or @socket == undefined
                    # probably also check of the connection is still up?
                    host = atom.config.get('nimrod.syncServer')
                    @socket = new ws("ws://#{host}:#{port}/nimrod")

                    @socket.on 'open', =>
                        atom.notifications.addInfo("Connected to build Server")
                        msg =
                            'api':
                                'version': '4.2.0'
                                'intent': 'register'
                            'interface': 'af108bb4c6f8c73129c2ac485b2a19a5'
                            'host': 'atom-package'
                        @socket.send JSON.stringify msg

                    @socket.on 'message', (data) =>
                        console.log "Got message #{data}"
                        msg = JSON.parse data
                        if msg.state != undefined and msg.state == 'OK'
                            atom.notifications.addSuccess("Build complete")
                        if msg.api.intent == 'stderr'
                            atom.notifications.addError(msg.text)
                        if msg.api.intent == 'stdout'
                            atom.notifications.addInfo(msg.text)
                        if msg.api.intent == 'registerSuccess'
                            @registered = true
                            callback true

                    @socket.on 'close', =>
                        atom.notifications.addWarning("Disconnected from build Server")
                        # set socket to null so that it can be reopened later
                        @socket = null
                        @registered = false

                        # NOTE: we should reconnect here automatically?
            else
                console.log "CI is not set, skipping"
                callback false
        ).bind this

    toggle: ->
        if @socket == undefined or @socket == null
            @connectToCloud ((success) ->
                if success and @registered
                    @getConfig ((config, dir) ->
                        @buildContent(config.resource.name, config.resource.target)
                    ).bind this
                else
                    atom.notifications.addError("Unable to build with socket offline")
            ).bind this

    buildContent: (project, target) ->
        msg =
            'api':
                'version': '4.2.0'
                'intent': 'build'
            'project': project
            'path': target
        @socket.send JSON.stringify msg

    syncToServer: (data, dir)->
        # Sync data to remote server
        notifications = atom.config.get('nimrod.showNotifications')
        syncProfile = atom.config.get('nimrod.syncProfile')
        syncServer = atom.config.get('nimrod.syncServer')
        target = data.resource.target
        syncToCloud = data.resource.syncToCloud
        if syncToCloud == undefined
            syncToCloud = true

        if target != undefined and target != ''
            if syncServer != '' and syncToCloud
                # spawn rsync process
                # console.log "Sync: "+dir+" -> "+syncProfile+'@'+syncServer+':./'+target+'/'
                sync = spawn 'rsync', ['-r', '--exclude', '.git', dir+'/',
                    syncProfile+'@'+syncServer+':./'+target+'/']

                sync.stderr.on 'data', (data) ->
                    atom.notifications.addError(data.toString().trim())

                sync.on 'close', (code) ->
                    if code == 0
                        if notifications is true
                            atom.notifications.addSuccess('Project successfully synched')
                        else
                            console.log "No command executed."
                    else
                        atom.notifications.addError('Unable to synch project!')

    syncToRobot: (data, dir) ->
        # Sync data to robot in your network
        notifications = atom.config.get('nimrod.showNotifications')

        console.log 'nao@'+robotIpAddr+':./'+data.resource.target+'/'
        if data.resource.syncToRobot != undefined and data.resource.syncToRobot
            robotIpAddr = atom.config.get('nimrod.robotIp')
            if robotIpAddr != ''
                roboSync = spawn 'rsync', ['-r', '--exclude', '.git', dir+'/',
                    'nao@'+robotIpAddr+':./'+data.resource.target+'/']

                roboSync.stderr.on 'data', (data) ->
                    atom.notifications.addError(data.toString().trim())

                roboSync.on 'close', (code) ->
                    if code == 0
                        if notifications is true
                            atom.notifications.addSuccess('Robot code synched')
                        else
                            console.log "No command executed."
                    else
                        atom.notifications.addError('Unable to synch robot code!')
            else
                console.log("Remote Addr is empty, not syncing")
        else
            console.log("Resource is empty, not syncing")

    getConfig: (callback)->
        # find the rood folder of the current path.
        # the root folder will be determined by the existance
        # of the nimrod.json
        currentPath = atom.workspace.getActivePaneItem().buffer.file.path
        dir = new File(currentPath).getParent()
        file = undefined
        while (true)
            confFile = dir.getPath() + path.sep + "nimrod.json"
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

                callback parsed, dir.getPath()
            else
                atom.notifications.addError("Unable to read Config file!")

    executeOn: (currentPath)->
        console.log "executeOn #{currentPath}"
        @getConfig ((config, dir) ->
            notifications = atom.config.get('nimrod.showNotifications')
            if notifications is true
                atom.notifications.addInfo('Synching data...')

            # try syncing data to the remote Server
            @syncToServer(config, dir)
            # try to sync data to the robot
            @syncToRobot(config, dir)
        ).bind this

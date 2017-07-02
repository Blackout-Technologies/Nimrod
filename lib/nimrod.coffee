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

    toggle: ->
        if @socket == null
            # probably also check of the connection is still up?
            host = atom.config.get('nimrod.syncServer')
            @socket = new ws("ws://#{host}:8100")

        msg =
            'api':
                'version': '4.2.0'
                'intent': 'build'
            'path': ''

        @socket.on 'open', ->
            atom.notifications.addInfo("Connected to build Server")
            Nimrod.socket.send JSON.stringify msg

        @socket.on 'message', (data) ->
            console.log "Got message #{data}"
            msg = JSON.parse data
            if msg.state == 'OK'
                atom.notifications.addSuccess("Build complete")

        @socket.on 'close', ->
            atom.notifications.addWarning("Disconnected from build Server")
            @socket = null


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
                sync = spawn 'rsync', ['-r', '--exclude', '.git', dir.getPath()+'/',
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

        if data.resource.syncToRobot != undefined and data.resource.syncToRobot
            robotIpAddr = atom.config.get('nimrod.robotIp')
            if robotIpAddr != ''
                console.log 'nao@'+robotIpAddr+':./'+data.resource.target+'/'
                roboSync = spawn 'rsync', ['-r', '--exclude', '.git', dir.getPath()+'/',
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

    executeOn: (currentPath)->
        @config = {}
        syncProfile = atom.config.get('nimrod.syncProfile')
        syncServer = atom.config.get('nimrod.syncServer')
        robotIpAddr = atom.config.get('nimrod.syncServer')
        notifications = atom.config.get('nimrod.showNotifications')

        if syncProfile == '' and syncServer == '' and robotIpAddr == ''
            atom.notifications.addWarning("No profiles for Nimrod setup yet. Visit the settings to set up your profile.")
            return

        @config.profile = syncProfile+'@'+syncServer

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

        fs.readFile confFile, (err,data)=>
            if data
                try
                    parsed = JSON.parse(data)
                catch e
                    alert("Your config file is not a valid JSON")
                    return

                @config = parsed
            @config.cwd = dir.getPath()

            if notifications is true
                atom.notifications.addInfo('Synching data...')
            # try syncing data to the remote Server
            @syncToServer(parsed, dir)
            # try to sync data to the robot
            @syncToRobot(parsed, dir)

            cwd: @config.cwd

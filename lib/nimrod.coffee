child_process = require 'child_process'
path = require 'path'
fs = require 'fs'
{spawn, exec} = require 'child_process'

NimrodView = require './nimrod-view'
{CompositeDisposable,Directory,File} = require 'atom'

module.exports = Nimrod =
    nimrodView: null
    modalPanel: null
    subscriptions: null

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

    executeOn: (currentPath)->
        @config = {}
        syncProfile = atom.config.get('nimrod.syncProfile')
        syncServer = atom.config.get('nimrod.syncServer')
        # console.log 'Nimrod Profile: '+syncProfile+'@'+syncServer

        @config.profile = syncProfile+'@'+syncServer
        if syncProfile is ''
            atom.notifications.addError('You have Nimrod installed but did not set a Profile! Go to settings -> Nimrod in order to set up a profile for synch')
            return

        if syncServer is ''
            atom.notifications.addError('You have Nimrod installed but did not set a Server! Go to settings -> Nimrod in order to set up a profile for synch')
            return

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

            if parsed.resource.target != undefined and parsed.resource.target != ''
                suppress = atom.config.get('nimrod.showNotifications')
                if suppress is true
                    atom.notifications.addInfo('Synching data...')

                sync = spawn 'rsync', ['-r', '-l', '--exclude', '.git',
                    dir.getPath()+'/',
                    syncProfile+'@'+syncServer+':./'+parsed.resource.target+'/']

                sync.stderr.on 'data', (data) ->
                    atom.notifications.addError(data.toString().trim())

                sync.on 'close', (code) ->
                    if code == 0
                        if suppress is true
                            atom.notifications.addSuccess('Project successfully synched')
                        else
                            console.log "No command executed."
                    else
                        atom.notifications.addError('Unable to synch project!')

                cwd: @config.cwd

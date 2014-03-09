//TODO: Don't overlay player controls.
//TODO: Use local media
//TODO: Use styled media receiver
//TODO: Reload when seeking
//TODO: Replace html5 player with jwplayer

(function () {
    'use strict';

    var MEDIA_SOURCE_URL = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
    var PROGRESS_BAR_WIDTH = 600;

    /**
     * Constants of states for Chromecast device
     **/
    var DEVICE_STATE = {
        'IDLE': 0,
        'ACTIVE': 1,
        'WARNING': 2,
        'ERROR': 3
    };

    /**
     * Constants of states for CastPlayer
     **/
    var PLAYER_STATE = {
        'IDLE': 'IDLE',
        'LOADING': 'LOADING',
        'LOADED': 'LOADED',
        'PLAYING': 'PLAYING',
        'PAUSED': 'PAUSED',
        'STOPPED': 'STOPPED',
        'SEEKING': 'SEEKING',
        'ERROR': 'ERROR'
    };

    /**
     * Cast player object
     * main variables:
     *  - deviceState for Cast mode:
     *    IDLE: Default state indicating that Cast extension is installed, but showing no current activity
     *    ACTIVE: Shown when Chrome has one or more local activities running on a receiver
     *    WARNING: Shown when the device is actively being used, but when one or more issues have occurred
     *    ERROR: Should not normally occur, but shown when there is a failure
     *  - Cast player variables for controlling Cast mode media playback
     *  - Local player variables for controlling local mode media playbacks
     *  - Current media variables for transition between Cast and local modes
     */
    var CastPlayer = function () {
        /* device variables */
        // @type {DEVICE_STATE} A state for device
        this.deviceState = DEVICE_STATE.IDLE;

        /* Cast player variables */
        // @type {Object} a chrome.cast.media.Media object
        this.currentMediaSession = null;
        // @type {Number} volume
        this.currentVolume = 0.5;
        // @type {Boolean} A flag for autoplay after load
        this.autoplay = true;
        // @type {string} a chrome.cast.Session object
        this.session = null;
        // @type {PLAYER_STATE} A state for Cast media player
        this.castPlayerState = PLAYER_STATE.IDLE;

        /* Local player variables */
        // @type {PLAYER_STATE} A state for local media player
        this.localPlayerState = PLAYER_STATE.IDLE;
        // @type {HTMLElement} local player
        this.localPlayer = null;

        /* Current media variables */
        // @type {Boolean} Audio on and off
        this.audio = true;
        // @type {Number} A number for current media index
        this.currentMediaIndex = 0;
        // @type {Number} A number for current media time
        this.currentMediaTime = 0;
        // @type {Number} A number for current media duration
        this.currentMediaDuration = -1;
        // @type {Timer} A timer for tracking progress of media
        this.timer = null;
        // @type {Boolean} A boolean to stop timer update of progress when triggered by media status event
        this.progressFlag = true;
        // @type {Number} A number in milliseconds for minimal progress update
        this.timerStep = 1000;

        this.initializeCastPlayer();
        this.initializeLocalPlayer();
    };

    /**
     * Initialize local media player
     */
    CastPlayer.prototype.initializeLocalPlayer = function () {
        this.localPlayer = document.getElementById('video_element')
    };

    /**
     * Initialize Cast media player
     * Initializes the API. Note that either successCallback and errorCallback will be
     * invoked once the API has finished initialization. The sessionListener and
     * receiverListener may be invoked at any time afterwards, and possibly more than once.
     */
    CastPlayer.prototype.initializeCastPlayer = function () {

        if (!chrome.cast || !chrome.cast.isAvailable) {
            setTimeout(this.initializeCastPlayer.bind(this), 1000);
            return;
        }
        // default set to the default media receiver app ID
        // optional: you may change it to point to your own
        var applicationID = chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID;

        // request session
        var sessionRequest = new chrome.cast.SessionRequest(applicationID);
        var apiConfig = new chrome.cast.ApiConfig(sessionRequest,
            this.sessionListener.bind(this),
            this.receiverListener.bind(this));

        chrome.cast.initialize(apiConfig, this.onInitSuccess.bind(this), this.onError.bind(this));

        this.initializeUI();
    };

    /**
     * Callback function for init success
     */
    CastPlayer.prototype.onInitSuccess = function () {
        console.log("init success");
        this.updateMediaControlUI();
    };

    /**
     * Generic error callback function
     */
    CastPlayer.prototype.onError = function () {
        console.log("error");
    };

    /**
     * @param {!Object} e A new session
     * This handles auto-join when a page is reloaded
     * When active session is detected, playback will automatically
     * join existing session and occur in Cast mode and media
     * status gets synced up with current media of the session
     */
    CastPlayer.prototype.sessionListener = function (e) {
        this.session = e;
        if (this.session) {
            this.deviceState = DEVICE_STATE.ACTIVE;
            if (this.session.media[0]) {
                this.onMediaDiscovered('activeSession', this.session.media[0]);
            }
            else {
                this.loadMedia(this.currentMediaIndex);
            }
            this.session.addUpdateListener(this.sessionUpdateListener.bind(this));
        }
    };

    /**
     * @param {string} e Receiver availability
     * This indicates availability of receivers but
     * does not provide a list of device IDs
     */
    CastPlayer.prototype.receiverListener = function (e) {
        if (e === 'available') {
            console.log("receiver found");
        }
        else {
            console.log("receiver list empty");
        }
    };

    /**
     * session update listener
     */
    CastPlayer.prototype.sessionUpdateListener = function (isAlive) {
        if (!isAlive) {
            this.session = null;
            this.deviceState = DEVICE_STATE.IDLE;
            this.castPlayerState = PLAYER_STATE.IDLE;
            this.currentMediaSession = null;
            clearInterval(this.timer);
            this.updateDisplayMessage();

            // continue to play media locally
            console.log("current time: " + this.currentMediaTime);
            this.playMediaLocally(this.currentMediaTime);
            this.updateMediaControlUI();
        }
    };

    /**
     * Select a media content
     * @param {Number} mediaIndex A number for media index
     */
    // TODO: Don't delete. Similar logic is needed when seeking.
    CastPlayer.prototype.selectMedia = function (mediaIndex) {
        console.log("media selected" + mediaIndex);

        this.currentMediaIndex = mediaIndex;
        // reset progress bar
        var pi = document.getElementById("progress_indicator");
        var p = document.getElementById("progress");

        // reset currentMediaTime
        this.currentMediaTime = 0;

        p.style.width = '0px';
        pi.style.marginLeft = -21 - PROGRESS_BAR_WIDTH + 'px';

        if (!this.currentMediaSession) {
            if (this.localPlayerState == PLAYER_STATE.PLAYING) {
                this.localPlayerState = PLAYER_STATE.IDLE;
                this.playMediaLocally(0);
            }
        }
        else {
            this.castPlayerState = PLAYER_STATE.IDLE;
            this.playMedia();
        }
        this.selectMediaUpdateUI(mediaIndex);
    };

    /**
     * Requests that a receiver application session be created or joined. By default, the SessionRequest
     * passed to the API at initialization time is used; this may be overridden by passing a different
     * session request in opt_sessionRequest.
     */
    CastPlayer.prototype.launchApp = function () {
        console.log("launching app...");
        chrome.cast.requestSession(this.onRequestSessionSuccess.bind(this), this.onLaunchError.bind(this));
        if (this.timer) {
            clearInterval(this.timer);
        }
    };

    /**
     * Callback function for request session success
     * @param {Object} e A chrome.cast.Session object
     */
    CastPlayer.prototype.onRequestSessionSuccess = function (e) {
        console.log("session success: " + e.sessionId);
        this.session = e;
        this.deviceState = DEVICE_STATE.ACTIVE;
        this.updateMediaControlUI();
        this.loadMedia(this.currentMediaIndex);
        this.session.addUpdateListener(this.sessionUpdateListener.bind(this));
    };

    /**
     * Callback function for launch error
     */
    CastPlayer.prototype.onLaunchError = function () {
        console.log("launch error");
        this.deviceState = DEVICE_STATE.ERROR;
    };

    /**
     * Stops the running receiver application associated with the session.
     */
    CastPlayer.prototype.stopApp = function () {
        this.session.stop(this.onStopAppSuccess.bind(this, 'Session stopped'),
            this.onError.bind(this));

    };

    /**
     * Callback function for stop app success
     */
    CastPlayer.prototype.onStopAppSuccess = function (message) {
        console.log(message);
        this.deviceState = DEVICE_STATE.IDLE;
        this.castPlayerState = PLAYER_STATE.IDLE;
        this.currentMediaSession = null;
        clearInterval(this.timer);
        this.updateDisplayMessage();

        // continue to play media locally
        console.log("current time: " + this.currentMediaTime);
        this.playMediaLocally(this.currentMediaTime);
        this.updateMediaControlUI();
    };

    /**
     * Loads media into a running receiver application
     * @param {Number} mediaIndex An index number to indicate current media content
     */
    CastPlayer.prototype.loadMedia = function (mediaIndex) {
        if (!this.session) {
            console.log("no session");
            return;
        }
        console.log("loading..." + MEDIA_SOURCE_URL);
        var mediaInfo = new chrome.cast.media.MediaInfo(MEDIA_SOURCE_URL);
        mediaInfo.contentType = 'video/mp4';
        var request = new chrome.cast.media.LoadRequest(mediaInfo);
        request.autoplay = this.autoplay;
        if (this.localPlayerState == PLAYER_STATE.PLAYING) {
            request.currentTime = this.localPlayer.currentTime;
        }
        else {
            request.currentTime = 0;
        }

        this.castPlayerState = PLAYER_STATE.LOADING;
        this.session.loadMedia(request,
            this.onMediaDiscovered.bind(this, 'loadMedia'),
            this.onLoadMediaError.bind(this));
    };

    /**
     * Callback function for loadMedia success
     * @param {Object} mediaSession A new media object.
     */
    CastPlayer.prototype.onMediaDiscovered = function (how, mediaSession) {
        console.log("new media session ID:" + mediaSession.mediaSessionId + ' (' + how + ')');
        this.currentMediaSession = mediaSession;
        if (how == 'loadMedia') {
            if (this.autoplay) {
                this.castPlayerState = PLAYER_STATE.PLAYING;
            }
            else {
                this.castPlayerState = PLAYER_STATE.LOADED;
            }
        }

        if (how == 'activeSession') {
            this.castPlayerState = this.session.media[0].playerState;
            this.currentMediaTime = this.session.media[0].currentTime;
        }

        if (this.castPlayerState == PLAYER_STATE.PLAYING) {
            // start progress timer
            this.startProgressTimer(this.incrementMediaTime);
        }

        this.currentMediaSession.addUpdateListener(this.onMediaStatusUpdate.bind(this));

        this.currentMediaDuration = this.currentMediaSession.media.duration;
        var duration = this.currentMediaDuration;
        var hr = parseInt(duration / 3600);
        duration -= hr * 3600;
        var min = parseInt(duration / 60);
        var sec = parseInt(duration % 60);
        if (hr > 0) {
            duration = hr + ":" + min + ":" + sec;
        }
        else {
            if (min > 0) {
                duration = min + ":" + sec;
            }
            else {
                duration = sec;
            }
        }
        document.getElementById("duration").innerHTML = duration;

        if (this.localPlayerState == PLAYER_STATE.PLAYING) {
            this.localPlayerState == PLAYER_STATE.STOPPED;
            var vi = document.getElementById('video_image');
            vi.style.display = 'block';
            this.localPlayer.style.display = 'none';
            // start progress timer
            this.startProgressTimer(this.incrementMediaTime);
        }
        // update UIs
        this.updateMediaControlUI();
        this.updateDisplayMessage();
    };

    /**
     * Callback function when media load returns error
     */
    CastPlayer.prototype.onLoadMediaError = function (e) {
        console.log("media error");
        this.castPlayerState = PLAYER_STATE.IDLE;
        // update UIs
        this.updateMediaControlUI();
        this.updateDisplayMessage();
    };

    /**
     * Callback function for media status update from receiver
     * @param {!Boolean} e true/false
     */
    CastPlayer.prototype.onMediaStatusUpdate = function (e) {
        if (e == false) {
            this.currentMediaTime = 0;
            this.castPlayerState = PLAYER_STATE.IDLE;
        }
        console.log("updating media");
        this.updateProgressBar(e);
        this.updateDisplayMessage();
        this.updateMediaControlUI();
    };

    /**
     * Helper function
     * Increment media current position by 1 second
     */
    CastPlayer.prototype.incrementMediaTime = function () {
        if (this.castPlayerState == PLAYER_STATE.PLAYING || this.localPlayerState == PLAYER_STATE.PLAYING) {
            if (this.currentMediaTime < this.currentMediaDuration) {
                this.currentMediaTime += 1;
                this.updateProgressBarByTimer();
            }
            else {
                this.currentMediaTime = 0;
                clearInterval(this.timer);
            }
        }
    };

    /**
     * Play media in local player
     * @param {Number} currentTime A number for media current position
     */
    CastPlayer.prototype.playMediaLocally = function (currentTime) {
        var vi = document.getElementById('video_image');
        vi.style.display = 'none';
        this.localPlayer.style.display = 'block';
        if (this.localPlayerState != PLAYER_STATE.PLAYING && this.localPlayerState != PLAYER_STATE.PAUSED) {
            this.localPlayer.src = MEDIA_SOURCE_URL;
            this.localPlayer.load();
            this.localPlayer.addEventListener('loadeddata', this.onMediaLoadedLocally.bind(this, currentTime));
        }
        else {
            this.localPlayer.play();
            this.startProgressTimer(this.incrementMediaTime);
        }
        this.localPlayerState = PLAYER_STATE.PLAYING;
        this.updateMediaControlUI();
    };

    /**
     * Callback when media is loaded in local player
     * @param {Number} currentTime A number for media current position
     */
    CastPlayer.prototype.onMediaLoadedLocally = function (currentTime) {
        this.currentMediaDuration = this.localPlayer.duration;
        var duration = this.currentMediaDuration;

        var hr = parseInt(duration / 3600);
        duration -= hr * 3600;
        var min = parseInt(duration / 60);
        var sec = parseInt(duration % 60);
        if (hr > 0) {
            duration = hr + ":" + min + ":" + sec;
        }
        else {
            if (min > 0) {
                duration = min + ":" + sec;
            }
            else {
                duration = sec;
            }
        }
        document.getElementById("duration").innerHTML = duration;
        this.localPlayer.currentTime = currentTime;
        this.localPlayer.play();
        this.startProgressTimer(this.incrementMediaTime);
    };

    /**
     * Play media in Cast mode
     */
    CastPlayer.prototype.playMedia = function () {
        if (!this.currentMediaSession) {
            this.playMediaLocally(0);
            return;
        }

        switch (this.castPlayerState) {
            case PLAYER_STATE.LOADED:
            case PLAYER_STATE.PAUSED:
                this.currentMediaSession.play(null,
                    this.mediaCommandSuccessCallback.bind(this, "playing started for " + this.currentMediaSession.sessionId),
                    this.onError.bind(this));
                this.currentMediaSession.addUpdateListener(this.onMediaStatusUpdate.bind(this));
                this.castPlayerState = PLAYER_STATE.PLAYING;
                // start progress timer
                this.startProgressTimer(this.incrementMediaTime);
                break;
            case PLAYER_STATE.IDLE:
            case PLAYER_STATE.LOADING:
            case PLAYER_STATE.STOPPED:
                this.loadMedia(this.currentMediaIndex);
                this.currentMediaSession.addUpdateListener(this.onMediaStatusUpdate.bind(this));
                this.castPlayerState = PLAYER_STATE.PLAYING;
                break;
            default:
                break;
        }
        this.updateMediaControlUI();
        this.updateDisplayMessage();
    };

    /**
     * Pause media playback in Cast mode
     */
    CastPlayer.prototype.pauseMedia = function () {
        if (!this.currentMediaSession) {
            this.pauseMediaLocally();
            return;
        }

        if (this.castPlayerState == PLAYER_STATE.PLAYING) {
            this.castPlayerState = PLAYER_STATE.PAUSED;
            this.currentMediaSession.pause(null,
                this.mediaCommandSuccessCallback.bind(this, "paused " + this.currentMediaSession.sessionId),
                this.onError.bind(this));
            this.updateMediaControlUI();
            this.updateDisplayMessage();
            clearInterval(this.timer);
        }
    };

    /**
     * Pause media playback in local player
     */
    CastPlayer.prototype.pauseMediaLocally = function () {
        this.localPlayer.pause();
        this.localPlayerState = PLAYER_STATE.PAUSED;
        this.updateMediaControlUI();
        clearInterval(this.timer);
    };

    /**
     * Stop media playback in either Cast or local mode
     */
    CastPlayer.prototype.stopMedia = function () {
        if (!this.currentMediaSession) {
            this.stopMediaLocally();
            return;
        }

        this.currentMediaSession.stop(null,
            this.mediaCommandSuccessCallback.bind(this, "stopped " + this.currentMediaSession.sessionId),
            this.onError.bind(this));
        this.castPlayerState = PLAYER_STATE.STOPPED;
        clearInterval(this.timer);

        this.updateDisplayMessage();
        this.updateMediaControlUI();
    };

    /**
     * Stop media playback in local player
     */
    CastPlayer.prototype.stopMediaLocally = function () {
        var vi = document.getElementById('video_image')
        vi.style.display = 'block';
        this.localPlayer.style.display = 'none';
        this.localPlayer.stop();
        this.localPlayerState = PLAYER_STATE.STOPPED;
        this.updateMediaControlUI();
    };

    /**
     * Set media volume in Cast mode
     * @param {Boolean} mute A boolean
     */
    CastPlayer.prototype.setReceiverVolume = function (mute) {
        var p = document.getElementById("audio_bg_level");
        if (event.currentTarget.id == 'audio_bg_track') {
            var pos = 100 - parseInt(event.offsetY);
        }
        else {
            var pos = parseInt(p.clientHeight) - parseInt(event.offsetY);
        }
        if (!this.currentMediaSession) {
            this.localPlayer.volume = pos < 100 ? pos / 100 : 1;
            p.style.height = pos + 'px';
            p.style.marginTop = -pos + 'px';
            return;
        }

        if (event.currentTarget.id == 'audio_bg_track' || event.currentTarget.id == 'audio_bg_level') {
            // add a drag to avoid loud volume
            if (pos < 100) {
                var vScale = this.currentVolume * 100;
                if (pos > vScale) {
                    pos = vScale + (pos - vScale) / 2;
                }
                p.style.height = pos + 'px';
                p.style.marginTop = -pos + 'px';
                this.currentVolume = pos / 100;
            }
            else {
                this.currentVolume = 1;
            }
        }

        if (!mute) {
            this.session.setReceiverVolumeLevel(this.currentVolume,
                this.mediaCommandSuccessCallback.bind(this),
                this.onError.bind(this));
        }
        else {
            this.session.setReceiverMuted(true,
                this.mediaCommandSuccessCallback.bind(this),
                this.onError.bind(this));
        }
        this.updateMediaControlUI();
    };

    /**
     * Mute media function in either Cast or local mode
     */
    CastPlayer.prototype.muteMedia = function () {
        if (this.audio == true) {
            this.audio = false;
            document.getElementById('audio_on').style.display = 'none';
            document.getElementById('audio_off').style.display = 'block';
            if (this.currentMediaSession) {
                this.setReceiverVolume(true);
            }
            else {
                this.localPlayer.muted = true;
            }
        }
        else {
            this.audio = true;
            document.getElementById('audio_on').style.display = 'block';
            document.getElementById('audio_off').style.display = 'none';
            if (this.currentMediaSession) {
                this.setReceiverVolume(false);
            }
            else {
                this.localPlayer.muted = false;
            }
        }
        this.updateMediaControlUI();
    };


    /**
     * media seek function in either Cast or local mode
     * @param {Event} e An event object from seek
     */
    CastPlayer.prototype.seekMedia = function (event) {
        var pos = parseInt(event.offsetX);
        var pi = document.getElementById("progress_indicator");
        var p = document.getElementById("progress");
        if (event.currentTarget.id == 'progress_indicator') {
            var curr = parseInt(this.currentMediaTime + this.currentMediaDuration * pos / PROGRESS_BAR_WIDTH);
            var pp = parseInt(pi.style.marginLeft) + pos;
            var pw = parseInt(p.style.width) + pos;
        }
        else {
            var curr = parseInt(pos * this.currentMediaDuration / PROGRESS_BAR_WIDTH);
            var pp = pos - 21 - PROGRESS_BAR_WIDTH;
            var pw = pos;
        }

        if (this.localPlayerState == PLAYER_STATE.PLAYING || this.localPlayerState == PLAYER_STATE.PAUSED) {
            this.localPlayer.currentTime = curr;
            this.currentMediaTime = curr;
            this.localPlayer.play();
        }

        if (this.localPlayerState == PLAYER_STATE.PLAYING || this.localPlayerState == PLAYER_STATE.PAUSED
            || this.castPlayerState == PLAYER_STATE.PLAYING || this.castPlayerState == PLAYER_STATE.PAUSED) {
            p.style.width = pw + 'px';
            pi.style.marginLeft = pp + 'px';
        }

        if (this.castPlayerState != PLAYER_STATE.PLAYING && this.castPlayerState != PLAYER_STATE.PAUSED) {
            return;
        }

        this.currentMediaTime = curr;
        console.log('Seeking ' + this.currentMediaSession.sessionId + ':' +
            this.currentMediaSession.mediaSessionId + ' to ' + pos + "%");
        var request = new chrome.cast.media.SeekRequest();
        request.currentTime = this.currentMediaTime;
        this.currentMediaSession.seek(request,
            this.onSeekSuccess.bind(this, 'media seek done'),
            this.onError.bind(this));
        this.castPlayerState = PLAYER_STATE.SEEKING;

        this.updateDisplayMessage();
        this.updateMediaControlUI();
    };

    /**
     * Callback function for seek success
     * @param {String} info A string that describe seek event
     */
    CastPlayer.prototype.onSeekSuccess = function (info) {
        console.log(info);
        this.castPlayerState = PLAYER_STATE.PLAYING;
        this.updateDisplayMessage();
        this.updateMediaControlUI();
    };

    /**
     * Callback function for media command success
     */
    CastPlayer.prototype.mediaCommandSuccessCallback = function (info, e) {
        console.log(info);
    };

    /**
     * Update progress bar when there is a media status update
     * @param {Object} e An media status update object
     */
    CastPlayer.prototype.updateProgressBar = function (e) {
        var p = document.getElementById("progress");
        var pi = document.getElementById("progress_indicator");
        if (e.idleReason == 'FINISHED' && e.playerState == 'IDLE') {
            p.style.width = '0px';
            pi.style.marginLeft = -21 - PROGRESS_BAR_WIDTH + 'px';
            clearInterval(this.timer);
            this.castPlayerState = PLAYER_STATE.STOPPED;
            this.updateDisplayMessage();
        }
        else {
            p.style.width = Math.ceil(PROGRESS_BAR_WIDTH * e.currentTime / this.currentMediaSession.media.duration + 1) + 'px';
            this.progressFlag = false;
            setTimeout(this.setProgressFlag.bind(this), 1000); // don't update progress in 1 second
            var pp = Math.ceil(PROGRESS_BAR_WIDTH * e.currentTime / this.currentMediaSession.media.duration);
            pi.style.marginLeft = -21 - PROGRESS_BAR_WIDTH + pp + 'px';
        }
    };

    /**
     * Set progressFlag with a timeout of 1 second to avoid UI update
     * until a media status update from receiver
     */
    CastPlayer.prototype.setProgressFlag = function () {
        this.progressFlag = true;
    };

    /**
     * Update progress bar based on timer
     */
    CastPlayer.prototype.updateProgressBarByTimer = function () {
        var p = document.getElementById("progress");
        if (isNaN(parseInt(p.style.width))) {
            p.style.width = 0;
        }
        if (this.currentMediaDuration > 0) {
            var pp = Math.floor(PROGRESS_BAR_WIDTH * this.currentMediaTime / this.currentMediaDuration);
        }

        if (this.progressFlag) {
            // don't update progress if it's been updated on media status update event
            p.style.width = pp + 'px';
            var pi = document.getElementById("progress_indicator");
            pi.style.marginLeft = -21 - PROGRESS_BAR_WIDTH + pp + 'px';
        }

        if (pp > PROGRESS_BAR_WIDTH) {
            clearInterval(this.timer);
            this.deviceState = DEVICE_STATE.IDLE;
            this.castPlayerState = PLAYER_STATE.IDLE;
            this.updateDisplayMessage();
            this.updateMediaControlUI();
        }
    };

    /**
     * Update display message depending on cast mode by deviceState
     */
    CastPlayer.prototype.updateDisplayMessage = function () {
        if (this.deviceState != DEVICE_STATE.ACTIVE || this.castPlayerState == PLAYER_STATE.IDLE || this.castPlayerState == PLAYER_STATE.STOPPED) {
            document.getElementById("playerstate").style.display = 'none';
            document.getElementById("playerstatebg").style.display = 'none';
            document.getElementById("play").style.display = 'block';
            document.getElementById("video_image_overlay").style.display = 'none';
        }
        else {
            document.getElementById("playerstate").style.display = 'block';
            document.getElementById("playerstatebg").style.display = 'block';
            document.getElementById("video_image_overlay").style.display = 'block';
            document.getElementById("playerstate").innerHTML = this.castPlayerState
                + " on " + this.session.receiver.friendlyName;
        }
    }

    /**
     * Update media control UI components based on localPlayerState or castPlayerState
     */
    CastPlayer.prototype.updateMediaControlUI = function () {
        if (this.deviceState == DEVICE_STATE.ACTIVE) {
            document.getElementById("casticonactive").style.display = 'block';
            document.getElementById("casticonidle").style.display = 'none';
            var playerState = this.castPlayerState;
        }
        else {
            document.getElementById("casticonidle").style.display = 'block';
            document.getElementById("casticonactive").style.display = 'none';
            var playerState = this.localPlayerState;
        }

        switch (playerState) {
            case PLAYER_STATE.LOADED:
            case PLAYER_STATE.PLAYING:
                document.getElementById("play").style.display = 'none';
                document.getElementById("pause").style.display = 'block';
                break;
            case PLAYER_STATE.PAUSED:
            case PLAYER_STATE.IDLE:
            case PLAYER_STATE.LOADING:
            case PLAYER_STATE.STOPPED:
                document.getElementById("play").style.display = 'block';
                document.getElementById("pause").style.display = 'none';
                break;
            default:
                break;
        }
    }

    /**
     * Update UI components after selectMedia call
     * @param {Number} mediaIndex An number
     */
    CastPlayer.prototype.selectMediaUpdateUI = function (mediaIndex) {
//        document.getElementById('video_image').src = MEDIA_SOURCE_ROOT + this.mediaContents[mediaIndex]['thumb'];
        document.getElementById("progress").style.width = '0px';
//        document.getElementById("media_title").innerHTML = this.mediaContents[mediaIndex]['title'];
//        document.getElementById("media_subtitle").innerHTML = this.mediaContents[mediaIndex]['subtitle'];
//        document.getElementById("media_desc").innerHTML = this.mediaContents[mediaIndex]['description'];
    };

    /**
     * Initialize UI components and add event listeners
     */
    CastPlayer.prototype.initializeUI = function () {
        // add event handlers to UI components
        document.getElementById("casticonidle").addEventListener('click', this.launchApp.bind(this));
        document.getElementById("casticonactive").addEventListener('click', this.stopApp.bind(this));
        document.getElementById("progress_bg").addEventListener('click', this.seekMedia.bind(this));
        document.getElementById("progress").addEventListener('click', this.seekMedia.bind(this));
        document.getElementById("progress_indicator").addEventListener('dragend', this.seekMedia.bind(this));
        document.getElementById("audio_on").addEventListener('click', this.muteMedia.bind(this));
        document.getElementById("audio_off").addEventListener('click', this.muteMedia.bind(this));
        document.getElementById("audio_bg").addEventListener('mouseover', this.showVolumeSlider.bind(this));
        document.getElementById("audio_on").addEventListener('mouseover', this.showVolumeSlider.bind(this));
        document.getElementById("audio_bg_level").addEventListener('mouseover', this.showVolumeSlider.bind(this));
        document.getElementById("audio_bg_track").addEventListener('mouseover', this.showVolumeSlider.bind(this));
        document.getElementById("audio_bg_level").addEventListener('click', this.setReceiverVolume.bind(this, false));
        document.getElementById("audio_bg_track").addEventListener('click', this.setReceiverVolume.bind(this, false));
        document.getElementById("audio_bg").addEventListener('mouseout', this.hideVolumeSlider.bind(this));
        document.getElementById("audio_on").addEventListener('mouseout', this.hideVolumeSlider.bind(this));

        // enable play/pause buttons
        document.getElementById("play").addEventListener('click', this.playMedia.bind(this));
        document.getElementById("pause").addEventListener('click', this.pauseMedia.bind(this));
        document.getElementById("progress_indicator").draggable = true;

    };

    /**
     * Show the volume slider
     */
    CastPlayer.prototype.showVolumeSlider = function () {
        document.getElementById('audio_bg').style.opacity = 1;
        document.getElementById('audio_bg_track').style.opacity = 1;
        document.getElementById('audio_bg_level').style.opacity = 1;
        document.getElementById('audio_indicator').style.opacity = 1;
    };

    /**
     * Hide the volume slider
     */
    CastPlayer.prototype.hideVolumeSlider = function () {
        document.getElementById('audio_bg').style.opacity = 0;
        document.getElementById('audio_bg_track').style.opacity = 0;
        document.getElementById('audio_bg_level').style.opacity = 0;
        document.getElementById('audio_indicator').style.opacity = 0;
    };

    /**
     * @param {function} A callback function for the fucntion to start timer
     */
    CastPlayer.prototype.startProgressTimer = function (callback) {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = null;
        }

        // start progress timer
        this.timer = setInterval(callback.bind(this), this.timerStep);
    };

    window.CastPlayer = CastPlayer;
})();

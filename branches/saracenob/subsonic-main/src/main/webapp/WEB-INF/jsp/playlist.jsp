<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="iso-8859-1"%>
<%@ include file="doctype.jsp" %>

<html>
    <head>
        <%@ include file="head.jsp" %>
        <script type="text/javascript" src="<c:url value="/dwr/interface/nowPlayingService.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/dwr/interface/playlistService.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/dwr/engine.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/dwr/util.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/prototype.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/scripts.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/swfobject.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/webfx/range.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/webfx/timer.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/webfx/slider.js"/>"></script>
        
        <!-- START Player Mod scripts     -->
        <script type="text/javascript" src="<c:url value="/script/dddropdownpanel.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/switchcontent.js"/>"></script>
        <link type="text/css" rel="stylesheet" href="<c:url value="/style/dddropdownpanel.css"/>">
        <!-- END Player Mod Scripts        -->

        <link type="text/css" rel="stylesheet" href="<c:url value="/script/webfx/luna.css"/>">
    </head>

    <body class="bgcolor2 playlistframe" onLoad="init()">



        <script type="text/javascript" language="javascript">
            var player = null;
            var songs = null;
            var currentAlbumUrl = null;
            var currentStreamUrl = null;
            var startPlayer = false;
            var repeatEnabled = false;
            var slider = null;

            function init() {
                dwr.engine.setErrorHandler(null);
                startTimer();
                if (${model.player.web}) { createPlayer(); } else { getPlaylist(); }
            }

            function startTimer() {
                <!-- Periodically check if the current song has changed. -->
                nowPlayingService.getNowPlayingForCurrentPlayer(nowPlayingCallback);
                setTimeout("startTimer()", 10000);
            }

            function nowPlayingCallback(nowPlayingInfo) {
                if (nowPlayingInfo != null && nowPlayingInfo.streamUrl != currentStreamUrl) {
                    getPlaylist();
                    if (currentAlbumUrl != nowPlayingInfo.albumUrl && top.main.updateNowPlaying) {
                        top.main.location.replace("nowPlaying.view?");
                        currentAlbumUrl = nowPlayingInfo.albumUrl;
                    }
                   if (${not model.player.web}) {
                        currentStreamUrl = nowPlayingInfo.streamUrl;
                        updateCurrentImage();
                   }
                }
            }

            function createPlayer() {
                var flashvars = {
                    backcolor:"<spring:theme code='backgroundColor'/>",
                    frontcolor:"<spring:theme code='textColor'/>",
                    plugins:"backstroke-1,subeq-1&subeq.gain=2&subeq.displaymode=decay&subeq.barbasecolor=<spring:theme code='barbasecolor'/>",
                    id:"player1"
                };
                var params = {
                    allowfullscreen:"true",
                    allowscriptaccess:"always"
                };
                var attributes = {
                    id:"player1",
                    name:"player1"
                };
                swfobject.embedSWF("<c:url value="/flash/jw-player-5.8.swf"/>", "placeholder", "340", "24", "9", false, flashvars, params, attributes);
            }

            function playerReady(thePlayer) {
                player = $("player1");
                player.addModelListener("STATE", "stateListener");
                getPlaylist();
            }

            function stateListener(obj) { // IDLE, BUFFERING, PLAYING, PAUSED, COMPLETED
                if (obj.newstate == "COMPLETED") {
                    onNext(repeatEnabled);
                }
            }

            function getPlaylist() {
                playlistService.getPlaylist(playlistCallback);
            }

            function onClear() {
                var ok = true;
                if (${model.partyMode}) {
                    ok = confirm("<fmt:message key="playlist.confirmclear"/>");
                }
                if (ok) {
                    playlistService.clear(playlistCallback);
                }
            }
            function onStart() {
                playlistService.start(playlistCallback);
            }
            function onStop() {
                playlistService.stop(playlistCallback);
            }
            function onGain(gain) {
                playlistService.setGain(gain);
            }
            function onSkip(index) {
                if (${model.player.web}) {
                    skip(index);
                } else {
                    currentStreamUrl = songs[index].streamUrl;
                    playlistService.skip(index, playlistCallback);
                }
            }
            function onNext(wrap) {
                var index = parseInt(getCurrentSongIndex()) + 1;
                if (wrap) {
                    index = index % songs.length;
                }
                skip(index);
            }
            function onPrevious() {
                skip(parseInt(getCurrentSongIndex()) - 1);
            }
            function onPlay(path) {
                startPlayer = true;
                playlistService.play(path, playlistCallback);
            }
            function onPlayRandom(path, count) {
                startPlayer = true;
                playlistService.playRandom(path, count, playlistCallback);
            }
            function onAdd(path) {
                startPlayer = false;
                playlistService.add(path, playlistCallback);
            }
            function onShuffle() {
                playlistService.shuffle(playlistCallback);
            }
            function onRemove(index) {
                playlistService.remove(index, playlistCallback);
            }
            function onRemoveSelected() {
                var indexes = new Array();
                var counter = 0;
                for (var i = 0; i < songs.length; i++) {
                    var index = i + 1;
                    if ($("songIndex" + index).checked) {
                        indexes[counter++] = i;
                    }
                }
                playlistService.removeMany(indexes, playlistCallback);
            }

            function onUp(index) {
                playlistService.up(index, playlistCallback);
            }
            function onDown(index) {
                playlistService.down(index, playlistCallback);
            }
            function onToggleRepeat() {
                playlistService.toggleRepeat(playlistCallback);
            }
            function onUndo() {
                playlistService.undo(playlistCallback);
            }
            
            function onSortBy(id) {
                switch(sort) {
                    case 0: playlistService.sortByTrack(playlistCallback); break;
                    case 1: playlistService.sortByArtist(playlistCallback); break;
                    case 2: playlistService.sortByAlbum(playlistCallback); break;
                    default:
                }
            }

            function playlistCallback(playlist) {
                songs = playlist.entries;
                repeatEnabled = playlist.repeatEnabled;

                if ($("start")) {
                    if (playlist.stopEnabled) {
                        $("start").hide();
                        $("stop").show();
                    } else {
                        $("start").show();
                        $("stop").hide();
                    }
                }

                if ($("toggleRepeat")) {
                    var text = repeatEnabled ? "<fmt:message key='playlist.repeat_on'/>" : "<fmt:message key='playlist.repeat_off'/>";
                    dwr.util.setValue("toggleRepeat", text);
                }

                if (songs.length == 0) {
                    $("empty").show();
                } else {
                    $("empty").hide();
                }

                // Delete all the rows except for the "pattern" row
                dwr.util.removeAllRows("playlistBody", { filter:function(tr) {
                    return (tr.id != "pattern");
                }});

                // Create a new set cloned from the pattern row
                for (var i = 0; i < songs.length; i++) {
                    var song  = songs[i];
                    var id = i + 1;
                    dwr.util.cloneNode("pattern", { idSuffix:id });
                    if ($("trackNumber" + id)) {
                        dwr.util.setValue("trackNumber" + id, song.trackNumber);
                    }

                    if ($("currentImage" + id) && song.streamUrl == currentStreamUrl) {
                        $("currentImage" + id).show();
                    }
                    if ($("title" + id)) {
                        dwr.util.setValue("title" + id, truncate(song.title));
                        $("title" + id).title = song.title;
                    }
                    if ($("titleUrl" + id)) {
                        dwr.util.setValue("titleUrl" + id, truncate(song.title));
                        $("titleUrl" + id).title = song.title;
                        $("titleUrl" + id).onclick = function () {onSkip(this.id.substring(8) - 1)};
                    }
                    if ($("album" + id)) {
                        dwr.util.setValue("album" + id, truncate(song.album));
                        $("album" + id).title = song.album;
                        $("albumUrl" + id).href = song.albumUrl;
                    }
                    if ($("artist" + id)) {
                        dwr.util.setValue("artist" + id, truncate(song.artist));
                        $("artist" + id).title = song.artist;
                    }
                    if ($("genre" + id)) {
                        dwr.util.setValue("genre" + id, song.genre);
                    }
                    if ($("year" + id)) {
                        dwr.util.setValue("year" + id, song.year);
                    }
                    if ($("bitRate" + id)) {
                        dwr.util.setValue("bitRate" + id, song.bitRate);
                    }
                    if ($("duration" + id)) {
                        dwr.util.setValue("duration" + id, song.durationAsString);
                    }
                    if ($("format" + id)) {
                        dwr.util.setValue("format" + id, song.format);
                    }
                    if ($("fileSize" + id)) {
                        dwr.util.setValue("fileSize" + id, song.fileSize);
                    }

                    $("pattern" + id).show();
                    $("pattern" + id).className = (i % 2 == 0) ? "bgcolor1 loadedlist1" : "bgcolor2 loadedlist2";
                }

                if (playlist.sendM3U) {
                    parent.frames.main.location.href="play.m3u?";
                }

                if (slider) {
                    slider.setValue(playlist.gain * 100);
                }

                if (${model.player.web}) {
                    triggerPlayer();
                }
            }

            function triggerPlayer() {
                if (startPlayer) {
                    startPlayer = false;
                    if (songs.length > 0) {
                        skip(0);
                    }
                }
                updateCurrentImage();
                if (songs.length == 0) {
                    player.sendEvent("LOAD", new Array());
                    player.sendEvent("STOP");
                }
            }

            function skip(index) {
                if (index < 0 || index >= songs.length) {
                    return;
                }

                var song = songs[index];
                currentStreamUrl = song.streamUrl;
                updateCurrentImage();
                var list = new Array();
                list[0] = {
                    file:song.streamUrl,
                    title:song.title,
                    provider:"sound"
                };

                if (song.duration != null) {
                    list[0].duration = song.duration;
                }
                if (song.format == "aac" || song.format == "m4a") {
                    list[0].provider = "video";
                }

                player.sendEvent("LOAD", list);
                player.sendEvent("PLAY");
            }

            function updateCurrentImage() {
                for (var i = 0; i < songs.length; i++) {
                    var song  = songs[i];
                    var id = i + 1;
                    var image = $("currentImage" + id);

                    if (image) {
                        if (song.streamUrl == currentStreamUrl) {
                            image.show();
                        } else {
                            image.hide();
                        }
                    }
                }
            }

            function getCurrentSongIndex() {
                for (var i = 0; i < songs.length; i++) {
                    if (songs[i].streamUrl == currentStreamUrl) {
                        return i;
                    }
                }
                return -1;
            }

            function truncate(s) {
                var cutoff = ${model.visibility.captionCutoff};

                if (s.length > cutoff) {
                    return s.substring(0, cutoff) + "...";
                }
                return s;
            }

            <!-- actionSelected() is invoked when the users selects from the "More actions..." combo box. -->
            function actionSelected(id) {
                switch (id) {
                    case "top": return;
                    case "loadPlaylist":        parent.frames.main.location.href = "loadPlaylist.view?"; break;
                    case "savePlaylist":        parent.frames.main.location.href = "savePlaylist.view?"; break;
                    case "downloadPlaylist":    location.href = "download.view?player=${model.player.id}"; break;
                    case "sharePlaylist":       parent.frames.main.location.href = "createShare.view?player=${model.player.id}&" + getSelectedIndexes(); break;
                    case "sortByTrack":         onSortBy(0); break;
                    case "sortByArtist":        onSortBy(1); break;
                    case "sortByAlbum":         onSortBy(2); break;
                    case "selectAll":           selectAll(true); break;
                    case "selectNone":          selectAll(false); break;
                    case "removeSelected":      onRemoveSelected(); break;
                    case "download":            location.href = "download.view?player=${model.player.id}&" + getSelectedIndexes(); break;
                    case "appendPlaylist":      parent.frames.main.location.href = "appendPlaylist.view?player=${model.player.id}&" + getSelectedIndexes(); break;
                    default:
                }
                $("moreActions").selectedIndex = 0;
            }

            function getSelectedIndexes() {
                var result = "";
                for (var i = 0; i < songs.length; i++) {
                    if ($("songIndex" + (i + 1)).checked) {
                        result += "i=" + i + "&";
                    }
                }
                return result;
            }

            function selectAll(b) {
                for (var i = 0; i < songs.length; i++) {
                    $("songIndex" + (i + 1)).checked = b;
                }
            }
        </script>

        <div id="playlistframecontainer">
            <div id="playlistframemenucontainer" class="bgcolor2">
                <div id="playlistframemenupanel">
                    <div id="mypanel" class="ddpanel">
                        <div id="mypanelcontent" class="ddpanelcontent">
                            <div id="ddpanelcontainer">
                                <c:if test="${model.user.settingsRole}">
                                    <select id="playerSelect" onChange="location='playlist.view?player=' + options[selectedIndex].value;">
                                        <c:forEach items="${model.players}" var="player">
                                        <option ${player.id eq model.player.id ? "selected" : ""} value="${player.id}">${player.shortDescription}</option>
                                        </c:forEach>
                                    </select>
                                    <select id="moreActions" onChange="actionSelected(this.options[selectedIndex].id)">
                                        <option id="top" selected="selected"><fmt:message key="playlist.more"/></option>
                                        <option style="color:blue;"><fmt:message key="playlist.more.playlist"/></option>
                                        <option id="loadPlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.load"/></option>
                                        <c:if test="${model.user.playlistRole}">
                                            <option id="savePlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.save"/></option>
                                        </c:if>
                                        <c:if test="${model.user.downloadRole}">
                                            <option id="downloadPlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="common.download"/></option>
                                        </c:if>
                                        <c:if test="${model.user.shareRole}">
                                            <option id="sharePlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="main.more.share"/></option>
                                        </c:if>
                                        <option id="sortByTrack">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.sortbytrack"/></option>
                                        <option id="sortByAlbum">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.sortbyalbum"/></option>
                                        <option id="sortByArtist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.sortbyartist"/></option>
                                        <option style="color:blue;"><fmt:message key="playlist.more.selection"/></option>
                                        <option id="selectAll">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.selectall"/></option>
                                        <option id="selectNone">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.selectnone"/></option>
                                        <option id="removeSelected">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.remove"/></option>
                                        <c:if test="${model.user.downloadRole}">
                                            <option id="download">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="common.download"/></option>
                                        </c:if>
                                        <c:if test="${model.user.playlistRole}">
                                            <option id="appendPlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.append"/></option>
                                        </c:if>
                                    </select>
                                </c:if>

                                <div class="solidblockmenu-outer right">
                                    <div class="playerleftround left"></div>
                                    <div class="playerrightround right"></div>
                                    <ul class="solidblockmenu"> 
                                        <c:if test="${model.user.settingsRole}">
                                        <li><a href="playerSettings.view?id=${model.player.id}" target="main" class="playersettings" title="<fmt:message key="playlist.settings"/>"><fmt:message key="playlist.settings"/></a></li>
                                        </c:if>
                                        <c:if test="${model.user.downloadRole}">
                                        <li><a href="javascript:noop()" onClick="javascript:actionSelected(this.id)" id="downloadPlaylist" class="playerdownload" title="<fmt:message key="common.download"/>"><fmt:message key="common.download"/></a></li>
                                        </c:if>
                                        <c:if test="${model.user.shareRole}">
                                        <li><a href="javascript:noop()" onClick="javascript:actionSelected(this.id)" id="sharePlaylist" class="playershare" title="<fmt:message key="main.more.share"/>"><fmt:message key="main.more.share"/></a></li>
                                        </c:if>            
                                        <li><a href="javascript:noop()" onClick="javascript:actionSelected(this.id)" id="appendPlaylist" class="playerappend" title="<fmt:message key="playlist.append"/>"><fmt:message key="playlist.append"/></a></li>   
                                        <li><a href="javascript:noop()" onClick="javascript:onRemoveSelected();" class="playerremove" title="<fmt:message key="playlist.remove"/>"><fmt:message key="playlist.remove"/></a></li>
                                        <li><a href="savePlaylist.view?" target="main" class="playersave" title="<fmt:message key="playlist.save"/>"><fmt:message key="playlist.save"/></a></li>
                                        <li><a href="loadPlaylist.view?" target="main" class="playerload" title="<fmt:message key="playlist.load"/>"><fmt:message key="playlist.load"/></a></li>
                                        <li><span id="togglecontent2-title" class="handcursor"></span>
                                        <div id="togglecontent2" class="switchgroup2"></div>
                                            <script type="text/javascript">
                                                var toggle2img=new switchcontent("switchgroup2", "div") //Limit scanning of switch contents to just "div" elements
                                                toggle2img.setStatus('<a href="javascript:noop()" onClick="javascript:selectAll(false)" class="playerselectall" title="<fmt:message key="playlist.more.selectnone"/>"/> ', '<a href="javascript:noop()" onClick="javascript:selectAll(true)" class="playerselectnone" title="<fmt:message key="playlist.more.selectall"/>"/> ')
                                                toggle2img.setPersist(true)
                                                toggle2img.collapsePrevious(true) //Only one content open at any given time
                                                toggle2img.init()
                                            </script>
                                        </a></li>
                                    </ul>
                                </div>
                            </div> 
                        </div>
                        <div id="mypaneltab" class="ddpaneltab">
                            <a href="#"><span>Advanced</span></a>
                        </div>
                    </div>

                    <div id="playlistframemenuplayer<c:choose><c:when test='${model.player.external}'>External</c:when><c:when test='${model.player.jukebox}'>Jukebox</c:when><c:otherwise></c:otherwise></c:choose>" class="solidblockmenu-outer">
                        <div class="playerleftround left"></div>
                        <div class="playerrightround right"></div>

                        <ul class="solidblockmenu left">
                            <li>
                                <select id="sortorder" onChange="javascript:onSortBy(selectedIndex);"> 
                                    <option value="<fmt:message key='playlist.more.sortbytrack'/>"><fmt:message key='playlist.more.sortbytrack'/></option> 
                                    <option value="<fmt:message key='playlist.more.sortbyartist'/>"><fmt:message key='playlist.more.sortbyartist'/></option>
                                    <option value="<fmt:message key='playlist.more.sortbyalbum'/>"><fmt:message key='playlist.more.sortbyalbum'/></option>
                                </select>
                            </li>
                             
                            <c:if test="${model.player.web or model.player.jukebox or model.player.external}">
                            <li><span id="togglecontent1-title" class="handcursor"></span>
                                <div id="togglecontent1" class="switchgroup1"></div>
                                <script type="text/javascript">
                                // MAIN FUNCTION: new switchcontent("class name", "[optional_element_type_to_scan_for]") REQUIRED
                                // Call Instance.init() at the very end. REQUIRED
                                    
                                var toggle1img=new switchcontent("switchgroup1", "div") //Limit scanning of switch contents to just "div" elements
                                toggle1img.setStatus('<a href="javascript:noop()" onClick="onToggleRepeat()" class="playerrepeaton" title="<fmt:message key="playlist.repeat_on"/>"/> ', '<a href="javascript:noop()" onClick="onToggleRepeat()" class="playerrepeatoff" title="<fmt:message key="playlist.repeat_off"/>"/> ')
                                toggle1img.setPersist(true)
                                toggle1img.collapsePrevious(true) //Only one content open at any given time
                                toggle1img.init()
                                </script>
                                </a>
                            </li>
                            </c:if> 
                            <li><a href="javascript:noop()" onClick="onUndo()" class="playerundo" title="<fmt:message key="playlist.undo"/>"><fmt:message key="playlist.undo"/></a></li>
                            <li><a href="javascript:noop()" onClick="onShuffle()" class="playershuffle" title="<fmt:message key="playlist.shuffle"/>"><fmt:message key="playlist.shuffle"/></a></li>
                            <li><a href="javascript:noop()" onClick="onClear()" class="playerclear" title="<fmt:message key="playlist.clear"/>"><fmt:message key="playlist.clear"/></a></li>
                            
                            <c:if test="${model.player.web}">
                            <li><a href="javascript:noop()" onClick="onNext(false)" class="playerforward" title="Forward">Forward</a></li>
                            <li><a href="javascript:noop()" onClick="onPrevious()" class="playerrewind" title="Rewind">Rewind</a></li>
                            </c:if>
                             
                            <c:if test="${model.user.streamRole and not model.player.web}">
                            <li><a href="javascript:noop()" onClick="onStop()" class="playerstop" ><fmt:message key="playlist.stop"/></a></li>
                            <li><a href="javascript:noop()" onClick="onStart()" class="playerstart" ><fmt:message key="playlist.start"/></a></li>
                            </c:if> 
                            <c:if test="${model.player.web}">
                            <li><div id="placeholder" style="float:left;width:340px;margin-top:5px"><a href="http://www.adobe.com/go/getflashplayer" target="_blank"><fmt:message key="playlist.getflash"/></a></div></li>
                            </c:if> 
                       
                            <c:if test="${model.player.jukebox}">
                            <li><div class="slider" id="slider-1" style="width:90px;float:left;">
                                <input class="slider-input" id="slider-input-1" name="slider-input-1">
                                </div></li>
                                <script type="text/javascript">

                                    var updateGainTimeoutId = 0;
                                    slider = new Slider(document.getElementById("slider-1"), document.getElementById("slider-input-1"));
                                    slider.onchange = function () {
                                        clearTimeout(updateGainTimeoutId);
                                        updateGainTimeoutId = setTimeout("updateGain()", 250);
                                    };

                                    function updateGain() {
                                         var gain = slider.getValue() / 100.0;
                                         onGain(gain);
                                    }
                                </script>
                            <li><img style="float:left; margin-top:4px; margin-left:3px;" src="<spring:theme code="volumeImage"/>" alt=""></li>
                            </c:if>
                        </ul>
                    </div>
                </div>
            </div>

                <div id="playlistcontainer">
                    <div id="playlistcontent">
                        <p id="empty"><em><fmt:message key="playlist.empty"/></em></p>
                        <div id="text">
                            <table border="0" cellspacing="10" cellpadding="0" width="100%">
                              <tr>
                                <td width="100%"><table style="border-collapse:collapse;white-space:nowrap;width:100%">
                                <tbody id="playlistBody">
                                    <tr id="pattern" style="display:none;margin:0;padding:0;border:0">
                                        <td class="bgcolor2 loadedlist2"><a href="javascript:noop()">
                                            <img id="removeSong" onClick="onRemove(this.id.substring(10) - 1)" src="<spring:theme code="removeImage"/>"
                                                 alt="<fmt:message key="playlist.remove"/>" title="<fmt:message key="playlist.remove"/>">&nbsp;</a></td>
                                        <td class="bgcolor2 loadedlist2"><a href="javascript:noop()">
                                            <img id="up" onClick="onUp(this.id.substring(2) - 1)" src="<spring:theme code="upImage"/>"
                                                 alt="<fmt:message key="playlist.up"/>" title="<fmt:message key="playlist.up"/>">&nbsp;</a></td>
                                        <td class="bgcolor2 loadedlist2"><a href="javascript:noop()">
                                            <img id="down" onClick="onDown(this.id.substring(4) - 1)" src="<spring:theme code="downImage"/>"
                                                 alt="<fmt:message key="playlist.down"/>" title="<fmt:message key="playlist.down"/>">&nbsp;</a></td>

                                        <td class="bgcolor2 loadedlist2" style="padding-left: 0.1em"><input type="checkbox" class="checkbox" id="songIndex"></td>
                                        <td style="padding-right:0.25em"></td>

                                        <c:if test="${model.visibility.trackNumberVisible}">
                                            <td style="padding-right:0.5em;text-align:right"><span class="detail" id="trackNumber">1</span></td>
                                        </c:if>

                                        <td style="padding-right:1.25em">
                                            <img id="currentImage" src="<spring:theme code="currentImage"/>" alt="" style="display:none">
                                            <c:choose>
                                                <c:when test="${model.player.externalWithPlaylist}">
                                                    <span id="title">Title</span>
                                                </c:when>
                                                <c:otherwise>
                                                    <a id="titleUrl" href="javascript:noop()">Title</a>
                                                </c:otherwise>
                                            </c:choose>
                                        </td>

                                        <c:if test="${model.visibility.albumVisible}">
                                            <td style="padding-right:1.25em"><a id="albumUrl" target="main"><span id="album" class="detail">Album</span></a></td>
                                        </c:if>
                                        <c:if test="${model.visibility.artistVisible}">
                                            <td style="padding-right:1.25em"><span id="artist" class="detail">Artist</span></td>
                                        </c:if>
                                        <c:if test="${model.visibility.genreVisible}">
                                            <td style="padding-right:1.25em"><span id="genre" class="detail">Genre</span></td>
                                        </c:if>
                                        <c:if test="${model.visibility.yearVisible}">
                                            <td style="padding-right:1.25em"><span id="year" class="detail">Year</span></td>
                                        </c:if>
                                        <c:if test="${model.visibility.formatVisible}">
                                            <td style="padding-right:1.25em"><span id="format" class="detail">Format</span></td>
                                        </c:if>
                                        <c:if test="${model.visibility.fileSizeVisible}">
                                            <td style="padding-right:1.25em;text-align:right;"><span id="fileSize" class="detail">Format</span></td>
                                        </c:if>
                                        <c:if test="${model.visibility.durationVisible}">
                                            <td style="padding-right:1.25em;text-align:right;"><span id="duration" class="detail">Duration</span></td>
                                        </c:if>
                                        <c:if test="${model.visibility.bitRateVisible}">
                                            <td style="padding-right:0.25em"><span id="bitRate" class="detail">Bit Rate</span></td>
                                        </c:if>
                                        <!--<td style="padding-right:1.25em"><a href="javascript:song.artist" onClick="javascript:return popupSize(this, 'lyrics', 430, 550)"><fmt:message key="main.lyrics"/></a></span></td>-->
                                    </tr>
                                </tbody>
                                </td></table>
                              </tr>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>
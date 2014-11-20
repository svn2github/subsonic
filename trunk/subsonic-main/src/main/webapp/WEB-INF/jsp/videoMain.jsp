<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="iso-8859-1"%>
<%--
  ~ This file is part of Subsonic.
  ~
  ~  Subsonic is free software: you can redistribute it and/or modify
  ~  it under the terms of the GNU General Public License as published by
  ~  the Free Software Foundation, either version 3 of the License, or
  ~  (at your option) any later version.
  ~
  ~  Subsonic is distributed in the hope that it will be useful,
  ~  but WITHOUT ANY WARRANTY; without even the implied warranty of
  ~  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  ~  GNU General Public License for more details.
  ~
  ~  You should have received a copy of the GNU General Public License
  ~  along with Subsonic.  If not, see <http://www.gnu.org/licenses/>.
  ~
  ~  Copyright 2014 (C) Sindre Mehus
  --%>

<%--@elvariable id="model" type="java.util.Map"--%>

<html><head>
    <%@ include file="head.jsp" %>
    <%@ include file="jquery.jsp" %>

    <script type="text/javascript">
        var image;
        var id;
        var duration;
        var timer;
        var offset;
        var step;
        var size = 120;

        function startPreview(img, id, duration) {
            stopPreview();
            image = $(img);
            step = Math.max(5, Math.round(duration / 50));
            offset = step;
            this.id = id;
            this.duration = duration;
            updatePreview();
            timer = window.setInterval(updatePreview, 1000);
        }

        function updatePreview() {
            image.attr("src", "coverArt.view?id=" + id + "&size=" + size + "&offset=" + offset);
            offset += step;
            if (offset > duration) {
                stopPreview();
            }
        }

        function stopPreview() {
            if (timer != null) {
                window.clearInterval(timer);
                timer = null;
            }
            if (image != null) {
                image.attr("src", "coverArt.view?id=" + id + "&size=" + size);
            }
        }
    </script>

    <style type="text/css">
        .videoContainer {
            width: 213px;
            float: left;
            padding-right: 14px;
            padding-bottom: 10px;
        }
        .duration {
            position: absolute;
            bottom: 3px;
            right: 3px;
            color: #d3d3d3;
            background-color: black;
            opacity: 0.8;
            padding-right:3px;
            padding-left:3px;
        }
        .title {
            width:213px;
            overflow: hidden;
            text-overflow: ellipsis;
            padding-top: 3px;
        }
        .directory {
            width: 213px;
            overflow: hidden;
            text-overflow: ellipsis;
        }
    </style>

</head><body class="mainframe bgcolor1">

<h1 style="padding-bottom: 1em">
    <span style="vertical-align: middle;">
        <c:forEach items="${model.ancestors}" var="ancestor">
            <sub:url value="main.view" var="ancestorUrl">
                <sub:param name="id" value="${ancestor.id}"/>
            </sub:url>
            <a href="${ancestorUrl}">${ancestor.name}</a> &raquo;
        </c:forEach>
        ${model.dir.name}
    </span>
</h1>

<c:forEach items="${model.children}" var="child">
    <c:if test="${child.video}">

        <sub:url value="/videoPlayer.view" var="videoUrl">
            <sub:param name="id" value="${child.id}"/>
        </sub:url>
        <sub:url value="/coverArt.view" var="coverArtUrl">
            <sub:param name="id" value="${child.id}"/>
            <sub:param name="size" value="120"/>
        </sub:url>

        <div class="videoContainer">
            <div style="position:relative">
                <div>
                    <a href="${videoUrl}"><img src="${coverArtUrl}" alt="" class="dropshadow"
                                               onmouseover="startPreview(this, ${child.id}, ${child.durationSeconds})"
                                               onmouseout="stopPreview()"></a>
                </div>
                <div class="detail duration">${child.durationString}</div>
            </div>
            <div class="detail title" title="${child.name}"><b>${child.name}</b></div>
        </div>
    </c:if>

</c:forEach>

<div style="clear:both;padding-top: 1em">
    <c:set var="cssClass" value="directory"/>
    <c:forEach items="${model.children}" var="child" varStatus="loopStatus">
        <c:if test="${child.directory}">
            <c:choose>
                <c:when test="${cssClass eq 'directory'}">
                    <c:set var="cssClass" value="bgcolor2 directory"/>
                </c:when>
                <c:otherwise>
                    <c:set var="cssClass" value="directory"/>
                </c:otherwise>
            </c:choose>
            <sub:url value="main.view" var="childUrl">
                <sub:param name="id" value="${child.id}"/>
            </sub:url>

            <div class="${cssClass}">
                <a href="${childUrl}" title="${child.name}"><span style="white-space:nowrap;">${child.name}</span></a>
            </div>
        </c:if>
    </c:forEach>
</div>

</body>
</html>

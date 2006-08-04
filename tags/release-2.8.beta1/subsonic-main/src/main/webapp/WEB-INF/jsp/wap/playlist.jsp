<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">

<%@ page language="java" contentType="text/vnd.wap.wml; charset=utf-8" pageEncoding="iso-8859-1"%>

<wml>

    <%@ include file="head.jsp" %>

    <c:if test="${fn:length(model.players) eq 1}">
        <c:choose>
            <c:when test="${empty model.players[0].name}">
                <c:set var="playerName" value=" - Player ${model.players[0].id}"/>
            </c:when>
            <c:otherwise>
                <c:set var="playerName" value=" - ${model.players[0].name}"/>
            </c:otherwise>
        </c:choose>
    </c:if>


    <card id="main" title="Subsonic" newcontext="false">
        <p><small><b><fmt:message key="wap.playlist.title"/>${playerName}</b></small></p>
        <p><small>

            <c:choose>
            <c:when test="${empty model.players}">
                <fmt:message key="wap.playlist.noplayer"/>
            </c:when>
                <c:otherwise>
                <b><a href="index.view">[<fmt:message key="common.home"/>]</a></b><br/>
                <b><a href="loadPlaylist.view">[<fmt:message key="wap.playlist.load"/>]</a></b><br/>
                <c:set var="playlist" value="${model.players[0].playlist}"/>

                <c:if test="${not empty playlist.files}">
                <b><a href="playlist.view?clear">[<fmt:message key="wap.playlist.clear"/>]</a></b><br/>
        </small></p>
        <p><small>

            <c:forEach items="${playlist.files}" var="file" varStatus="loopStatus">
                <c:set var="isCurrent" value="${(file eq playlist.currentFile) and (loopStatus.count - 1 eq playlist.index)}"/>
                ${isCurrent ? "<b>" : ""}
                <a href="playlist.view?skip=${loopStatus.count - 1}">${fn:escapeXml(file.title)}</a>
                ${isCurrent ? "</b>" : ""}
                <br/>
            </c:forEach>
            </c:if>
            </c:otherwise>
            </c:choose>
        </small></p>
    </card>
</wml>


<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="iso-8859-1"%>
<%--@elvariable id="command" type="net.sourceforge.subsonic.command.SearchCommand"--%>
<%@ include file="doctype.jsp" %>

<html>
	<head>
		<%@ include file="head.jsp" %>
		<script type="text/javascript" src="<c:url value='/script/scripts.js'/>"></script>
		<script type="text/javascript" src="<c:url value='/script/prototype.js'/>"></script>
		<script type="text/javascript" src="<c:url value='/dwr/util.js'/>"></script>

		<script type="text/javascript">
			function more(rowSelector, moreId) {
				var rows = $$(rowSelector);
				for (var i = 0; i < rows.length; i++) {
					rows[i].show();
				}
				$(moreId).hide();
			}
		</script>

	</head>
	<body class="mainframe bgcolor1">

		<div id="mainframecontainer">

			<div id="mainframecontentcontainer">
				<div id="mainframecontent">
				
				
					<h1>
						<img id="pageimage" src="<spring:theme code="searchImage"/>" alt=""/>
						<span class="desc"><fmt:message key="search.title"/></span>
					</h1>

					<form:form commandName="command" method="post" action="search.view" name="searchForm">
					<table cellpadding="0px" cellspacing="0px" align="right" style="margin-right:20px;" width="400px">
						<tr>
							<td><fmt:message key="search.query"/></td>
							<td style="border-style:solid none solid solid;border-color:#849dbd;border-width:1px;background-color:#FFF">
							<form:input path="query" size="35"/>
							</td>
							<td style="border-style:solid solid solid none;border-color:#849dbd;border-width:1px;" width="24px" align="right">
							<input id="Submit" type="image" onClick="search(0)" src="<spring:theme code="searchImage"/>" alt="${search}" title="${search}" align="absBottom" style="border-style:none" width="18px">
							<!--<a href="javascript:document.searchForm.submit()"><img src="<spring:theme code="searchImage"/>" alt="${search}" title="${search}"></a>-->
							</td>
						</tr>
					</table>
					</form:form>
					</div>

					<br>
					<c:if test="${command.indexBeingCreated}">
						<p class="warning"><fmt:message key="search.index"/></p>
					</c:if>

					<c:if test="${not command.indexBeingCreated and empty command.artists and empty command.albums and empty command.songs}">
						<p class="warning"><fmt:message key="search.hits.none"/></p>
					</c:if>

					<c:if test="${not empty command.artists}">
						<h2><fmt:message key="search.hits.artists"/></h2>
						<table style="border-collapse:collapse">
							<c:forEach items="${command.artists}" var="match" varStatus="loopStatus">

								<sub:url value="/main.view" var="mainUrl">
									<sub:param name="path" value="${match.path}"/>
								</sub:url>

								<tr class="artistRow" ${loopStatus.count > 5 ? "style='display:none'" : ""}>
									<c:import url="playAddDownload.jsp">
										<c:param name="path" value="${match.path}"/>
										<c:param name="playEnabled" value="${command.user.streamRole and not command.partyModeEnabled}"/>
										<c:param name="addEnabled" value="${command.user.streamRole and (not command.partyModeEnabled or not match.directory)}"/>
										<c:param name="downloadEnabled" value="${command.user.downloadRole and not command.partyModeEnabled}"/>
										<c:param name="asTable" value="true"/>
									</c:import>
									<td ${loopStatus.count % 2 == 1 ? "class='bgcolor2'" : ""} style="padding-left:0.25em;padding-right:1.25em">
										<a href="${mainUrl}">${match.name}</a>
									</td>
								</tr>

								</c:forEach>
						</table>
						<c:if test="${fn:length(command.artists) gt 5}">
							<div id="moreArtists" class="forward"><a href="javascript:noop()" onclick="more('tr.artistRow', 'moreArtists')"><fmt:message key="search.hits.more"/></a></div>
						</c:if>
					</c:if>

					<c:if test="${not empty command.albums}">
						<h2><fmt:message key="search.hits.albums"/></h2>
						<table style="border-collapse:collapse">
							<c:forEach items="${command.albums}" var="match" varStatus="loopStatus">

								<sub:url value="/main.view" var="mainUrl">
									<sub:param name="path" value="${match.path}"/>
								</sub:url>

								<tr class="albumRow" ${loopStatus.count > 5 ? "style='display:none'" : ""}>
									<c:import url="playAddDownload.jsp">
										<c:param name="path" value="${match.path}"/>
										<c:param name="playEnabled" value="${command.user.streamRole and not command.partyModeEnabled}"/>
										<c:param name="addEnabled" value="${command.user.streamRole and (not command.partyModeEnabled or not match.directory)}"/>
										<c:param name="downloadEnabled" value="${command.user.downloadRole and not command.partyModeEnabled}"/>
										<c:param name="asTable" value="true"/>
									</c:import>

									<td ${loopStatus.count % 2 == 1 ? "class='bgcolor2'" : ""} style="padding-left:0.25em;padding-right:1.25em">
										<a href="${mainUrl}">${match.firstChild.metaData.album}</a>
									</td>

									<td ${loopStatus.count % 2 == 1 ? "class='bgcolor2'" : ""} style="padding-right:0.25em">
										<span class="detail">${match.firstChild.metaData.artist}</span>
									</td>
								</tr>

								</c:forEach>
						</table>
						<c:if test="${fn:length(command.albums) gt 5}">
							<div id="moreAlbums" class="forward"><a href="javascript:noop()" onclick="more('tr.albumRow', 'moreAlbums')"><fmt:message key="search.hits.more"/></a></div>
						</c:if>
					</c:if>


					<c:if test="${not empty command.songs}">
						<h2><fmt:message key="search.hits.songs"/></h2>
						<table style="border-collapse:collapse">
							<c:forEach items="${command.songs}" var="match" varStatus="loopStatus">

								<sub:url value="/main.view" var="mainUrl">
									<sub:param name="path" value="${match.parent.path}"/>
								</sub:url>

								<tr class="songRow" ${loopStatus.count > 15 ? "style='display:none'" : ""}>
									<c:import url="playAddDownload.jsp">
										<c:param name="path" value="${match.path}"/>
										<c:param name="playEnabled" value="${command.user.streamRole and not command.partyModeEnabled}"/>
										<c:param name="addEnabled" value="${command.user.streamRole and (not command.partyModeEnabled or not match.directory)}"/>
										<c:param name="downloadEnabled" value="${command.user.downloadRole and not command.partyModeEnabled}"/>
										<c:param name="video" value="${match.video and command.player.web}"/>
										<c:param name="asTable" value="true"/>
									</c:import>

									<td ${loopStatus.count % 2 == 1 ? "class='bgcolor2'" : ""} style="padding-left:0.25em;padding-right:1.25em">
											${match.metaData.title}
									</td>

									<td ${loopStatus.count % 2 == 1 ? "class='bgcolor2'" : ""} style="padding-right:1.25em">
										<a href="${mainUrl}"><span class="detail">${match.metaData.album}</span></a>
									</td>

									<td ${loopStatus.count % 2 == 1 ? "class='bgcolor2'" : ""} style="padding-right:0.25em">
										<span class="detail">${match.metaData.artist}</span>
									</td>
								</tr>

								</c:forEach>
						</table>
					<c:if test="${fn:length(command.songs) gt 15}">
						<div id="moreSongs" class="forward"><a href="javascript:noop()" onclick="more('tr.songRow', 'moreSongs')"><fmt:message key="search.hits.more"/></a></div>
					</c:if>
					</c:if>

				</div>
			</div>
		</div>
	</body>
</html>
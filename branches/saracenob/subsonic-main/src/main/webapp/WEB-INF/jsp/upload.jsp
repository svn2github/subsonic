<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="iso-8859-1" %>
<%@ include file="doctype.jsp" %>

<html>
    <head>
        <%@ include file="head.jsp" %>
        <style type="text/css">
            #progressBar {width: 350px; height: 10px; border: 1px solid black; display:none;}
            #progressBarContent {width: 0; height: 10px; background: url("<c:url value="/icons/progress.png"/>") repeat;}
        </style>
        <script type="text/javascript" src="<c:url value="/dwr/interface/transferService.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/dwr/engine.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/upload.js"/>"></script>
    </head>
    <body class="mainframe bgcolor1">

        <%@ include file="uploadForm.jsp" %>

        <div id="mainframecontainer" class="fillframe">
            <div id="mainframemenucontainer" class="bgcolor1 fade vcenterouter fillwidth">
                <span id="mainframemenuleft" class="vcenterinner">
                    <button class="ui-icon-triangle-1-w ui-icon-primary vcenter" onClick="location.href='more.view?'"><fmt:message key="common.back"/></button>
                </span>
                <span id="mainframemenucenter" class="vcenterinner">
                    <button class="ui-icon-arrowthickstop-1-n ui-icon-primary vcenter" onClick="toggleUploadFile()"><fmt:message key="upload.uploadfile"/></button>
                </span>
            </div>

            <div id="mainframecontentcontainer">
                <div id="mainframecontent">

                    <h1><fmt:message key="upload.title"/></h1>
                    <blockquote>
                        <c:forEach items="${model.uploadedFiles}" var="file">
                            <p><fmt:message key="upload.success"><fmt:param value="${file.path}"/></fmt:message></p>
                        </c:forEach>

                        <c:forEach items="${model.unzippedFiles}" var="file">
                            <fmt:message key="upload.unzipped"><fmt:param value="${file.path}"/></fmt:message><br/>
                        </c:forEach>

                        <c:choose>
                            <c:when test="${not empty model.exception}">
                                <p><fmt:message key="upload.failed"><fmt:param value="${model.exception.message}"/></fmt:message></p>
                            </c:when>
                            <c:when test="${empty model.uploadedFiles}">
                                <p><fmt:message key="upload.empty"/></p>
                            </c:when>
                        </c:choose>
                    </blockquote>
                </div>
            </div>
        </div>
    </body>
    <script type="text/javascript">
        jQueryLoad.wait(function() {
            $("#uploadnext").click(function(e) { e.preventDefault(); });
            $("#uploadback").click(function(e) { e.preventDefault(); });
            jQueryUILoad.wait(function() {
                $("#uploadFileForm").validation().stylize();
                $("#mainframemenucontainer").stylize();
            });
        });
    </script>
</html>

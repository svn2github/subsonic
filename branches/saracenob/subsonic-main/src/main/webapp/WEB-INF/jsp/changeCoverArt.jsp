<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="iso-8859-1" %>
<%@ include file="doctype.jsp" %>
<% 
    int imagesPerPage = 8;
    int imagesPerRow = 4;
    pageContext.setAttribute("imagesPerPage", imagesPerPage); 
    pageContext.setAttribute("imagesPerRow", imagesPerRow); 
%>

<html>
    <head>
        <%@ include file="head.jsp" %>
        <script type="text/javascript" src="<c:url value="/dwr/engine.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/dwr/util.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/dwr/interface/coverArtService.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/scripts.js"/>"></script>

        <script type="text/javascript" src="<c:url value="/script/fancyzoom/FancyZoom.js"/>"></script>
        <script type="text/javascript" src="<c:url value="/script/fancyzoom/FancyZoomHTML.js"/>"></script>

        <script type="text/javascript" src="http://www.google.com/jsapi"></script>
        <script type="text/javascript" language="javascript">

            var imageSearch;
            dwr.engine.setErrorHandler(null);
            google.load('search', '1');
            google.setOnLoadCallback(onLoad);

            function onLoad() {
                imageSearch = new google.search.ImageSearch();
                imageSearch.setSearchCompleteCallback(this, searchComplete, null);
                imageSearch.setNoHtmlGeneration();
                imageSearch.setResultSetSize(${imagesPerPage});
                google.search.Search.getBranding("branding");
                doSearch();
            }

            function doSearch() {
                $("#wait").show();
                $("#success").hide();
                $("#error").hide();
                $("#errorDetails").hide();
                $("#noImagesFound").hide();
                $("#imagesearchresults").hide();
                var query = dwr.util.getValue("query");
                imageSearch.execute(query);
            }

            function searchComplete() {

                $("#wait").hide();

                if (imageSearch.results && imageSearch.results.length > 0) {
                    var images = $("#images")[0];
                    images.innerHTML = "";
                    $("#imagesearchresultcontainer").css({ "maxWidth" : 240 * (imageSearch.results.length / 2) + "px" });
                    setupZoom('<c:url value="/"/>');

                    $("#imagesearchresults").show();
                    var results = imageSearch.results;
                    for (var i = 0; i < results.length; i++) {
                        var result = results[i];
                        var node = $("#coverarttemplate").clone();
                        var zoomlink = node.find(".search-result-thumbnail-zoom")[0];
                        zoomlink.href = result.url;

                        var thumbnail = node.find(".search-result-thumbnail")[0];
                        thumbnail.src = result.tbUrl;

                        var setlink = node.find(".search-result-setimage")[0];
                        setlink.href = "javascript:setImage('" + result.url + "');";

                        var title = node.find(".search-result-title")[0];
                        title.innerHTML = result.contentNoFormatting;

                        var dimension = node.find(".search-result-dimension")[0];
                        dimension.innerHTML = result.width + " &#215; " + result.height;

                        var url = node.find(".search-result-url")[0];
                        url.innerHTML = result.visibleUrl;

                        $('#images').append(node).end();
                        $(node).css({ 'visibility' : 'visible', "display" : "none" });
                        $(node).delay(30).fadeIn(600);
                    }
                    prepZooms();
                    addPaginationLinks();
                } else {
                    $("#noImagesFound").show();
                }
            }

            function addPaginationLinks() {
                // To paginate search results, use the cursor function.
                var cursor = imageSearch.cursor;
                var curPage = cursor.currentPageIndex; // check what page the app is on
                var pagesDiv = document.createElement("span");
                pagesDiv.className = "imageResultPages";

                // Create link to prev page.
                var prev = document.createElement("a");
                prev.href = (curPage > 0) ? "javascript:imageSearch.gotoPage(" + (curPage - 1) + ");" : "#";
                prev.innerHTML = "<fmt:message key='common.previous'/>";
                prev.style.marginRight = "0.5em";
                prev.className = "back"
                $(prev).appendTo(pagesDiv);
                
                for (var i = 0; i < cursor.pages.length; i++) {
                    var page = cursor.pages[i];
                    var label;
                    label = (curPage == i) ? document.createElement("b") : document.createElement("a");
                    if (curPage != i) { label.href = "javascript:imageSearch.gotoPage(" + i + ");"; }
                    label.style.width = "1em";
                    label.innerHTML = page.label;
                    label.style.padding = (curPage == i) ? "0.3em" : "0.2em";
                    label.style.paddingTop = "0.2em";
                    label.style.marginRight = "0.5em";
                    $(label).appendTo(pagesDiv);
                }

                // Create link to next page.
                var next = document.createElement("a");
                next.href = (curPage < cursor.pages.length - 1) ? "javascript:imageSearch.gotoPage(" + (curPage + 1) + ");" : "#";
                next.innerHTML = "<fmt:message key='common.next'/>";
                next.style.marginLeft = "0.5em";
                next.className = "forward"
                $(next).appendTo(pagesDiv);

                var pages = $("#pages")[0];
                pages.innerHTML = "";
                $(pagesDiv).appendTo(pages);
            }

            function setImage(imageUrl) {
                $("#wait").show();
                $("#success").hide();
                $("#error").hide();
                $("#errorDetails").hide();
                $("#noImagesFound").hide();
                $("#pages").hide();
                $("#backlink").hide();
                $("#addFromURILink").hide();
                $("#imagesearchresults").hide();
                var path = dwr.util.getValue("path");
                coverArtService.setCoverArtImage(path, imageUrl, setImageComplete);
            }

            function setImageComplete(errorDetails) {
                $("#wait").hide();
                if (errorDetails != null) {
                    dwr.util.setValue("errorDetails", "<br/>" + errorDetails, { escapeHtml:false });
                    $("#error").show();
                    $("#errorDetails").show();
                    $("#pages").show();
                    $("#addFromURILink").show();
                } else {
                    $("#success").show();
                    $("#backlink").show();
                    $("#backlink").innerHTML = "Back"
                }
            }
        </script>
        <script type="text/javascript">
            function toggleAddFromURI() {
                $("#addCoverArtFormContainer").toggle("blind");
            }
            
            function verifyImageURI() {
                var uri = document.addFromURIForm.url.value 
                var regexp = /(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/;

                // Check for null value
                if (uri == "") {
                    return false;
                }
                // Check for valid URI
                if (regexp.test(uri) == false) {
                    return false;
                }
                
                // Checks passed: submit
                document.addFromURIForm.submit();
                $("#addCoverArtFormContainer").toggle();
            }
        </script>

        <style type="text/css">
            /*Google powered by branding*/
            td.gsc-branding-text div.gsc-branding-text, td.gcsc-branding-text div.gcsc-branding-text { display: none; }
            td.gsc-branding-img-noclear, td.gcsc-branding-img-noclear { display: none; }
        </style>
    </head>
    <body class="mainframe bgcolor1">

        <div id="addCoverArtFormContainer" class="bgcolor1" style="display:none">
            <div style="width:50%;margin:2px auto;">
                <form name="addCoverArtForm" method="post" action="javascript:setImage(dwr.util.getValue('url'))">
                    <input id="path" type="hidden" name="path" value="${model.path}"/>
                    <table>
                        <tr>
                            <td><label for="url"><fmt:message key="changecoverart.address"/></label></td>
                            <td><input type="text" name="url" value="" style="width:30em" onclick="select()"/></td>
                            <td><input type="button" value="<fmt:message key='common.ok'/>" onClick="verifyImageURI()"/></td>
                            <td><input type="reset" value="<fmt:message key='common.cancel'/>" onClick="toggleAddFromURI()"/></td>
                        </tr>
                    </table>
                </form>
            </div>
        </div>

        <div id="mainframecontainer">
            <div id="mainframemenucontainer" class="bgcolor1 fade">
                <span id="mainframemenuleft">
                    <sub:url value="main.view" var="backUrl"><sub:param name="path" value="${model.path}"/></sub:url>
                    <span class="back cancel"><a href="${backUrl}" id="backlink"><fmt:message key="common.cancel"/></a></span>
                </span>
                <span id="mainframemenucenter">
                    <span id="addFromURILink" class="mainframemenuitem addFromURI" style="background-image: url(<spring:theme code='addImage'/>)"><a href="#" onClick="toggleAddFromURI()"><fmt:message key="changecoverart.addfromuri"/></a></span>
                </span>
                <span id="mainframemenucenter">
                    <div class="pagination">
                        <span id="pages"></span>
                    </div>
                </span>
                <span id="mainframemenuright">
                    <span class="right">
                        <!-- TODO Add ability to choose cover art search provider.
                        <select name="imageSearchProvider" id="imageSearchProvider" onChange="" disabled="disabled">
                            <option value="google" selected><fmt:message key="changecoverart.search"/></option>
                        </select>
                        -->
                        <form name="searchForm" id="searchForm" method="post" action="javascript:doSearch()">
                            <table bgcolor="#ffffff" cellpadding="0px" cellspacing="0px" align="right" width="300px" style="margin-top:1px">
                                <tr>
                                    <td style="border-style:solid none solid solid;border-color:#849dbd;border-width:1px;">
                                        <input class="searchboxquery" type="text" name="query" id="query" onClick="select();" value="<str:capitalize>${model.artist} ${model.album}</str:capitalize>"
                                            onFocus="if(this.value=='<str:capitalize>${model.artist} ${model.album}</str:capitalize>'){this.value='';this.style.color='#000';}else{this.select();}"
                                            onBlur="if(this.value==''){this.value='<str:capitalize>${model.artist} ${model.album}</str:capitalize>';this.style.color='b3b3b3';}">
                                    </td>
                                    <td style="border-style:solid solid solid none;border-color:#849dbd;border-width:1px;" width="24px" align="right">
                                        <input id="Submit" type="image" src="<spring:theme code='searchImage'/>" alt="${search}" title="${search}" align="absBottom" style="border-style:none" width="18px">
                                    </td>
                                </tr>
                            </table>
                        </form>
                    </span>
                </span>
            </div>

            <div id="mainframecontentcontainer">
                <div id="mainframecontent">

                    <h1><fmt:message key="changecoverart.title"/></h1>

                    <h2 id="wait" style="display:none"><fmt:message key="changecoverart.wait"/></h2>
                    <h2 id="noImagesFound" style="display:none"><fmt:message key="changecoverart.noimagesfound"/></h2>
                    <h2 id="success" style="display:none"><fmt:message key="changecoverart.success"/></h2>
                    <h2 id="error" style="display:none"><fmt:message key="changecoverart.error"/></h2>
                    <div id="errorDetails" class="warning" style="display:none">
                    </div>

                    <div id="imagesearchresultcontainer" class="center">
                        <div id="imagesearchresults">

                            <div id="branding" style="float:right;padding-right:1em;padding-top:0.5em">
                            </div>

                            <div style="clear:both;">
                            </div>

                            <div id="images" style="width:100%;padding-bottom:2em">
                            </div>

                            <div style="clear:both;">
                            </div>

                        </div>
                    </div>

                    <div id="coverarttemplate" class="left" style="visibility:hidden;height:190px; width:220px;padding:10px;text-align:center;position:relative;vertical-align:bottom;">
                        <div style="position: absolute;bottom:0;margin:0px auto">
                            <div class="search-result-thumb">&nbsp;</div>
                            <a class="search-result-thumbnail-zoom" rel="zoom"><img class="search-result-thumbnail" style="padding:1px; border:1px solid #021a40; background-color:white;"></a>
                            <div><a class="search-result-setimage">Set as Cover Image</a></div>
                            <div class="search-result-title"></div>
                            <div class="search-result-dimension detail"></div>
                            <div class="search-result-url detail"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>
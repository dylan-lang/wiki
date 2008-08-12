<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <dsp:when test="page?">
      <div id="menu"> 
  	<span>modify</span>
    	<ul>
     	  <li>
	    <a href="<wiki:show-page-permanent-link/>">view</a> |
	    <a href="<wiki:show-page-permanent-link/>/remove">remove</a>
	  </li>
	  <li><a href="<wiki:show-page-permanent-link/>/versions">versions</a></li>
	  <li><a href="<wiki:show-page-permanent-link/>/connections">connections</a></li>
          <dsp:if test="page-discussion?">
	    <dsp:then>
	      <li><a href="<wiki:show-page-page-permanent-link/>">page</a></li>
	    </dsp:then>
	    <dsp:else>
	      <li><a href="<wiki:show-page-discussion-permanent-link/>">discussion</a></li>
	    </dsp:else>
	  </dsp:if>
	  <li><a href="<wiki:show-page-permanent-link/>/access">access</a></li>
        </ul>
      </div>
    </dsp:when>
    <div id="body">
      <h2><wiki:show-page-title/></h2>
      <dsp:if test="page?">
        <dsp:else>
          <p class="hint">
            This page doesn't exist. You can create it by writing the page's content below.
          </p>
        </dsp:else>
      </dsp:if>
      <dsp:if test="file?">
        <dsp:then>
          <form action="<turboblog:show-blog-permanent-link />/files/<turboblog:show-file-filename />?edit" method="post" enctype="multipart/form-data">
        </dsp:then>
        <dsp:else>
          <form action="<turboblog:show-blog-permanent-link />/files?add" method="post" enctype="multipart/form-data">
        </dsp:else>
      </dsp:if>
        <fieldset id="general">
          <legend>General</legend>
          <ol>
            <dsp:when test="add-file?">
              <li id="file">
                <label id="file-label" for="file-input">File <em>*</em></label>
                <input id="file-input" type="file" name="file" />
                <dsp:when test="file-error?"><span class="error">A file is required.</span></dsp:when>
              </li>
            </dsp:when>
            <li id="filename">
              <label id="filename-label" for="filename-input">Filename <dsp:when test="file?"><em>*</em></dsp:when></label>
              <input id="filename-input" type="text" name="filename" value="<turboblog:show-file-filename />"/>
              <dsp:when test="filename-error?"><span class="error">An filename is required.</span></dsp:when>
              <dsp:when test="exists-error?"><span class="error">There&quot;s already a file with this name.</span></dsp:when>
            </li>
          </ol>
        </fieldset>
        <dsp:if test="file?">
          <dsp:then>
            <input type="submit" value="Save"/>
          </dsp:then>
          <dsp:else>
            <input type="submit" value="Upload"/>
          </dsp:else>
        </dsp:if>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

<%dsp:taglib name="wiki"/><%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: Recent Changes</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Recent Changes</h2>
      <wiki:list-changes-daily>
	<h3><wiki:show-day-date formatted="%d.%m.%y"/></h3>
	<dl id="changes">
	  <wiki:list-day-changes>
	    <dt>
	      <span class="time"><wiki:show-change-date formatted="%H:%M"/></span>
	      <dsp:when test="page-changed?">
		<span class="object page">
		  <a href="<wiki:show-page-permanent-link use-change="true"/>"><wiki:show-change-title/></a>
		</span>
		<dsp:unless test="change-action=removal?">
		  [<a href="<wiki:show-page-permanent-link use-change="true" />/versions/<wiki:show-change-version/>"><wiki:show-change-version/></a>]
		</dsp:unless>
		<dsp:if test="change-action=edit?">
		  <dsp:then>
		    <a href="<wiki:show-page-permanent-link use-change="true"/>/versions/<wiki:show-change-version/>?diff"><wiki:show-change-verb/></a> 
		    (<a href="<wiki:show-page-permanent-link use-change="true"/>/versions/<wiki:show-change-version/>?diff"><wiki:show-change-difference/></a>) 
		  </dsp:then>
		  <dsp:else>
		    <wiki:show-change-verb/>
		  </dsp:else>
		</dsp:if>
              </dsp:when>
              <dsp:when test="user-changed?">
                <span class="object user">
  		  <a href="<wiki:show-user-permanent-link use-change="true"/>"><wiki:show-change-title/></a>
		</span>
		<wiki:show-change-verb/>
              </dsp:when>
              <dsp:when test="group-changed?">
                <span class="object group">
                  <a href="<wiki:show-group-permanent-link use-change="true"/>"><wiki:show-change-title/></a>
                </span>
                <wiki:show-change-verb/>
              </dsp:when>
              <wiki:with-change-author>
                by <a href="<wiki:show-user-permanent-link/>"><wiki:show-user-username/></a>
              </wiki:with-change-author>
	    </dt>
	    <dd>
	      <wiki:show-change-comment/>
	    </dd>
	  </wiki:list-day-changes>
	</dl>
      </wiki:list-changes-daily>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

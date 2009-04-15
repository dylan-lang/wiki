<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-page-title/>
    <dsp:unless test="latest-page-version?">
      @ #<wiki:show-version-number/>
    </dsp:unless>
  </title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="menu"> 
      <span>menu</span>
      <ul>
        <dsp:when test="can-modify-content?">
	  <li>
	    <a href="<wiki:show-page-permanent-link/>/edit">edit</a> |
	    <a href="<wiki:show-page-permanent-link/>/remove">remove</a>
	  </li>
	</dsp:when>
        <dsp:when test="can-view-content?">
	  <li><a href="<wiki:show-page-permanent-link/>/versions">versions</a></li>
	  <li><a href="<wiki:show-page-permanent-link/>/connections">connections</a></li>
	</dsp:when>
	<dsp:if test="is-discussion-page?">
          <dsp:then>
	    <li><a href="<wiki:show-page-page-permanent-link/>">page</a></li>
          </dsp:then>
          <dsp:else>
	    <li><a href="<wiki:show-page-discussion-permanent-link/>">discussion</a></li>
          </dsp:else>
	</dsp:if>
        <dsp:when test="can-modify-access?">
          <li><a href="<wiki:show-page-permanent-link/>/access">access</a></li>
        </dsp:when>
      </ul>
    </div>
    <div id="body">
      <h2><wiki:show-page-title/>
          <dsp:unless test="latest-page-version?">
	    <em>@ #<wiki:show-version-number/></em>
          </dsp:unless>
      </h2>
      <wiki:show-page-content content-format="xhtml"/>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

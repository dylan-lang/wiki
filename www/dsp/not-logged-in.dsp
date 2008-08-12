<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan</title>
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
	    <a href="<wiki:show-page-permanent-link/>/edit">edit</a> |
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
	</ul>
      </div>
    </dsp:when>
    <div id="body">
      <h2>Error</h2>
      <p>You have to <a href="<web-framework:show-login-url redirect="#t" current="#t"/>">login</a> to go on.</p>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

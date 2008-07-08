<%dsp:taglib name="wiki"/><%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-page-title/>
    <dsp:if test="latest-page-version?">
      <dsp:else>@ #<wiki:show-version-number/></dsp:else>
    </dsp:if>
  </title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
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
        <li><a href="<wiki:show-page-permanent-link/>/access">access</a></li>
      </ul>
    </div>
    <div id="body">
      <h2><wiki:show-page-title/>
          <dsp:if test="latest-page-version?">
	    <dsp:else><em>@ #<wiki:show-version-number/></em></dsp:else>
          </dsp:if>
      </h2>
      <wiki:show-page-content content-format="xhtml"/>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

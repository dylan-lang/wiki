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
    <div id="menu"> 
      <span>menu</span>
      <ul>
	<li>
	  <a href="<wiki:show-page-permanent-link/>">view</a> |
	  <a href="<wiki:show-page-permanent-link/>/edit">edit</a> |
	  <a href="<wiki:show-page-permanent-link/>/remove">remove</a>
	</li>
	<li><a href="<wiki:show-page-permanent-link/>/connections">connections</a></li>
	<dsp:if test="is-discussion-page?">
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
      <h2>History of <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>
      <ul class="striped big">
	<wiki:list-page-versions>
	  <li>
	    <strong>
	      <a href="<wiki:show-page-permanent-link/>/versions/<wiki:show-version-number/>">#<wiki:show-version-number/></a>
	    </strong> 
	    <wiki:show-version-published formatted="%e. %b %Y %H:%M:%S">:
	      <em><wiki:show-version-comment/></em>
	  </li>
	</wiki:list-page-versions>
      </ul>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

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
    <%dsp:include url="options-menu.dsp"/>
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

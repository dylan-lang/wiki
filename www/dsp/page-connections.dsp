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
      <h2>Connections of <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>
      <ul class="striped big">
	<wiki:list-page-backlinks>
          <li><a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></li>
	</wiki:list-page-backlinks>
      </ul>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

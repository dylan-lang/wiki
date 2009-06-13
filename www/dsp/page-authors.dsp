<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">               
      <h2>Authors of <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <ul class="striped big">
	<wiki:list-page-authors>
          <li><a href="<wiki:show-user-permanent-link/>"><wiki:show-user-username/></a></li>
	</wiki:list-page-authors>
      </ul>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

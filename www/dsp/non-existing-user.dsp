<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework" prefix="wf"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-group-name/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">
      <h2><wiki:show-group-name/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <p class="hint">
        This group doesn't exist.
	<a href="/register">Register</a> or
	<a href="<wf:show-login-url redirect="true" current="true"/>">login</a>
	to create it.
      </p>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

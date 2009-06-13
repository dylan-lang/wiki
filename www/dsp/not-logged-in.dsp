<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework" prefix="wf"/>
<head>
  <title>Dylan Wiki: Login</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">
      <h2>Error</h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <p>You have to <a href="<wf:show-login-url redirect="yes" current="yes"/>">login</a> to go on.</p>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

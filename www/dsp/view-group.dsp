<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Group <dsp:get name="group-name"/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <dsp:when test="exists?" name="active-user">
      <%dsp:include url="group-options-menu.dsp"/>
    </dsp:when>
    <div id="body">
      <h2>Group <dsp:get name="group-name"/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <%dsp:include url="view-group-body.dsp"/>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

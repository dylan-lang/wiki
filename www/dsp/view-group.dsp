<%dsp:taglib name="wiki"/>
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
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

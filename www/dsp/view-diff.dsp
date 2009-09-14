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
      <h2><wiki:show-page-title/> &mdash; diff of version #<dsp:get name="version1"/> and #<dsp:get name="version2"/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:loop over="diffs" context="page" var="diff-entry">
        <wiki:show-diff-entry name="diff-entry"/>
        <p/>
      </dsp:loop>

    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

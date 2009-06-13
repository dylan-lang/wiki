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
    <div id="body">
      <h2>Search Results for <em><dsp:get name="query" context="request"/></em></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <wiki:search-results/>

    </div>
  </div>		
  <%dsp:include url="footer.dsp"/>
</body>
</html>

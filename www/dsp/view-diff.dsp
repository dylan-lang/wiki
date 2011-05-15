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
      <h2>Change to <dsp:get name="name"/> @ <dsp:get name="date"/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <h3>Author: <dsp:get name="author"/></h3>
      <h3>Comment: <dsp:get name="comment"/></h3>

      <h2>Diff:</h2>
      <pre class="diff">
        <dsp:get name="diff" />
      </pre>


    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Group <dsp:get name="group-name"/></title>
  <%dsp:include url="meta.dsp"/>
  <link rel="alternate"
        type="application/atom+xml"
        title="Dylan Wiki Group Atom Feed"
        href="/feed/groups/<dsp:get name='group-name'/>" />
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <dsp:when test="exists?" name="active-user">
      <%dsp:include url="group-options-menu.dsp"/>
    </dsp:when>
    <div id="body">
      <h2>Group <dsp:get name="group-name"/>
        <a href="/feed/groups/<dsp:get name='group-name'/>">
          <img border="0" src="/images/feed-icon-14x14.png" alt="Atom feed for this group"/>
        </a>
      </h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <%dsp:include url="view-group-body.dsp"/>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

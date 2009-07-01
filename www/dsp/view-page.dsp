<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <wiki:show-page-title/>
    <dsp:unless test="latest-page-version?">
      @ #<wiki:show-version-number/>
    </dsp:unless>
  </title>
  <%dsp:include url="meta.dsp"/>
  <dsp:if test="can-view-content?">
    <link rel="alternate"
          type="application/atom+xml"
          title="Atom feed for page <wiki:show-page-title/>"
          href="/feed/pages/<wiki:show-page-title/>" />
  </dsp:if>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">
      <h2><wiki:show-page-title/>
          <dsp:unless test="latest-page-version?">
	    <em>@ #<wiki:show-version-number/></em>
          </dsp:unless>
          <dsp:if test="can-view-content?">
            <a href="/feed/pages/<wiki:show-page-title/>">
              <img border="0" src="/images/feed-icon-14x14.png" alt="Atom feed for this page"/>
            </a>
          </dsp:if>
      </h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:if test="can-view-content?">
        <dsp:then>
          <wiki:show-page-content content-format="xhtml"/>
          <dsp:loop over="page-tags" var="tag" header="<hl/><h3>Tags:</h3>">
            <dsp:get name="tag"/>
            <a href="/feed/tags/<dsp:get name='tag'/>">
              <img border="0" src="/images/feed-icon-14x14.png" alt="Atom feed for this tag"/>
            </a>
            <dsp:unless test="loop-end?">, </dsp:unless>
          </dsp:loop>
        </dsp:then>
        <dsp:else>
          You do not have permission to view this page.
        </dsp:else>
      </dsp:if>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

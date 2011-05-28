<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <wiki:show-page-title/>
    <dsp:unless test="latest-page-version?">
      @ <wiki:page-creation-date/>
    </dsp:unless>
  </title>
  <%dsp:include url="meta.dsp"/>
  <dsp:if test="can-view-content?">
    <link rel="alternate"
          type="application/atom+xml"
          title="Atom feed for page <wiki:show-page-title/>"
          href="<wiki:base/>/feed/pages/<wiki:show-page-title/>" />
  </dsp:if>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="midsection">
    <div id="navigation">
      <wiki:include-page title="Wiki Left Nav"/>
    </div>
    <%dsp:include url="options-menu.dsp"/>
    <div id="content">
      <h2><wiki:show-page-title/>
          <dsp:unless test="latest-page-version?">
            <em>@ <wiki:page-creation-date/></em>
          </dsp:unless>
          <dsp:if test="can-view-content?">
            <a href="<wiki:base/>/feed/pages/<wiki:show-page-title/>">
              <img border="0" src="<wiki:base/>/static/images/feed-icon-14x14.png" alt="Atom feed for this page"/>
            </a>
          </dsp:if>
      </h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:if test="can-view-content?">
        <dsp:then>
          <wiki:show-page-content/>
          <%dsp:include url="view-page-tags.dsp"/>
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

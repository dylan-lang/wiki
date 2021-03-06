<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <dsp:get name="user-name"/></title>
  <%dsp:include url="meta.dsp"/>
  <link rel="alternate"
        type="application/atom+xml"
        title="Dylan Wiki Atom Feed"
        href="<wiki:base/>/feed/users/<dsp:get name='user-name'/>" />
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="midsection">
    <div id="navigation">
      <wiki:include-page title="Wiki Left Nav"/>
    </div>
    <dsp:when test="logged-in?">
      <%dsp:include url="user-options-menu.dsp"/>
    </dsp:when>
    <div id="content">
      <h2>User <dsp:get name="user-name"/><dsp:when test="true?" name="admin?"> (administrator)</dsp:when>
        <a href="<wiki:base/>/feed/users/<dsp:get name='user-name'/>">
          <img border="0" src="<wiki:base/>/static/images/feed-icon-14x14.png" alt="Atom feed for changes to this user"/>
        </a>
      </h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

<dsp:comment> Not until we have a way for the user to opt in...
      <h3>Email Address</h3>
      <dsp:get name="user-email"/>
</dsp:comment>

      <h3>Group Memberships</h3>
      <ul>
        <dsp:loop over="group-memberships" context="page" var="group-name" empty="None">
          <li><a href="<wiki:base/>/group/view/<dsp:get name='group-name' context='page'/>">
              <dsp:get name="group-name" context="page"/></a>
          </li>
        </dsp:loop>
      </ul>

      <h3>Group Ownerships</h3>
      <ul>
        <dsp:loop over="group-ownerships" context="page" var="group-name" empty="None">
          <li><a href="<wiki:base/>/group/view/<dsp:get name='group-name' context='page'/>">
              <dsp:get name="group-name" context="page"/></a>
          </li>
        </dsp:loop>
      </ul>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-user-username/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <dsp:when test="logged-in?">
      <%dsp:include url="user-options-menu.dsp"/>
    </dsp:when>
    <div id="body">
      <h2><wiki:show-user-username/><dsp:when test="admin?"> (administrator)</dsp:when></h2>
      <dsp:show-form-notes/>

      <dsp:loop over="user-group-names" var="group-name" header="<h3>Group Memberships</h3><ul>" footer="</ul>">
        <li><a href="/groups/<dsp:get name="group-name" context="page"/>">
            <dsp:get name="group-name" context="page"/></a>
        </li>
      </dsp:loop>

      <dsp:loop over="group-names-owned-by-user" var="group-name" header="<h3>Group Ownerships</h3><ul>" footer="</ul>">
        <li><a href="/groups/<dsp:get name="group-name" context="page"/>">
            <dsp:get name="group-name" context="page"/></a>
        </li>
      </dsp:loop>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

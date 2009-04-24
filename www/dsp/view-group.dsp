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
      <h2>Group: <wiki:show-group-name/></h2>
      <h3>Members</h3>
      <dsp:loop over="group-member-names" var="user-name" header="<ul>" footer="</ul>">
        <li><a href="/users/<dsp:get name="user-name" context="page"/>">
            <dsp:get name="user-name" context="page"/></a>
          <dsp:when test="user-is-group-owner?">(group owner)</dsp:when>
        </li>
      </dsp:loop>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

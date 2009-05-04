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
    <dsp:when test="logged-in?">
      <%dsp:include url="group-options-menu.dsp"/>
    </dsp:when>
    <div id="body">
      <dsp:show-form-notes/>
      <h2>Group: <wiki:show-group-name/></h2>
      <h3>Members</h3>
      <dsp:if test="logged-in?">
        <dsp:then>
          <dsp:loop over="group-member-names" var="user-name" header="<ul>" footer="</ul>">
            <li><a href="/users/<dsp:get name="user-name" context="page"/>">
                <dsp:get name="user-name" context="page"/></a>
              <dsp:when test="user-is-group-owner?">(group owner)</dsp:when>
            </li>
          </dsp:loop>
        </dsp:then>
        <dsp:else>
          You must login to view group members.
        </dsp:else>
      </dsp:if>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

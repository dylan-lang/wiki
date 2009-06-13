<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Users</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Users</h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <form action="/users" method="post">
        <ul class="striped big">
          <li class="user">
            <input type="text" name="user-name"
                   value="<dsp:get name='user-name' context='request,page'/>"
                   <dsp:if-error field-name='user-name' text='class="invalid-input"'/>
                   />
            <input type="submit" name="go" value="Find"/>
            <dsp:show-field-errors field-name="user-name"/>
          </li>
          <dsp:loop over="active-users" context="page" var="user">
            <li class="user">
              <a href="/users/<dsp:get name='user[name]'/>"><dsp:get name="user[name]"/></a>
              <dsp:when test="true?" name="user[admin?]">*</dsp:when>
              <dsp:if-equal name1="user[name]" name2="active-user">(you)</dsp:if-equal>
            </li>
          </dsp:loop>
        </ul>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

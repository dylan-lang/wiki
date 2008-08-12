<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: Users</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Users</h2>
      <form action="/users">
        <ul class="striped big">
          <li class="user">
            <input type="text" name="query" value=""/>
            <input type="submit" name="go" value="Create"/>
          </li>
          <wiki:list-users>
            <li class="user">
              <a href="<wiki:show-user-permanent-link/>"><wiki:show-user-username/></a>
            </li>
          </wiki:list-users>
        </ul>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

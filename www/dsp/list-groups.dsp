<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: Groups</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Groups</h2>
      <form action="/groups">
        <ul class="striped big">
          <li class="group">
            <input type="text" name="query" value=""/>
            <input type="submit" name="go" value="Create"/>
          </li>
          <wiki:list-groups>
            <li class="group">
              <a href="<wiki:show-group-permanent-link/>"><wiki:show-group-name/></a>
            </li>
          </wiki:list-groups>
        </ul>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

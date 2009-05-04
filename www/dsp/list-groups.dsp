<%dsp:taglib name="dsp"/>
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
      <dsp:when test="logged-in?">
        <form action="/groups" method="post">
          <ul class="striped big">
            <li class="group">
              <input type="text" name="group" value=""/>
              <input type="submit" name="go" value="Create"/>
            </li>
          </ul>
        </form>
      </dsp:when>
      <dsp:loop over="all-group-names" var="group-name" header="<ul>" footer="</ul>">
        <li class="group">
          <a href="/groups/<dsp:get name="group-name" context="page"/>"><dsp:get name="group-name" context="page"/></a>
        </li>
      </dsp:loop>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

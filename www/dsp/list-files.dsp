<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: Files</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Files</h2>
      <form action="/files">
        <ul class="striped big">
          <li class="file">
            <input type="text" name="query" value=""/>
            <input type="submit" name="go" value="Create"/>
          </li>
          <wiki:list-files>
            <li class="file">
              <a href="<wiki:show-file-permanent-link/>"><wiki:show-file-filename/></a>
            </li>
          </wiki:list-files>
        </ul>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

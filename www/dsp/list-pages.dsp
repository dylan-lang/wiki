<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Pages</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Pages</h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:when test="query-tagged?">
        <ul class="cloud" id="query-tags">
          <wiki:list-query-tags>
            <li><wiki:show-tag/></li>
          </wiki:list-query-tags>
        </ul>
      </dsp:when>
      <form action="/pages">
        <ul class="striped big">
          <li class="page">
            <input type="text" name="query"
                   value="<dsp:get name='query' context='request,page'/>"/>
            <input type="submit" name="go" value="Find"/>
          </li>
          <dsp:loop over="all-page-titles" var="page-title">
            <li class="page">
              <a href="/pages/<dsp:get name="page-title" context="page"/>"><dsp:get name="page-title" context="page"/></a>
            </li>
          </dsp:loop>

<dsp:comment>            
          <wiki:list-pages use-query-tags="true">
            <li class="page">
              <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a>
            </li>
          </wiki:list-pages>
</dsp:comment>            

        </ul>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

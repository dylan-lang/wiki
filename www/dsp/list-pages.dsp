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
      <form action="<wiki:base/>/page/list" method="post">
        <ul class="striped big">
          <li class="page">
            <input type="text" name="query"
                   value="<dsp:get name='query' context='request,page'/>"/>
            <input type="submit" name="go" value="Find"/>
          </li>

          <!-- display the current page of the wiki page list -->
          <dsp:loop over="wiki-pages" context="page" var="info">
            <li class="page">
              <dsp:get name="info[when-published]"/>
              <a href="<wiki:base/>/page/view/<dsp:get name='info[title]'/>"><dsp:get name="info[title]"/></a>,
              changed by <dsp:get name="info[latest-authors]"/>
            </li>
          </dsp:loop>

        </ul>
      </form>
      <!-- display the paginator for the wiki page list -->
      <dsp:show-page-links name="wiki-pages" url="<wiki:base/>/pages?page=" query-value="page" />

    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

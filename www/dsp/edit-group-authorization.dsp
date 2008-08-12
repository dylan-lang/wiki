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
    <div id="menu"> 
      <span>edit</span>
      <ul>
        <li><a href="<wiki:show-group-permanent-link/>">properties</a></li>
        <li><a href="<wiki:show-group-permanent-link/>/members">members</a></li>
      </ul>
    </div>
    <div id="body">               
      <h2>Authorization of <a href="<wiki:show-group-permanent-link/>"><wiki:show-group-name/></a></h2>
      <form action="authorization" method="post">
        <fieldset>
	  <legend>Pages</legend>
          <ol>
            <li id="pages-read-item">
              <input id="pages-read-input" type="checkbox" name="pages-read"<dsp:when test="group-authorization-pages-read?"> checked="checked"</dsp:when>/>
	      <label id="pages-read-label" for="pages-read-input">Read</label>
            </li>
            <li id="pages-write-item">
              <input id="pages-write-input" type="checkbox" name="pages-write"<dsp:when test="group-authorization-pages-write?"> checked="checked"</dsp:when>/>
              <label id="pages-write-label" for="pages-write-input">Write</label>
            </li>
          </ol>
        </fieldset>
        <fieldset>
          <ol>
	    <li id="comment-item">
              <label id="comment-label" for="comment-input">Comment:</label>
              <input id="comment-input" type="text" name="comment" value=""/>
            </li>
          </ol>
        </fieldset>
        <input type="submit" value="Save" />
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

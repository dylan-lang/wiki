<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">
      <h2><wiki:show-page-title/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:if test="can-modify-content?">
        <dsp:then>
          <form action="" method="post">
            <fieldset>
              <ol>
                <li id="comment-item">
                  <label id="comment-label" for="comment-input">Comment:</label>
                  <input id="comment-input" type="text" name="comment" value=""/>
                </li>
              </ol>
            </fieldset>        	
            <input type="submit" value="Remove '<wiki:show-page-title/>'"/>  
          </form>
        </dsp:then>
        <dsp:else>
          You do not have permission to delete this page.
        </dsp:else>
      </dsp:if>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

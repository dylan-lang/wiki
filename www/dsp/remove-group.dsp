<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Remove Group <dsp:get name="group-name"/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="group-options-menu.dsp"/>
    <div id="body">
      <h2>Remove Group <dsp:get name="group-name"/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <%dsp:include url="view-group-body.dsp"/>

      <form action="" method="post">
	<fieldset>
          <ol>
            <li id="comment-item">
              <label id="comment-label" for="comment-input">Comment:</label>
              <input id="comment-input" type="text" name="comment"
                     value="<dsp:get name='comment' context='request'/>"/>
            </li>
          </ol>
        </fieldset>        	
        <input type="submit" value="Remove Group"/>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

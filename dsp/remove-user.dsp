<%dsp:taglib name="wiki"/><%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-user-username/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">
      <h2><wiki:show-user-username/></h2>
      <form action="" method="post">
	<fieldset>
          <ol>
            <li id="comment-item">
              <label id="comment-label" for="comment-input">Comment:</label>
              <input id="comment-input" type="text" name="comment" value=""/>
            </li>
          </ol>
        </fieldset>        	
        <input type="submit" value="Remove '<wiki:show-user-username/>'"/>  
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

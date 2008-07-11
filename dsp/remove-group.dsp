<%dsp:taglib name="wiki"/><%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <dsp:when test="page?">
      <div id="menu"> 
  	<span>modify</span>
    	<ul>
     	  <li>
	    <a href="<wiki:show-page-permanent-link/>">view</a> |
	    <a href="<wiki:show-page-permanent-link/>/edit">edit</a>
	  </li>
	  <li><a href="<wiki:show-page-permanent-link/>/versions">versions</a></li>
	  <li><a href="<wiki:show-page-permanent-link/>/connections">connections</a></li>
	  <dsp:if test="page-discussion?">
	    <dsp:then>
	      <li><a href="<wiki:show-page-page-permanent-link/>">page</a></li>
	    </dsp:then>
	    <dsp:else>
	      <li><a href="<wiki:show-page-discussion-permanent-link/>">discussion</a></li>
	    </dsp:else>
	  </dsp:if>
	</ul>
      </div>
    </dsp:when>
    <div id="body">
      <h2><wiki:show-page-title/></h2>
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
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

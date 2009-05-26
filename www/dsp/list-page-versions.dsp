<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
   <title>Dylan: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">               
      <h2>History of <a href="/pages/<dsp:get name='title'/>"><dsp:get name="title"/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <ul class="striped big">
	<wiki:list-page-versions>
	  <li>
	    <strong>
	      <a href="/pages/<dsp:get name='title'/>/versions/<dsp:get name='version-number'/>">#<dsp:get name="version-number"/></a>
	    </strong> 
	    <dsp:get name="published"/> by <a href="/users/<dsp:get name='author'/>"><dsp:get name='author'/></a> - <em><dsp:get name="comment"/></em>
	  </li>
	</wiki:list-page-versions>
      </ul>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

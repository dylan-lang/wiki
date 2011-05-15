<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <dsp:get name="title"/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">
      <h2>History of <a href="<wiki:base/>/page/view/<dsp:get name='title'/>"><dsp:get name="title"/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <ul class="striped big">
        <dsp:loop over="page-changes" context="page" var="change">
	  <li>
	    <strong>
	      <a href="<wiki:base/>/page/view/<dsp:get name='title'/>/<dsp:get name='change[rev]'/>"> <dsp:get name="title"/> @ <dsp:get name="change[date]"/></a>
	    </strong>
	    (<a href="<wiki:base/>/page/diff/<dsp:get name='title'/>/<dsp:get name='change[rev]'/>">diff</a>)
	    by <a href="<wiki:base/>/user/view/<dsp:get name='change[author]'/>"><dsp:get name='change[author]'/></a> <em><dsp:get name="change[comment]"/></em>
	  </li>
	</dsp:loop>
      </ul>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

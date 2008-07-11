<%dsp:taglib name="wiki"/><%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="menu"> 
      <span>modify</span>
      <ul>
	<li>
	  <a href="<wiki:show-page-permanent-link/>/edit">edit</a> |
	  <a href="<wiki:show-page-permanent-link/>/remove">remove</a>
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
        <li><a href="<wiki:show-page-permanent-link/>/access">access</a></li>	  
      </ul>
    </div>
    <div id="body">
      <h2>Difference of <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>
      <table id="diff">
	<thead>
	  <tr>
	    <th>
	      <wiki:with-other-version>
		<h3>Version: 
		  <a href="<wiki:show-page-permanent-link/>/versions/<wiki:show-version-number/>">#<wiki:show-version-number/></a>
    	        </h3>
      	        <wiki:show-version-published formatted="%e. %b %Y %H:%M:%S">:
        	  <em><wiki:show-version-comment/></em>	
	      </wiki:with-other-version>
	    </th>
	    <th>
	      <h3>Version:
		<a href="<wiki:show-page-permanent-link/>/versions/<wiki:show-version-number/>">#<wiki:show-version-number/></a>
	      </h3>
	      <wiki:show-version-published formatted="%e. %b %Y %H:%M:%S">:
		<em><wiki:show-version-comment/></em>
	    </th>
	  </tr>
	</thead>
	<tbody>
	  <wiki:with-diff>
	    <tr>
	      <td><wiki:with-other-version><wiki:show-page-content/></wiki:with-other-version></td>
	      <td><wiki:show-page-content/></td>
	    </tr>
	  </wiki:with-diff>
	</tbody>
      </table>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

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
      <h2>Difference of <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

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

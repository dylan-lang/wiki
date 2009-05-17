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
    <%dsp:include url="group-options-menu.dsp"/>
    <div id="body">               
      <h2>Members of <a href="<wiki:show-group-permanent-link/>"><wiki:show-group-name/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <form action="members" method="post">
        <fieldset>
          <table style="width: 100%">
	    <tr>
	      <th><label id="users-label" for="users-list">Users:</label></th>
	      <th><label id="members-label" for="members-list">Members:</label></th>
	    </tr>
	    <tr>
              <td id="users-item">
	        <select id="users-list" name="users" multiple="multiple">
                  <wiki:list-users>
                    <option><wiki:show-user-username/></option>
		  </wiki:list-users>
                </select>
	      </td>
              <td id="members-item">
                <select id="members-list" name="members" multiple="multiple">
                  <dsp:loop over="group-member-names" var="user-name" header="<ul>" footer="</ul>">
                    <option><dsp:get name="user-name" context="page"/></option>
                  </dsp:loop>
	        </select>
              </td>
	    </tr>
	    <tr>
              <td id="comment-item" colspan="2">
                <label id="comment-label" for="comment-input">Comment:</label>
                <input id="comment-input" type="text" name="comment" value=""/>
              </td>
            </tr>
	    <tr>
	      <td><input type="submit" name="add" value="Add" /></td>
	      <td><input type="submit" name="remove" value="Remove" /></td>
	    </tr>
        </table>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

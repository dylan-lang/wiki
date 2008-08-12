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
        <li><a href="<wiki:show-group-permanent-link/>/authorization">authorization</a></li>
      </ul>
    </div>
    <div id="body">               
      <h2>Members of <a href="<wiki:show-group-permanent-link/>"><wiki:show-group-name/></a></h2>
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
                  <wiki:list-group-members>
	            <option><wiki:show-user-username/></option>
	          </wiki:list-group-members>
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

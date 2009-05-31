<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan Wiki: Change Members of <dsp:get name="group-name"/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="group-options-menu.dsp"/>
    <div id="body">
      <h2>Change Members of <a href="/groups/<dsp:get name='group-name'/>"><dsp:get name='group-name'/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <form action="members" method="post">
        <fieldset>
          <table>
	    <tr>
              <td id="users-item">
                <label id="users-label" for="users-list">Users:</label>
	        <select id="users-list" name="users" multiple="multiple">
                  <dsp:loop over="non-members" context="page" var="user-name">
                    <option><dsp:get name="user-name"/></option>
		  </dsp:loop>
                </select>
	      </td>
              <td id="members-item">
                <label id="members-label" for="members-list">Members:</label>
                <select id="members-list" name="members" multiple="multiple">
                  <dsp:loop over="group-members" var="user-name" context="page">
                    <option><dsp:get name="user-name"/></option>
                  </dsp:loop>
	        </select>
              </td>
	    </tr>
	    <tr>
	      <td><input type="submit" name="add" value="Add" /></td>
	      <td><input type="submit" name="remove" value="Remove" /></td>
	    </tr>
	    <tr>
              <td id="comment-item" colspan="2">
                <label id="comment-label" for="comment-input">Comment:</label>
                <input id="comment-input" type="text" name="comment"
                       value="<dsp:get name='comment' context='request'/>"/>
              </td>
            </tr>
          </table>
        </fieldset>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

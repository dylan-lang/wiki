<%dsp:taglib name="wiki"/>

<%dsp:include url="xhtml-start.dsp"/>

<head>
   <title>Dylan: <wiki:show-page-title/> -- access control</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">               
      <dsp:show-form-notes/>
      <h2>Access Control for <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>
      <dsp:if test="can-view-content?">
        <dsp:then>
          <form action="" method="post">

            <p/>
            <label id="owner-label" for="owner-input">Owner:</label>
            <input id="owner-input" type="text" name="owner" width="20"
                   value="<dsp:get name="owner-name" context="page"/>"/>
            <p/>
            <table border="0">
              <tr>
                <td>
                  <label for="view-content-input">View Content</label>
                  <textarea id="view-content-input" name="view-content" cols="20" rows="10"
                            ><wiki:show-rules name="view-content"/></textarea>
                </td>
                <td>
                  <label for="modify-content-input">Modify Content</label>
                  <textarea id="modify-content-input" name="modify-content" cols="20" rows="10"
                            ><wiki:show-rules name="modify-content"/></textarea>
                </td>
                <td>
                  <label for="modify-acls-input">Modify ACLs</label>
                  <textarea id="modify-acls-input" name="modify-acls" cols="20" rows="10"
                            ><wiki:show-rules name="modify-acls"/></textarea>
                </td>
              </tr>
            </table>

            Enter user names, group names, or one of the three
            special rules: <em>owner</em>, <em>trusted</em> (i.e.,
            must be logged in), or <em>anyone</em>.  Enter one per
            line.  Precede any rule with ! to deny access to that
            target.

            <p/>
            <label id="comment-label" for="comment-input">Comment:</label>
            <input id="comment-input" type="text" name="comment" value="" width="50"/>
            <p/>
            <input type="submit" value="Save" />
          </form>
        </dsp:then>

        <dsp:comment>
          For now if you don't have permission to modify the ACLs you can't see 'em either.
          Eventually maybe we just show them, or add a view-acls permission, though I'm
          not sure it's worth the trouble.
        </dsp:comment>

        <dsp:else>
          You do not have permission to view this page.
        </dsp:else>
      </dsp:if>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

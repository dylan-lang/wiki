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
      <dsp:show-page-notes/>
      <h2>Access Control for <a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h2>
      <dsp:if test="can-view-content?">
        <dsp:then>
          <form action="" method="post">

            <p>
            Enter user names, group names, or one of the three
            special targets: <em>owner</em> (i.e., page
            owner), <em>trusted</em> (i.e., must be logged in),
            or <em>anyone</em>.  Enter one per line.  Precede any
            rule with ! to deny access to that target.
            </p>

            <label id="owner-label" for="owner-input">Owner:</label>
<dsp:comment>
todo
            <dsp:input id="owner-input" type="text" name="owner" width="20"/>
</dsp:comment>
            <input id="owner-input" type="text" name="owner-name" width="20"
                   <dsp:if-error field-name='owner-name' text='class="invalid-input"'/>
                   value="<dsp:get name='owner-name' context='request,page'/>"/>
            <dsp:show-field-errors field-name="owner-name"/>
            <p/>
            <table border="0">
              <tr>
                <td>
                  <label for="view-content-input">View Content</label>
                  <textarea id="view-content-input" name="view-content" cols="20" rows="6"
                            <dsp:if-error field-name='view-content' text='class="invalid-input"'/>
                            ><wiki:show-rules name="view-content"/></textarea>
                </td>
                <td>
                  <label for="modify-content-input">Modify Content</label>
                  <textarea id="modify-content-input" name="modify-content" cols="20" rows="6"
                            <dsp:if-error field-name='modify-content' text='class="invalid-input"'/>
                            ><wiki:show-rules name="modify-content"/></textarea>
                </td>
                <td>
                  <label for="modify-acls-input">Modify ACLs</label>
                  <textarea id="modify-acls-input" name="modify-acls" cols="20" rows="6"
                            <dsp:if-error field-name='modify-acls' text='class="invalid-input"'/>
                            ><wiki:show-rules name="modify-acls"/></textarea>
                </td>
              </tr>
              <tr>
                <td colspan="3" align="left">
                  <dsp:show-field-errors field-name="modify-content,modify-acls,view-content"/>
                </td>
              </tr>
            </table>
            <p/>
            <label id="comment-label" for="comment-input">Comment:</label>
            <input id="comment-input" type="text" name="comment" width="50"
                   <dsp:if-error field-name='comment' text='class="invalid-input"'/>
                   value="<dsp:get name='comment' context='request'/>"/>
            <dsp:show-field-errors field-name="comment"/>
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

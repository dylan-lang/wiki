<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework" prefix="wf"/>
<head>
   <title>Dylan Wiki: Group <dsp:get name="group-name"/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="group-options-menu.dsp"/>
    <div id="body">               
      <h2>Group <dsp:get name="group-name"/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:if test="exists?" name="active-user">

        <dsp:else>
          <!-- not logged in -->
          <p class="hint">
            You must <a href="<wiki:base/>/register">Register</a> or
            <a href="<wiki:base/>/login?redirect=<wiki:current/>">login</a>
            to edit this group.
          </p>
        </dsp:else>

        <dsp:then>
          <!-- logged in -->
          <dsp:unless test="exists?" name="group-owner">
            <p class="hint">
              This group doesn't exist. Enter a comment and click Create to create it.
            </p>
          </dsp:unless>
          <form action="" method="post">
            <fieldset>
              <ol>
                <li id="name-item">
                  <label id="name-label" for="name-input">Name: <em title="required">*</em></label>
                  <input id="name-input" type="text" name="group-name"
                         <dsp:if-error field-name="group-name" text='class="invalid-input"'/>
                         value="<dsp:get name='group-name' context='request,page'/>"/>
                  <dsp:show-field-errors field-name="group-name"/>
                </li>
                <li id="owner-item">
                  <label id="owner-label" for="owner-input">Owner: <em title="required">*</em></label>
                  <input id="owner-input" type="text" name="group-owner"
                         <dsp:if-error field-name="group-owner" text='class="invalid-input"'/>
                         value="<dsp:get name='group-owner' context='request,page'/>"/>
                  <dsp:show-field-errors field-name="group-owner"/>
                </li>
                <li id="description-item">
                  <label id="description-label" for="description-text">Description: <em title="required">*</em></label>
                  <textarea id="description-text" name="group-description" rows="3" cols="40"
                            <dsp:if-error field-name='group-description' text='class="invalid-input"'/>><dsp:get name='group-description' context='request,page'/></textarea>
                  <dsp:show-field-errors field-name="group-description"/>
                </li>
                <li id="comment-item">
                  <label id="comment-label" for="comment-input">Comment:</label>
                  <input id="comment-input" type="text" name="comment"
                         value="<dsp:get name='comment' context='request'/>"/>
                </li>
              </ol>
            </fieldset>
            <dsp:if test="exists?" name="group-owner">
              <dsp:then>
                <input type="submit" value="Save" />
              </dsp:then>
              <dsp:else>
                <input type="submit" value="Create" />
              </dsp:else>
            </dsp:if>
          </form> 
        </dsp:then>
      </dsp:if>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

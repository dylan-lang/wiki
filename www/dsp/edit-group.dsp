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
      <dsp:show-form-notes/>
      <h2><wiki:show-group-name/></h2>
      <dsp:unless test="group?">
        <p class="hint">
          This group doesn't exist. Enter a comment and click Create to create it.
        </p>
      </dsp:unless>
      <form action="" method="post">
        <fieldset>
          <ol>
	    <dsp:when test="group?">
              <li id="name-item">
                <label id="name-label" for="name-input">Name: <em title="required">*</em></label>
                <input id="name-input" type="text" name="name" value="<wiki:show-group-name/>"/>
                <dsp:when test="name-error?">
                  <span class="error">A name is required.</span>
                </dsp:when>
                <dsp:when test="exists-error?">
                  <span class="error">There's already a group with this name.</span>
                </dsp:when>
              </li>
	    </dsp:when>
            <li id="comment-item">
              <label id="comment-label" for="comment-input">Comment:</label>
              <input id="comment-input" type="text" name="comment" value=""/>
            </li>
          </ol>
        </fieldset>
        <dsp:if test="group?">
          <dsp:then>
            <input type="submit" value="Save" />
          </dsp:then>
          <dsp:else>
            <input type="submit" value="Create" />
          </dsp:else>
        </dsp:if>
      </form> 
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

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
      <h2><wiki:show-page-title/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:if test="page?">
        <dsp:then>
          (Owned by <wiki:show-page-owner/>)
        </dsp:then>
        <dsp:else>
          <p class="hint">
            This page doesn't exist. You can create it by writing the page's content below.
          </p>
        </dsp:else>
      </dsp:if>
      <dsp:when test="can-modify-content?">
        <form action="" method="post">
          <fieldset>
            <ol>
              <li id="title-item">
                <label id="title-label" for="title-input">Title: <em title="required">*</em></label>
                <input id="title-input" type="text" name="title"
                       <dsp:if-error field-name="title" text='class="invalid-input"'/>
                       value="<dsp:get name='title' context='request,page'/>"/>
                <dsp:show-field-errors field-name="title" tag="span"/>
              </li>
              <li id="content-item">
                <label id="content-label" for="content-text">Content:</label>
                <textarea id="content-text" name="content" rows="20" cols="80"><dsp:get name="content" context="request,page"/></textarea>
              </li>
              <li id="tags-item">
                <label id="tags-label" for="tags-input">Tags:</label>
                <input id="tags-input" type="text" name="tags"
                       value="<dsp:get name='tags' context='request,page'/>"/>
                <dsp:show-field-errors field-name="tags"/>
              </li>
              <li id="comment-item">
                <label id="comment-label" for="comment-input">Comment:</label>
                <input id="comment-input" type="text" name="comment"
                       value="<dsp:get name='comment' context='request'/>"/>
                <dsp:show-field-errors field-name="comment"/>
              </li>
            </ol>
          </fieldset>
          <dsp:if test="page?">
            <dsp:then>
              <input type="submit" value="Save" />
            </dsp:then>
            <dsp:else>
              <input type="submit" value="Create" />
            </dsp:else>
          </dsp:if>	
        </form>
      </dsp:when>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan: <wiki:show-page-title/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <%dsp:include url="options-menu.dsp"/>
    <div id="body">
      <h2><wiki:show-page-title/></h2>
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
      <dsp:if test="can-modify-content?">
        <dsp:then>
          <form action="" method="post">
            <fieldset>
              <ol>
                <dsp:when test="page?">
                  <li id="title-item">
                    <label id="title-label" for="title-input">Title: <em title="required">*</em></label>
                    <input id="title-input" type="text" name="title" value="<wiki:show-page-title/>"/>
                    <dsp:when test="title-error?"><span class="error">A title is required.</span></dsp:when>
                    <dsp:when test="exists-error?"><span class="error">There's already a page with this title.</span></dsp:when>
                  </li>
                </dsp:when>
                <li id="content-item">
                  <label id="content-label" for="content-text">Content:</label>
                  <textarea id="content-text" name="content" rows="20" cols="80"><wiki:show-page-content content-format="markup"/></textarea>
                </li>
                <li id="tags-item">
                  <label id="tags-label" for="tags-input">Tags:</label>
                  <input id="tags-input" type="text" name="tags" value="<wiki:list-page-tags><wiki:show-tag /> </wiki:list-page-tags>"/>
                </li>
                <li id="comment-item">
                  <label id="comment-label" for="comment-input">Comment:</label>
                  <input id="comment-input" type="text" name="comment" value=""/>
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
        </dsp:then>
        <dsp:else>
          You do not have permission to modify this page.
        </dsp:else>
      </dsp:if>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

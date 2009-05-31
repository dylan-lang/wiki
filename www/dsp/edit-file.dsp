<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
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

      <form action="/???" method="post" enctype="multipart/form-data">
        <fieldset id="general">
          <legend>General</legend>
          <ol>
            <dsp:when test="add-file?">
              <li id="file">
                <label id="file-label" for="file-input">File <em>*</em></label>
                <input id="file-input" type="file" name="file" />
                <dsp:show-field-errors field-name="file"/>
              </li>
            </dsp:when>
            <li id="filename">
              <label id="filename-label" for="filename-input">Filename <dsp:when test="file?"><em>*</em></dsp:when></label>
              <input id="filename-input" type="text" name="filename" value="<dsp:get name="filename" context="page"/>"/>
              <dsp:show-field-errors field-name="filename"/>
            </li>
          </ol>
        </fieldset>
        <dsp:if test="file?">
          <dsp:then>
            <input type="submit" value="Save"/>
          </dsp:then>
          <dsp:else>
            <input type="submit" value="Upload"/>
          </dsp:else>
        </dsp:if>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

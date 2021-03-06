<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: <wiki:show-user-username/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="midsection">
    <div id="navigation">
      <wiki:include-page title="Wiki Left Nav"/>
    </div>
    <div id="content">
      <h2><wiki:show-user-username/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:loop over="user-group-names" var="group-name" footer="</ul>">
        <dsp:when test="loop-start?">
          <h3><wiki:show-user-username/> is a member of:</h3>
          <ul>
        </dsp:when>
        <li><a href="<wiki:base/>/group/view/<dsp:get name="group-name" context="page"/>">
            <dsp:get name="group-name" context="page"/></a>
        </li>
      </dsp:loop>

      <dsp:loop over="group-names-owned-by-user" var="group-name" footer="</ul>">
        <dsp:when test="loop-start?">
          <h3>Groups owned by <wiki:show-user-username/>:</h3>
          <ul>
        </dsp:when>
        <li><a href="<wiki:base/>/group/view/<dsp:get name="group-name" context="page"/>">
            <dsp:get name="group-name" context="page"/></a>
        </li>
        <dsp:when test="loop-end?">
          </ul>
          <h3>Note that any groups owned by this user will become owned by the
            "administrator" user.</h3>
        </dsp:when>

      </dsp:loop>

      <form action="<wiki:base/>/user/deactivate/<wiki:show-user-username/>" method="post">
        <fieldset>
          <ol>
            <li id="comment-item">
              <label id="comment-label" for="comment-input">Comment:</label>
              <input id="comment-input" type="text" name="comment" value=""/>
            </li>
          </ol>
        </fieldset>
        <input type="submit" value="Deactivate '<wiki:show-user-username/>'"/>  
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

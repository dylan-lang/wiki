<%dsp:taglib name="wiki"/><%dsp:include url="xhtml-start.dsp"/>
<head>
   <title>Dylan: <wiki:show-group-name/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <dsp:when test="group?">
      <div id="menu"> 
        <span>edit</span>
        <ul>
          <li><a href="<wiki:show-group-permanent-link/>/members">members</a></li>
          <li><a href="<wiki:show-group-permanent-link/>/authorization">authorization</a></li>
        </ul>
      </div> 
    </dsp:when>
    <div id="body">               
      <h2><wiki:show-group-name/></h2>
      <dsp:if test="group?">
        <dsp:else>
          <p class="hint">
            This group doesn't exist. You can create it by entering the group's name below.
          </p>
        </dsp:else>
      </dsp:if>
      <form action="" method="post">
        <fieldset>
          <ol>
	    <dsp:when test="group?">
              <li id="name-item">
                <label id="name-label" for="name-input">Name: <em title="required">*</em></label>
                <input id="name-input" type="text" name="name" value="<wiki:show-group-name/>"/>
                <dsp:when test="name-error?"><span class="error">An name is required.</span></dsp:when>
                <dsp:when test="exists-error?"><span class="error">There's already a group with this name.</span></dsp:when> 
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

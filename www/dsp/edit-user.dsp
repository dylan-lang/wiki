<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">
      <h2><wiki:show-user-username/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:if test="user?">
        <dsp:else>
          <p class="hint">
            This user doesn't exist. You can create it below.
          </p>
        </dsp:else>
      </dsp:if>
      <form method="post">
        <fieldset id="general" class="splitted">
          <ol>
            <dsp:when test="user?">
              <li id="username">
                <label id="username-label" for="username-input">Username <em title="required">*</em></label>
                <input id="username-input" type="text" name="username" value="<wiki:show-user-username />"/>
                <dsp:when test="username-error?"><span class="error">An username is required.</span></dsp:when>
                <dsp:when test="exists-error?"><span class="error">This username is already in use.</span></dsp:when>
              </li>
	    </dsp:when>
            <li id="password">
	      <label id="password-label" for="password-input">Password <em title="required">*</em></label>
              <input id="password-input" type="password" name="password" />
              <dsp:when test="password-error?"><span class="error">A password is required.</span></dsp:when>
	    </li>
            <li id="email">
              <label id="email-label" for="email-input">E-Mail <em title="required">*</em></label>
              <input id="email-input" type="text" name="email" value="<wiki:show-user-email />"/>
              <dsp:when test="email-error?"><span class="error">An email is required to get in contact with you.</span></dsp:when>
	    </li>
          </ol>
        </fieldset>
        <dsp:if test="user?">
          <dsp:then>
            <input type="submit" value="Save"/>
          </dsp:then>
          <dsp:else>
            <input type="submit" value="Register"/>
          </dsp:else>
        </dsp:if>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

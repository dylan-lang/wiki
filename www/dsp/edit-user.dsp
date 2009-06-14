<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan Wiki: Edit User <dsp:get name="user-name"/></title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">
      <h2><dsp:get name="user-name"/></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:unless test="exists?" name="user-name">
        <p class="hint">
          This user doesn't exist. You can create it below.
        </p>
      </dsp:unless>
      <form method="post">
        <fieldset id="general" class="splitted">
          <ol>
            <li id="username">
              <label id="username-label" for="username-input">Name <em title="required">*</em></label>
              <input id="username-input" type="text" name="user-name"
                     <dsp:if-error field-name="user-name" text='class="invalid-input"'/>
                     value="<dsp:get name='user-name' context='request,page'/>"/>
              <dsp:show-field-errors field-name="user-name"/>
            </li>
            <li id="password">
	      <label id="password-label" for="password-input">Password <em title="required">*</em></label>
              <input id="password-input" type="password" name="password"
                     <dsp:if-error field-name="password" text='class="invalid-input"'/>
                     value="<dsp:get name='password' context='request,page'/>"/>
              <dsp:show-field-errors field-name="password"/>
	    </li>
            <li id="email">
              <label id="email-label" for="email-input">E-Mail <em title="required">*</em></label>
              <input id="email-input" type="text" name="email"
                     <dsp:if-error field-name="email" text='class="invalid-input"'/>
                     value="<dsp:get name='email' context='request,page'/>"/>
              <dsp:show-field-errors field-name="email"/>
	    </li>
            <dsp:when test="true?" name="active-user-is-admin?">
              <li id="admin">
                <label id="admini-label" for="admin-input">Administrator?</label>
                <input id="admin-input" type="checkbox" name="admin?"
                       <dsp:when test="false?" name="active-user-is-admin?">disabled="disabled"</dsp:when>
                       <dsp:when test="true?" name="admin?" context="request,page">checked="checked"</dsp:when>
                       <dsp:if-error field-name="admin?" text='class="invalid-input"'/> />
                <dsp:show-field-errors field-name="admin?"/>
	      </li>
            </dsp:when>
          </ol>
        </fieldset>
        <input type="submit" value="<dsp:get name='button-text'/>"/>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

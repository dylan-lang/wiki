<%dsp:taglib name="wiki"/>
<%dsp:include url="xhtml-start.dsp"/>
<head>
  <title>Dylan Wiki: Register New Account</title>
  <%dsp:include url="meta.dsp"/>
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

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
            <li id="password2">
	      <label id="password2-label" for="password2-input">Password <em title="required">*</em></label>
              <input id="password2-input" type="password2" name="password2"
                     <dsp:if-error field-name="password2" text='class="invalid-input"'/>
                     value="<dsp:get name='password2' context='request,page'/>"/>
              <dsp:show-field-errors field-name="password2"/>
	    </li>
            <li id="email">
              <label id="email-label" for="email-input">Confirm Email Address <em title="required">*</em></label>
              <input id="email-input" type="text" name="email"
                     <dsp:if-error field-name="email" text='class="invalid-input"'/>
                     value="<dsp:get name='email' context='request,page'/>"/>
              <dsp:show-field-errors field-name="email"/>
	    </li>
          </ol>
        </fieldset>
        <input type="submit" value="Register New Account"/>
      </form>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework" prefix="wf"/>
<head>
  <title>Dylan Wiki: Groups</title>
  <%dsp:include url="meta.dsp"/>
  <link rel="alternate"
        type="application/atom+xml"
        title="Dylan Wiki Groups Atom Feed"
        href="/feed/groups" />
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Groups <a href="/feed/groups"><img border="0" src="/images/feed-icon-14x14.png" alt="Atom Feed"/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:when test="logged-in?">
        <form action="/groups" method="post">
          <ul class="striped big">
            <li class="group">
              <input type="text" name="group"
                     value="<dsp:get name='group' context='request,page'/>"
                     <dsp:if-error field-name='group' text='class="invalid-input"'/>
                     />
              <input type="submit" name="go" value="Create"/>
              <dsp:show-field-errors field-name="group"/>
            </li>
          </ul>
        </form>
      </dsp:when>
      <dsp:unless test="logged-in?">
	<a href="/register">Register</a> or
	<a href="<wf:show-login-url redirect="true" current="true"/>">login</a>
        to create a new group.
      </dsp:unless>
      <dsp:loop over="all-groups" context="page" var="group" header="<ul>" footer="</ul>" empty="<p>There are no groups.</p>">
        <li class="group">
          <a href="/groups/<dsp:get name='group[name]' context='page'/>"><dsp:get name="group[name]" context="page"/></a> (<dsp:get name="group[count]"/> members)
          <div class="group-description"><dsp:get name="group[description]"/></div>
        </li>
      </dsp:loop>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

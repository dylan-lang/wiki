<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework" prefix="wf"/>
<head>
  <title>Dylan Wiki: Groups</title>
  <%dsp:include url="meta.dsp"/>
  <link rel="alternate"
        type="application/atom+xml"
        title="Dylan Wiki Group Changes"
        href="<wiki:base/>/feed/groups" />
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Groups <a href="<wiki:base/>/feed/groups"><img border="0" src="<wiki:base/>/static/images/feed-icon-14x14.png" alt="Atom feed for group changes"/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:when test="logged-in?">
        <form action="<wiki:base/>/group/list" method="post">
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
	<a href="<wiki:base/>/register">Register</a> or
	<a href="<wiki:base/>/login?redirect=<wiki:current/>">login</a>
        to create a new group.
      </dsp:unless>
      <dsp:loop over="all-groups" context="page" var="group" header="<ul>" footer="</ul>" empty="<p>There are no groups.</p>">
        <li class="group">
          <a href="<wiki:base/>/group/view/<dsp:get name='group[name]' context='page'/>"><dsp:get name="group[name]" context="page"/></a> (<dsp:get name="group[count]"/> members)
          <div class="group-description"><dsp:get name="group[description]"/></div>
        </li>
      </dsp:loop>
    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

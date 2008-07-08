<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework"/>
<a href="/" title="Dylan">
  <h1 id="header">
    Dylan
  </h1>
</a>
<div id="search-user">
  <form id="search-form" action="/" method="get">
    <fieldset>
      <ol>
        <li>
          <select name="type" size="1">
	    <option>*</option>
            <option selected="selected">Page</option>
	    <option>User</option>
	    <option>Group</option>
	    <option>File</option>
	  </select>
	</li>
        <li>
          <input id="search-text" type="text" name="query" value=""/>
	</li>
	<li>
          <input type="submit" name="search" value="Search"/>
	</li>
	<li>
          <input type="submit" name="go" value="Go"/>
	</li>
      </ol>
    </fieldset>
  </form>
  <div id="authenticated-user">
  <dsp:if test="authenticated?">
  <dsp:then>
  <wiki:with-authenticated-user>
    <span class="user-info">
      <a id="authenticated-user-link" href="<wiki:show-user-permanent-link />"><wiki:show-user-username/></a>
      &mdash;
      <a href="<web-framework:show-logout-url redirect="true" current="true"/>">logout</a>
    </span>
  </wiki:with-authenticated-user>
  </dsp:then>
  <dsp:else>
    <span>
      <a href="/users">register</a>
      &mdash;
      <a href="<web-framework:show-login-url redirect="true" current="true"/>">login</a>
    </span>
  </dsp:else>
  </dsp:if>
  </div>
</div>

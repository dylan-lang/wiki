<%dsp:taglib name="wiki"/>
<%dsp:taglib name="web-framework" prefix="wf"/>
<a id="dylan-logo" href="/" title="Dylan"><img border="0" src="/images/dylan-logo.png" alt="Dylan"/></a>
<div id="search-user">

  <form action="http://www.google.com/cse" id="cse-search-box">
    <div>
      <input type="hidden" name="cx" value="007351416707469336892:urro5q5ibho" />
      <input type="hidden" name="ie" value="UTF-8" />
      <input type="text" name="q" size="20" />
      <input type="submit" name="sa" value="Google Search" />
    </div>
  </form>

<dsp:comment>
We'll use Google custom search, at least for a while

  <script type="text/javascript" src="http://www.google.com/coop/cse/brand?form=cse-search-box&lang=en"></script>

  <form id="search-form" action="<wiki:base/>/search" method="get">
    <fieldset>
      <ol>
        <li>
          <select name="search-type" size="1">
	    <option>*</option>
            <option selected="selected">Page</option>
	    <option>User</option>
	    <option>Group</option>
	    <option>File</option>
	  </select>
	</li>
        <li>
          <input id="search-text" type="text" name="query" value="<dsp:get name="query" context="request"/>"/>
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

</dsp:comment>

  <div id="authenticated-user">
    <dsp:if test="authenticated?">
      <dsp:then>
        <wiki:with-authenticated-user>
          <span class="user-info">
            <a id="authenticated-user-link" href="<wiki:show-user-permanent-link/>"><wiki:show-user-username/></a>
            &mdash;
            <a href="<wiki:base/>/logout?redirect=<wiki:current/>">logout</a>
          </span>
        </wiki:with-authenticated-user>
      </dsp:then>
      <dsp:else>
        <span class="not-logged-in">
          <a href="<wiki:base/>/register">register</a>
          &mdash;
          <a href="<wiki:base/>/login?redirect=<wiki:current/>">login</a>
        </span>
      </dsp:else>
    </dsp:if>
  </div>

</div>

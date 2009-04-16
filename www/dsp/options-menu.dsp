<%dsp:taglib name="wiki"/>

    <div id="menu"> 
      <span>options</span>
      <ul>
	<li><a href="<wiki:show-page-permanent-link/>">view</a></li>
        <dsp:when test="can-modify-content?">
	  <li>
	    <a href="<wiki:show-page-permanent-link/>/edit">edit</a> |
	    <a href="<wiki:show-page-permanent-link/>/remove">remove</a>
	  </li>
	</dsp:when>
        <dsp:when test="can-view-content?">
	  <li><a href="<wiki:show-page-permanent-link/>/versions">versions</a></li>
	  <li><a href="<wiki:show-page-permanent-link/>/connections">connections</a></li>
	</dsp:when>
	<dsp:if test="is-discussion-page?">
          <dsp:then>
	    <li><a href="<wiki:show-page-page-permanent-link/>">page</a></li>
          </dsp:then>
          <dsp:else>
	    <li><a href="<wiki:show-page-discussion-permanent-link/>">discussion</a></li>
          </dsp:else>
	</dsp:if>
        <dsp:when test="can-modify-access?">
          <li><a href="<wiki:show-page-permanent-link/>/access">access</a></li>
        </dsp:when>
      </ul>
    </div>

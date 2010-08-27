<%dsp:taglib name="wiki"/>

    <div id="menu"> 
      <span>options</span>
      <ul>
	<li><a href="<wiki:base/>/page/view/<wiki:show-page-title/>">view</a></li>
        <dsp:when test="can-modify-content?">
	  <li>
	    <a href="<wiki:base/>/page/edit/<wiki:show-page-title/>">edit</a> |
	    <a href="<wiki:base/>/page/remove/<wiki:show-page-title/>">remove</a>
	  </li>
	</dsp:when>
        <dsp:when test="can-view-content?">
	  <li><a href="<wiki:base/>/page/versions/<wiki:show-page-title/>">versions</a></li>
	  <li><a href="<wiki:base/>/page/connections/<wiki:show-page-title/>">connections</a></li>
	</dsp:when>
	<dsp:if test="is-discussion-page?">
          <dsp:then>
	    <li><a href="<wiki:base/>/page/view/<wiki:show-main-page-title/>">page</a></li>
          </dsp:then>
          <dsp:else>
	    <li><a href="<wiki:base/>/page/view/<wiki:show-discussion-page-title/>">discussion</a></li>
          </dsp:else>
	</dsp:if>
        <dsp:when test="can-modify-acls?">
          <li><a href="<wiki:base/>/page/access/<wiki:show-page-title/>">access</a></li>
        </dsp:when>
      </ul>
    </div>

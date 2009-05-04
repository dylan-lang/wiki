<%dsp:taglib name="wiki"/>

    <div id="menu">
      <span>options</span>
      <ul>
	<li><a href="<wiki:show-user-permanent-link/>">view</a></li>
        <dsp:when test="can-modify-user?">
	  <li><a href="<wiki:show-user-permanent-link/>/edit">edit</a></li>
          <li><a href="<wiki:show-user-permanent-link/>/remove">remove</a></li>
	</dsp:when>
      </ul>
    </div>

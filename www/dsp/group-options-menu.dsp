<%dsp:taglib name="wiki"/>

    <div id="menu">
      <span>options</span>
      <ul>
	<li><a href="<wiki:show-group-permanent-link/>">view</a></li>
        <dsp:when test="can-modify-group?">
	  <li><a href="<wiki:show-group-permanent-link/>/edit">edit</a></li>
          <li><a href="<wiki:show-group-permanent-link/>/members">members</a></li>
          <li><a href="<wiki:show-group-permanent-link/>/remove">remove</a></li>
	</dsp:when>
      </ul>
    </div>

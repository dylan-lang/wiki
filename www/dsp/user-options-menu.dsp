<%dsp:taglib name="wiki"/>

    <div id="menu">
      <span>options</span>
      <ul>
	<li><a href="/users/<dsp:get name='user-name'/>">view</a></li>
        <dsp:when test="can-modify-user?">
	  <li><a href="/users/<dsp:get name='user-name'/>/edit">edit</a></li>
          <li><a href="/users/<dsp:get name='user-name'/>/remove">remove</a></li>
	</dsp:when>
      </ul>
    </div>

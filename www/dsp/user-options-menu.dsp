<%dsp:taglib name="wiki"/>

    <div id="menu">
      <span>options</span>
      <ul>
	<li><a href="<wiki:base/>/user/view/<dsp:get name='user-name'/>">view</a></li>
        <dsp:when test="can-modify-user?">
	  <li><a href="<wiki:base/>/user/edit/<dsp:get name='user-name'/>">edit</a></li>
          <li><a href="<wiki:base/>/user/remove/<dsp:get name='user-name'/>">remove</a></li>
	</dsp:when>
      </ul>
    </div>

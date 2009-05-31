
    <div id="menu">
      <span>options</span>
      <ul>
        <li><a href="/groups/<dsp:get name="group-name"/>">view</a></li>
        <dsp:when test="can-modify-group?">
          <li><a href="/groups/<dsp:get name="group-name"/>/edit">edit</a></li>
          <li><a href="/groups/<dsp:get name="group-name"/>/members">members</a></li>
          <li><a href="/groups/<dsp:get name="group-name"/>/remove">remove</a></li>
        </dsp:when>
      </ul>
    </div>

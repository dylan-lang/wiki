
    <div id="menu">
      <span>options</span>
      <ul>
        <li><a href="<wiki:base/>/group/view/<dsp:get name="group-name"/>">view</a></li>
        <dsp:when test="can-modify-group?">
          <li><a href="<wiki:base/>/group/edit/<dsp:get name="group-name"/>">edit</a></li>
          <li><a href="<wiki:base/>/group/members/<dsp:get name="group-name"/>/members">members</a></li>
          <li><a href="<wiki:base/>/group/remove/<dsp:get name="group-name"/>/remove">remove</a></li>
        </dsp:when>
      </ul>
    </div>

<%dsp:taglib name="web-framework" prefix="wf"/>
<%dsp:taglib name="wiki"/>

      <dsp:get name="group-description"/>

      <h3>Members</h3>
      <dsp:when test="exists?" name="active-user">
        <dsp:loop over="group-members" context="page" var="user-name" header="<ul>" footer="</ul>">
          <li>
            <a href="<wiki:base/>/user/view/<dsp:get name='user-name' context='page'/>">
            <dsp:get name="user-name" context="page"/></a>
            <dsp:if-equal name1="user-name" name2="active-user">(you)</dsp:if-equal>
            <dsp:if-equal name1="user-name" name2="group-owner">(group owner)</dsp:if-equal>
          </li>
        </dsp:loop>
      </dsp:when>
      <dsp:unless test="exists?" name="active-user">
        You must login to view group members.
      </dsp:unless>

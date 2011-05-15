<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Recent Changes</title>
  <%dsp:include url="meta.dsp"/>
  <link rel="alternate"
        type="application/atom+xml"
        title="All Dylan Wiki Changes"
        href="<wiki:base/>/feed" />
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">               
      <h2>Recent Changes <a href="<wiki:base/>/feed"><img border="0" src="<wiki:base/>/static/images/feed-icon-14x14.png" alt="Atom feed for all wiki changes"/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:show-page-links name="recent-changes" url="<wiki:base/>/recent-changes?page=" query-value="page"/>

      <wiki:list-recent-changes>
        <dsp:if-not-equal name1="day" name2="previous-day">
          <h3><span class="date"><dsp:get name="day"/></span></h3>
        </dsp:if-not-equal>
        <dl id="changes">
          <dt>
            <span class="time"><dsp:get name="time"/></span>
            <span class="object <dsp:get name='object-type'/>">
              <a href="<dsp:get name='newest-url'/>"><dsp:get name="title"/></a>
            </span>

            <dsp:get name="verb"/>

            by <a href="<wiki:base/>/user/view/<dsp:get name='author'/>"><dsp:get name="author"/></a>

            <!-- only page changes show these links for now -->
            <dsp:if-equal name1="object-type" name2="page" context2="literal">
              <dsp:if-not-equal name1="action" name2="delete" context2="literal">
                &mdash;
                <a href="<dsp:get name='revision-url'/>">revision</a>,
                <a href="<dsp:get name='diff-url'/>">diff</a>
              </dsp:if-not-equal>
            </dsp:if-equal>

          </dt>
          <dd>
            <dsp:get name="comment"/>
          </dd>
        </dl>
      </wiki:list-recent-changes>

      <dsp:show-page-links name="recent-changes" url="<wiki:base/>/recent-changes?page=" query-value="page"/>

    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

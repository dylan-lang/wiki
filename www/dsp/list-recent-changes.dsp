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
      <h2>Recent Changes <a href="<wiki:base/>/feed"><img border="0" src="/images/feed-icon-14x14.png" alt="Atom feed for all wiki changes"/></a></h2>

      <dsp:show-page-errors/>
      <dsp:show-page-notes/>

      <dsp:show-page-links name="recent-changes" url="/wiki/recent-changes?page=" query-value="page"/>

      <wiki:list-recent-changes>
        <dsp:if-not-equal name1="day" name2="previous-day">
	  <h3><span class="date"><dsp:get name="day"/></span></h3>
        </dsp:if-not-equal>
	<dl id="changes">
	  <dt>
	    <span class="time"><dsp:get name="time"/></span>
	    <span class="object <dsp:get name='change-class'/>">
	      <a href="<dsp:get name='permalink'/>"><dsp:get name="title"/></a>
	    </span>

            <!-- special case for page changes -->
            <dsp:if-equal name1="change-class" name2="page" context2="literal">
	      <dsp:if-not-equal name1="action" name2="removal" context2="literal">
		[<a href="<dsp:get name='permalink'/>/versions/<dsp:get name='version'/>"><dsp:get name="version"/></a>]
	      </dsp:if-not-equal>
	      <dsp:if-equal name1="action" name2="edit" context2="literal">
		<a href="<dsp:get name='permalink'/>/versions/<dsp:get name='version'/>?diff"><dsp:get name="verb"/></a> 
              </dsp:if-equal>
	      <dsp:if-not-equal name1="action" name2="edit" context2="literal">
                <dsp:get name="verb"/>
              </dsp:if-not-equal>
            </dsp:if-equal>

            <!-- non-page (i.e., user and group) changes -->
            <dsp:if-not-equal name1="change-class" name2="page" context2="literal">
	      <dsp:get name="verb"/>
            </dsp:if-not-equal>

            by <a href="<wiki:base/>/users/<dsp:get name='author'/>"><dsp:get name="author"/></a>

	  </dt>
	  <dd>
	    <dsp:get name="comment"/>
	  </dd>
	</dl>
      </wiki:list-recent-changes>

      <dsp:show-page-links name="recent-changes" url="/wiki/recent-changes?page=" query-value="page"/>

    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

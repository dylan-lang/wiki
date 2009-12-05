<%dsp:taglib name="wiki"/>

      <dsp:if test="can-view-content?">
        <dsp:then>
          <wiki:show-page-content content-format="xhtml"/>
          <dsp:loop over="page-tags" var="tag" header="<hl/><h3>Tags:</h3>">
            <dsp:get name="tag"/>
            <a href="<wiki:base/>/feed/tags/<dsp:get name='tag'/>">
              <img border="0" src="/images/feed-icon-14x14.png" alt="Atom feed for this tag"/>
            </a>
            <dsp:unless test="loop-end?">, </dsp:unless>
          </dsp:loop>
        </dsp:then>
        <dsp:else>
          You do not have permission to view this page.
        </dsp:else>
      </dsp:if>

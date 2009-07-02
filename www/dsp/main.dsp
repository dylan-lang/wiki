<%dsp:include url="xhtml-start.dsp"/>
<%dsp:taglib name="wiki"/>
<head>
  <title>Dylan Wiki: Home</title>
  <%dsp:include url="meta.dsp"/>
  <link rel="alternate"
        type="application/atom+xml"
        title="Dylan Wiki Atom Feed"
        href="/feed" />
</head>
<body>
  <%dsp:include url="header.dsp"/>
  <div id="content">
    <%dsp:include url="navigation.dsp"/>
    <div id="body">
      <h2>Overview</h2>
      <blockquote title="Peter Hinely about Dylan">
        <p>
          Dylan is an advanced, object-oriented, dynamic language which supports
          rapid program development.  When needed, programs can be optimized for more
          efficient execution by supplying more type information to the compiler.  Nearly
          all entities in Dylan (including functions, classes, and basic data types such
          as integers) are first class objects. Additionally Dylan supports multiple
          inheritance, polymorphism, multiple dispatch, keyword arguments, object
          introspection, macros, and many other advanced features &hellip; 
        </p>
      </blockquote>
      <cite>Peter Hinely</cite>
      <hr/>
      <p>
        More information about
        the <a href="/books/drm/Background_and_Goals.html">background
        and goals</a> of the Dylan language are available in
        the <a href="/books/drm/Title">Dylan Reference Manual</a>.
        To get a quick feel of the language have a look at
        some <a href="/pages/Fragments">code examples</a>.
      </p>
      <p>
        We currently maintain
        two <a href="/pages/Implementations">implementations</a> of
        Dylan and we're working on a number
        of <a href="/pages/Projects">projects</a>.
      </p>
      <p>Please feel free to <a href="/pages/Community">join us</a>!</p> 

      <h2>News <a href="/feed/tags/news"><img border="0" src="/images/feed-icon-14x14.png" alt="Atom feed for news"/></a></h2>
      <wiki:list-pages tags="news" order-by="published">
        <h3 class="news summary"><a href="<wiki:show-page-permanent-link/>"><wiki:show-page-title/></a></h3>
        <small class="date"><wiki:show-page-published formatted="%d. %B %Y %H:%M"/></small>
        <wiki:show-page-content format="markup"/>
      </wiki:list-pages>

    </div>
  </div>
  <%dsp:include url="footer.dsp"/>
</body>
</html>

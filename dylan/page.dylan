Module: wiki-internal

define thread variable *page-title* = #f;

// Represents a user-editable wiki page that will be stored by web-framework.
// Not to be confused with <wiki-dsp>, which is a DSP maintained in our
// source code tree.
//
define class <wiki-page> (<entry>)
  slot page-owner :: <wiki-user>,
    required-init-keyword: owner:;
  slot access-controls :: <acls> = $default-access-controls,
    init-keyword: access-controls:;
  slot page-versions :: <vector> = #[],
    init-keyword: versions:;
end;

define wf/object-tests
    (page, version, other-version, diff-version, diff-other-version)
in wiki end;

/*
define wf/action-tests
 (view-page, edit-page,
  remove-page, view-versions)
in wiki end;
*/

define wf/error-test (title) in wiki end;



// storage

define method storage-type
    (type == <wiki-page>)
 => (type :: <type>);
  <string-table>;
end;

// Tells web-framework under what unique (I assume) key to store this object.
//
define inline-only method key
    (page :: <wiki-page>)
 => (res :: <string>)
  page.title
end;


// url

define method permanent-link
    (page :: <wiki-page>, #key escaped?, full?)
 => (url :: <url>)
  page-permanent-link(key(page))
end;

define method page-permanent-link
    (title :: <string>)
 => (url :: <url>)
  let location = wiki-url("/page/view/%s", title);
  transform-uris(request-url(current-request()), location, as: <url>)
end;

define method redirect-to (page :: <wiki-page>)
  redirect-to(permanent-link(page));
end;


// methods

define method find-page
    (title :: <string>)
 => (page :: false-or(<wiki-page>))
  element(storage(<wiki-page>), title, default: #f)
end;

define method add-author
    (page :: <wiki-page>, user :: <user>)
 => (user :: <user>)
  page.authors := add-new!(page.authors, user,
                           test: method (user1, user2)
                                   user1.user-name = user2.user-name
                                 end);
  user
end method add-author;

// todo -- Do this as a wiki page.
define constant $reserved-tags :: <sequence> = #["news"];

define method reserved-tag?
    (tag :: <string>) => (reserved? :: <boolean>)
  member?(tag, $reserved-tags, test: \=)
end;

define method save-page
    (title :: <string>, content :: <string>, 
     #key comment :: <string> = "", tags :: false-or(<sequence>))
 => ()
  let page :: false-or(<wiki-page>) = find-page(title);
  let action :: <symbol> = $edit;
  let author :: <wiki-user> = authenticated-user();
  if (~page)
    page := make(<wiki-page>, title: title, owner: author);
    action := $create;
  end;
  save-page-internal(page, content, comment, tags, author, action);
  dump-data();
  block ()
    generate-connections-graph(page);
  exception (ex :: <serious-condition>)
    // we don't care about the graph (yet?)
    // maybe the server doesn't have "dot" installed.
    log-error("Error generating connections graph for page %s: %s",
              title, ex);
  end;
end method save-page;

// This is separated out so it can be used for the conversion from the
// old wiki to new.
define method save-page-internal
    (page :: <wiki-page>, content :: <string>, comment :: <string>,
     tags :: <sequence>, author :: <wiki-user>, action :: <symbol>,
     #key published :: false-or(<date>))
  let title = page.title;
  let version-number :: <integer> = size(page.page-versions) + 1;
  if (version-number = 1
        | content ~= page.latest-text
        | tags ~= page.latest-tags)
    let date-published = published | current-date();
    let version = make(<wiki-page-version>,
                       content: make(<raw-content>, content: content),
                       authors: list(author),
                       version: version-number,
                       page: page,
		       categories: tags & as(<vector>, tags),
                       published: date-published);
    let comment = make(<comment>,
                       name: as(<string>, action),
                       authors: list(author.user-name),
                       content: make(<raw-content>, content: comment));
    version.comments[0] := comment;
    version.references := extract-references(version);
    add-author(page, author);
    with-storage (pages = <wiki-page>)
      page.page-versions := add!(page.page-versions, version);
    end;
    let change = make(<wiki-page-change>,
                      title: title,
                      version: version-number, 
                      action: action,
                      authors: list(author.user-name),
                      published: date-published);
    change.comments[0] := comment;
    save(page);
    save(change);
  end if;
end method save-page-internal;

define method generate-connections-graph (page :: <wiki-page>) => ();
  let graph = make(gvr/<graph>);
  let node = gvr/create-node(graph, label: page.title);
  let backlinks = find-backlinks(page);
  backlinks := map(title, backlinks);
  gvr/add-predecessors(node, backlinks);
  gvr/add-successors(node, last(page.page-versions).references);
  for (node in gvr/nodes(graph))
    node.gvr/attributes["URL"] := build-uri(page-permanent-link(node.gvr/label));
    node.gvr/attributes["color"] := "blue";
    node.gvr/attributes["style"] := "filled";
    node.gvr/attributes["fontname"] := "Verdana"; 
    node.gvr/attributes["shape"] := "note";
  end for;
  let temporary-graph = gvr/generate-graph(graph, node, format: "svg");
  let graph-file = as(<file-locator>, temporary-graph);
  if (file-exists?(graph-file))
    let destination = as(<file-locator>, concatenate("graphs/", page.title, ".svg"));
    rename-file(graph-file, destination, if-exists: #"replace");
  end if;
end;

define method extract-references
    (version :: <wiki-page-version>)
 => (references :: <sequence>);
  let references = list();
  //TODO: replace by upcoming regex-search-all-strings
  let content = version.content.content;
  let regex = "\\[\\[([^\\]]*)\\]\\]";
  let start = 0;
  while (regex-position(regex, content, start: start))
    let (#rest matches) = regex-search-strings(regex, copy-sequence(content, start: start));
    if (first(matches))
      references := add!(references, second(matches));
    end if;
    let (#rest positions) = regex-position(regex, content, start: start);
    start := last(positions) | size(content);
  end while;
  references;
end;

define method remove-page
    (page :: <wiki-page>,
     #key comment :: <string> = "")
 => ();
  save-change(<wiki-page-change>, page.title, $remove, comment);
  remove-key!(storage(<wiki-page>), page.title);
  dump-data();
end;

define method rename-page
    (title :: <string>, new-title :: <string>,
     #key comment :: <string> = "")
 => ();
  let page = find-page(title);
  if (page)
    rename-page(page, new-title, comment: comment)
  end if;
end;

define method rename-page
    (page :: <wiki-page>, new-title :: <string>,
     #key comment :: <string> = "")
 => ();
  let comment = concatenate("was: ", page.title, ". ", comment);
  remove-key!(storage(<wiki-page>), page.title);
  page.title := new-title;
  storage(<wiki-page>)[new-title] := page;
  save-change(<wiki-page-change>, new-title, $rename, comment);
  save(page);
  dump-data();
end;


define generic find-backlinks
    (object :: <object>)
 => (backlinks :: <stretchy-vector>); 

define method find-backlinks
    (page :: <wiki-page>)
 => (backlinks :: <stretchy-vector>);
  find-backlinks(page.title);
end;

define method find-backlinks
    (title :: <string>)
 => (backlinks :: <stretchy-vector>);
  let backlinks = make(<stretchy-vector>);
  for (page-title in sort(key-sequence(storage(<wiki-page>))))
    let page = find-page(page-title);
    if (page & member?(title, last(page.page-versions).references, test: \=))
      backlinks := add!(backlinks, page);
    end if;
  end for; 
  backlinks;
end;

define method discussion-page?
    (page :: <wiki-page>)
 => (is? :: <boolean>)
  let (matched?, discussion, title)
    = regex-search-strings("(Discussion: )(.*)", page.title);
  matched? = #t;
end;

define function redirect-content?
    (content :: <string>)
 => (content :: false-or(<string>), 
     title :: false-or(<string>))
  let (content, title) = 
    regex-search-strings("^#REDIRECT \\[\\[(.*)\\]\\]",
			 content);
  values(content, title);
end;

define method latest-text
    (page :: <wiki-page>)
 => (text :: <string>)
  page.page-versions.last.content.content
end;

define method latest-tags
    (page :: <wiki-page>)
 => (tags :: <sequence>)
  page.page-versions.last.categories
end;

define method latest-authors
    (page :: <wiki-page>)
 => (authors :: <sequence>)
  page.page-versions.last.authors
end;



//// List Page Versions

define class <page-versions-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <page-versions-page>, #key title :: <string>)
  let wiki-page = find-page(percent-decode(title));
  if (wiki-page)
    set-attribute(page-context(), "title", percent-decode(title));
    set-attribute(page-context(), "page-versions",
                  if (wiki-page)
                    reverse(wiki-page.page-versions)
                  else
                    #()
                  end);
    next-method()
  else
    respond-to-get(*non-existing-page-page*, title: title);
  end;
end;

define body tag list-page-versions in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  for (version in get-attribute(page-context(), "page-versions"))
    let pc = page-context();
    set-attribute(pc, "author", version.authors.last.user-name);
    // todo -- make date format and TZ a user setting.
    set-attribute(pc, "published",
                  format-date("%e %b %Y %H:%M:%S", version.date-published));
    let comment = version.comments[0].content.content;
    if (~comment | comment.empty?)
      comment := "no comment";
    end;
    set-attribute(pc, "comment", comment);
    set-attribute(pc, "version-number", version.version-number);
    do-body();
  end;
end tag list-page-versions;


//// Page connections (backlinks)

define class <connections-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <connections-page>, #key title :: <string>)
  let title = percent-decode(title);
  dynamic-bind (*page* = find-page(title))
    if (*page*)
      next-method();
    else
      respond-to-get(*non-existing-page-page*, title: title);
    end;
  end;
end method respond-to-get;

define body tag list-page-backlinks in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  let backlinks = find-backlinks(*page*);
  if (empty?(backlinks))
    output("There are no connections to this page.");
  else
    for (backlink in backlinks)
      set-attribute(page-context(), "backlink", backlink.title);
      set-attribute(page-context(), "backlink-url", permanent-link(backlink));
      do-body();
    end for;
  end if;
end;


define class <list-pages-page> (<wiki-dsp>) end;

define method respond-to-get
    (dsp :: <list-pages-page>, #key)
  if (get-query-value("go"))
    redirect-to(page-permanent-link(get-query-value("query")));
  else
    let pc = page-context();
    local method page-info (page :: <wiki-page>)
            table(<string-table>,
                  "title" => page.title,
                  "when-published" => standard-date-and-time(page.date-published),
                  "latest-authors" => join(map(user-name, page.latest-authors), ", "))
          end;
    let current-page = get-query-value("page", as: <integer>) | 1;
    let paginator = make(<paginator>,
                         sequence: map(page-info, find-pages()),
                         page-size: 25,
                         current-page-number: current-page);
    set-attribute(pc, "wiki-pages", paginator);
    next-method();
  end;
end method respond-to-get;

define method do-remove-page (#key title)
  let page = find-page(percent-decode(title));
  remove-page(page, comment: get-query-value("comment"));
  redirect-to(page);
end;

// Provide backward compatibility with old wiki URLs
// /wiki/view.dsp?title=t&version=v
// 
define method show-page-back-compatible
    (#key)
  with-query-values (title, version)
    let title = percent-decode(title);
    let version = version & percent-decode(version);
    let default = current-request().request-absolute-url;
    let url = make(<url>,
                   scheme: default.uri-scheme,
                   host: default.uri-host,
                   port: default.uri-port,
                   // No, I don't understand the empty string either.
                   path: concatenate(list("", "pages", title),
                                     iff(version,
                                         list("versions", version),
                                         #())));
    let location = as(<string>, url);
    moved-permanently-redirect(location: location,
                               header-name: "Location",
                               header-value: location);
  end;
end;

define method show-page-responder
    (#key title :: <string>, version)
  let title = percent-decode(title);
  let page = find-page(title);
  let version = if (page & version)
                  element(page.page-versions, string-to-integer(version) - 1,
                          default: #f);
                end if;
  dynamic-bind (*page* = page,
                *version* = version,
                *page-title* = title)
    respond-to-get(case
                     *page* => *view-page-page*;
                     authenticated-user() => *edit-page-page*;
                     otherwise => *non-existing-page-page*;
                   end,
                   title: title);
  end;
end method show-page-responder;

define class <edit-page-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <edit-page-page>, #key title :: <string>, previewing?)
  let title = percent-decode(title);
  if (authenticated-user())
    set-attribute(page-context(), "title", title);
    set-attribute(page-context(), "previewing?", previewing?);
    dynamic-bind (*page* = find-page(title))
      if (*page*)
        let content = get-query-value("content")
                        | *page*.page-versions.last.content.content;
        let pc = page-context();
        set-attribute(pc, "content", content);
        set-attribute(pc, "owner", *page*.page-owner);
        set-attribute(pc, "tags", unparse-tags(*page*.latest-tags));
      end;
      next-method();
    end;
  else
    // This shouldn't happen unless the user typed in the /edit url,
    // since the edit option shouldn't be available unless logged in.
    add-page-error("You must be logged in to edit wiki pages.");
    respond-to-get(*view-page-page*, title: title);
  end;
end method respond-to-get;

define method respond-to-post
    (wiki-dsp :: <edit-page-page>, #key title :: <string>)
  let title = percent-decode(title);
  let page = find-page(title);
  with-query-values (title as new-title, content, comment, tags, button)
    let tags = iff(tags, parse-tags(tags), #[]);
    let new-title = new-title & trim(new-title);

    // Handle page renaming.
    // todo -- potential race conditions here.  Should really lock the old and
    //         new pages around the find-page and rename-page. Low priority now.
    if (new-title & ~empty?(new-title) & new-title ~= title)
      if (find-page(new-title))
        add-field-error("title", "A page with this title already exists.");
      else
        title := new-title;
        page & rename-page(page, new-title, comment: comment);
      end;
    end;

    let author :: <wiki-user> = authenticated-user();
    if (page & ~has-permission?(author, page, $modify-content))
      add-page-error("You do not have permission to edit this page.");
    end;

    let reserved-tags = choose(reserved-tag?, tags);
    if (~empty?(reserved-tags) & ~administrator?(author))
      add-field-error("tags", "The tag%s %s %s reserved for administrator use.",
                      iff(reserved-tags.size = 1, "", "s"),
                      join(tags, ", ", conjunction: " and "),
                      iff(reserved-tags.size = 1, "is", "are"));
    end;

    let previewing? = (button = "Preview");
    if (previewing? | page-has-errors?())
      // Redisplay the page with errors highlighted.
      respond-to-get(*edit-page-page*, title: title, previewing?: #t);
    else
      save-page(title, content | "", comment: comment, tags: tags);
      redirect-to(find-page(title));
    end;
  end;
end method respond-to-post;

define class <view-diff-page> (<wiki-dsp>) end;

// /Title/diff/n  diffs versions n - 1 and n.
// /Title/diff/n/m diffs versions n and m.
// Note that in the first case n is the newer version and in the latter
// case n is the older version.
//
define method respond-to-get
    (page :: <view-diff-page>,
     #key title :: <string>,
          version1 :: <string>,
          version2 :: false-or(<string>))
  let title = percent-decode(title);
  dynamic-bind (*page* = find-page(title))  // only for <show-page-title/>
    if (*page*)
      block (return)
        let pc = page-context();
        let ix1 = string-to-integer(version1) - 1;
        let ix2 = iff(version2, string-to-integer(version2) - 1, ix1 - 1);
        let (ix1, ix2) = values(min(ix1, ix2), max(ix1, ix2));
        set-attribute(pc, "version1", ix1 + 1);
        set-attribute(pc, "version2", ix2 + 1);
        let old-rev = element(*page*.page-versions, ix1, default: #f);
        let new-rev = element(*page*.page-versions, ix2, default: #f);
        if (~old-rev)
          add-page-error("%s revision #%s does not exist.", title, ix1 + 1);
        end;
        if (~new-rev)
          add-page-error("%s revision #%s does not exist.", title, ix2 + 1);
        end;
        if (old-rev & new-rev)
          let seq1 = split(old-rev.content.content, '\n');
          let seq2 = split(new-rev.content.content, '\n');
          set-attribute(pc, "diffs", sequence-diff(seq1, seq2));
          // sequence-diff doesn't hang onto the actual lines, only indexes,
          // so store them too...
          set-attribute(pc, "seq1", seq1);
          set-attribute(pc, "seq2", seq2);
        end;
      exception (ex :: <error>)
        add-page-error("Invalid version number: %s", ex);
      end;
    else
      add-page-error("The page does not exist: %s", title);
    end;
    next-method();
  end;
end method respond-to-get;

define method print-diff-entry
    (entry :: <insert-entry>, seq1 :: <sequence>, seq2 :: <sequence>)
  let lineno1 = entry.source-index + 1;
  let lineno2 = entry.element-count + entry.source-index;
  if (lineno1 = lineno2)
    output("Added line %d:<br/>", lineno1);
  else
    output("Added lines %d - %d:<br/>", lineno1, lineno2);
  end;
  for (line in copy-sequence(seq2, start: lineno1 - 1, end: lineno2),
       lineno from lineno1)
    output("%d: %s<br/>", lineno, line);
  end;
end method print-diff-entry;
  
define method print-diff-entry
    (entry :: <delete-entry>, seq1 :: <sequence>, seq2 :: <sequence>)
  let lineno1 = entry.dest-index + 1;
  let lineno2 = entry.element-count + entry.dest-index;
  if (lineno1 = lineno2)
    output("Removed line %d:<br/>", lineno1);
  else
    output("Removed lines %d - %d:<br/>", lineno1, lineno2);
  end;
  for (line in copy-sequence(seq1, start: lineno1 - 1, end: lineno2),
       lineno from lineno1)
    output("%d: %s<br/>", lineno, line);
  end;
end method print-diff-entry;

define tag show-diff-entry in wiki
    (page :: <view-diff-page>)
    (name :: <string>)
  let pc = page-context();
  let entry = get-attribute(pc, name);
  let seq1 = get-attribute(pc, "seq1");
  let seq2 = get-attribute(pc, "seq2");
  print-diff-entry(entry, seq1, seq2);
end tag show-diff-entry;


define method redirect-to-page-or
    (page :: <wiki-dsp>, #key title :: <string>)
  let title = percent-decode(title);
  dynamic-bind (*page* = find-page(title))
    if (*page*)
      respond-to-get(page);
    else
      redirect-to(page-permanent-link(title));
    end if;
  end;
end method redirect-to-page-or;

define constant show-page-authors =
  curry(redirect-to-page-or, *page-authors-page*);

define constant show-remove-page =
  curry(redirect-to-page-or, *remove-page-page*);


// tags

define tag show-page-permanent-link in wiki
    (page :: <wiki-dsp>)
    ()
  if (*page*)
    output("%s", permanent-link(*page*))
  end;
end;

// Show the title of the main page corresponding to a discussion page.
define tag show-main-page-title in wiki
    (page :: <wiki-dsp>) ()
  if (*page*)
    let main-title = regex-replace(*page*.title, "^Discussion: ", "");
    output("%s", escape-xml(main-title));
  end;
end tag show-main-page-title;

// Show the title of the discussion page corresponding to a main page.
define tag show-discussion-page-title in wiki
    (page :: <wiki-dsp>) ()
  if (*page*)
    let discuss-title = concatenate("Discussion: ", *page*.title);
    output("%s", escape-xml(discuss-title));
  end;
end tag show-discussion-page-title;

define tag show-page-title in wiki
    (page :: <wiki-dsp>)
    ()
  if (*page*)
    output("%s", escape-xml(*page-title* | *page*.title));
  end;
end;

define tag show-page-owner in wiki
    (page :: <wiki-dsp>)
    ()
  if (*page*)
    output("%s", escape-xml(*page*.page-owner.user-name))
  end;
end;

define tag show-page-content in wiki
    (page :: <wiki-dsp>)
    (content-format :: false-or(<string>))
  let raw-content
    = if (get-attribute(page-context(), "content"))
        get-attribute(page-context(), "content")
      elseif (*page*)
        (*version* | *page*.page-versions.last).content.content
      elseif (wf/*form* & element(wf/*form*, "content", default: #f))
        wf/*form*["content"];
      else
        ""
      end if;
  case
    content-format = "xhtml"
      => output("%s", wiki-markup-to-html(raw-content)); // parse-wiki-markup(content);
    otherwise
      => output("%s", raw-content);
  end case;
end;

define tag show-version in wiki
    (page :: <wiki-dsp>)
    ()
  output("%s", *version* | "");
end;


// body tags 

define body tag list-page-tags in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    // Is it correct to be using the tags from the newest page version?
    // At least this DSP tag should be called show-latest-page-tags ...
    for (tag in latest-tags(*page*))
      dynamic-bind(*tag* = tag)
        do-body();
      end;
    end for;
  elseif (wf/*form* & element(wf/*form*, "tags", default: #f))
    output("%s", escape-xml(wf/*form*["tags"]));
  end if;
end;

define method more-recently-published?
    (page1 :: <wiki-page>, page2 :: <wiki-page>)
  page1.date-published > page2.date-published
end;

define method find-pages
    (#key tags :: <sequence> = #[],  // strings
          order-by :: <function> = more-recently-published?)
 => (pages :: <sequence>)
   let pages = value-sequence(storage(<wiki-page>));
   if (~empty?(tags))
     pages := choose(method (page)
                       every?(rcurry(member?, page.page-versions.last.categories,
                                     test:, \=),
                              tags)
                     end,
                     pages);
   end;
   if (order-by)
     pages := sort(pages, test: order-by);
   end;
   pages
end method find-pages;

// This is only used is main.dsp now, and only for news.
// May want to make a special one for news instead.
define body tag list-pages in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    (tags :: false-or(<string>),
     order-by :: false-or(<string>),
     use-query-tags :: <boolean>)
   let tagged = get-query-value("tagged");
   tags := if (use-query-tags & instance?(tagged, <string>))
             parse-tags(tagged);
           elseif (tags)
             parse-tags(tags);
           end if;
  for (page in find-pages(tags: tags | #[]))
    dynamic-bind(*page* = page)
      do-body();
    end;
  end for;
end;

define body tag list-page-authors in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    for (author in *page*.authors)
      dynamic-bind(*user* = author)
        do-body();
      end;
    end for;
  end if;
end;


// named methods

define named-method is-discussion-page? in wiki
    (page :: <wiki-dsp>)
  *page* & discussion-page?(*page*);
end;

define named-method latest-page-version? in wiki
    (page :: <wiki-dsp>)
  *page* & (~*version* | *page*.page-versions.last = *version*)
end;

define named-method page-tags in wiki
    (page :: <wiki-dsp>)
  // todo -- show tags for the specific page version being displayed!
  *page* & sort(*page*.latest-tags) | #[]
end;


//// Search

/***** We'll use Google or Yahoo custom search, at least for a while

define class <search-page> (<wiki-dsp>)
end;

// Called when the search form is submitted.
//
define method respond-to-post
    (page :: <search-page>)
  with-query-values(query, search-type, search as search?, go as go?, redirect)
    log-debug("query = %s, search-type = %s, search? = %s, go? = %s, redirect = %s",
              query, search-type, search?, go?, redirect);
    let query = trim(query);
    if (empty?(query))
      note-form-error("Please enter a search term.", field: "search-text");
      process-template(page);
    elseif (go?)
      select (as(<symbol>, search-type))
        #"page" => redirect-to(page-permanent-link(query));
        #"user" => redirect-to(user-permanent-link(query));
        #"group" => redirect-to(group-permanent-link(query));
        //#"file" => redirect-to(file-permanent-link(query));
        otherwise =>
          // go to anything with the exact name given
          let thing = find-user(query) | find-page(query)
                        | find-group(query) /* | find-file(query) */ ;
          if (thing)
            redirect-to(permanent-link(thing));
          else
            note-form-error(format-to-string("%s not found", query),
                            field: "search-text");
            process-template(page);
          end if;
      end select;
    end if;
  end;
end method respond-to-post;

*/


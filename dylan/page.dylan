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
 => (url :: <url>);
  page-permanent-link(key(page));
end;

define method page-permanent-link
    (title :: <string>)
 => (url :: <url>);
  let location = wiki-url("/pages/%s", title);
  transform-uris(request-url(current-request()), location, as: <url>);
end;

define method redirect-to (page :: <wiki-page>)
  redirect-to(permanent-link(page));
end;


// methods

define method find-page
    (title :: <string>)
 => (page :: false-or(<wiki-page>));
  element(storage(<wiki-page>), title, default: #f);
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
  if (page)
    if (~has-permission?(author, page, $modify-content))
      add-page-error("You do not have permission to edit this page.");
    end;
  else
    page := make(<wiki-page>,
                 title: title,
                 owner: author);
    action := $create;
  end;

  let reserved-tags = choose(reserved-tag?, tags);
  if (~empty?(reserved-tags) & ~administrator?(author))
    add-field-error("tags", "The tag%s %s %s reserved for administrator use.",
                    iff(reserved-tags.size = 1, "", "s"),
                    join(tags, ", ", conjunction: " and "),
                    iff(reserved-tags.size = 1, "is", "are"));
  end;
  if (page-has-errors?())
    respond-to-get($view-page-page, title: title);
  else
    save-page-internal(page, content, comment, tags, author, action);
    dump-data();
    generate-connections-graph(page);
  end;
end method save-page;

// This is separated out so it can be used for the conversion from the
// old wiki to new.
define method save-page-internal
    (page :: <wiki-page>, content :: <string>, comment :: <string>,
     tags :: <sequence>, author :: <wiki-user>, action :: <symbol>)
  let title = page.title;
  let version-number :: <integer> = size(page.page-versions) + 1;
  if (version-number = 1
        | content ~= page.latest-text
        | tags ~= page.latest-tags)
    let version = make(<wiki-page-version>,
                       content: make(<raw-content>, content: content),
                       authors: list(author),
                       version: version-number,
                       page: page,
		       categories: tags & as(<vector>, tags));
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
                      authors: list(author.user-name));
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
    let destination = merge-locators(as(<file-locator>, 
					concatenate("graphs/", page.title, ".svg")),
  				     document-root(virtual-host(current-request())));
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

define method diff
    (version-a :: <wiki-page-version>, version-b :: <wiki-page-version>)
 => (diff-a :: <sequence>, diff-b :: <sequence>);
  let lines-a = split(version-a.content.content, "\n");
  let lines-b = split(version-b.content.content, "\n");
  let diff-a = make(<stretchy-vector>);
  let diff-b = make(<stretchy-vector>);
/*
  for (line-a in lines-a, line-b in lines-b, i from 0)
    if (line-a ~= line-b)
      let line-b-in-a = find-key(lines-a, method (line) line = line-b end, skip: i);
      let line-a-in-b = find-key(lines-b, method (line) line = line-a end, skip: i);
      if (line-b-in-a & ~line-a-in-b)
        format-out("removed in version b:\n%s\n\n", line-a);
      elseif (~line-b-in-a & line-a-in-b)
        format-out("added in version b:\n%s\n\n", line-b);
//      else if ()
//        //modified?
      end if;
    end if;
  end for;
*/
  values(diff-a, diff-b);
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
 => (text :: <string>);
  page.page-versions.last.content.content
end;

define method latest-tags
    (page :: <wiki-page>)
 => (tags :: <sequence>)
  page.page-versions.last.categories
end;


// pages

define constant $view-page-page
  = make(<wiki-dsp>, source: "view-page.dsp");

define constant $view-diff-page
  = make(<wiki-dsp>, source: "view-diff.dsp");

define constant $remove-page-page
  = make (<wiki-dsp>, source: "remove-page.dsp");

define constant $list-pages-page
  = make(<wiki-dsp>, source: "list-pages.dsp");

define constant $page-authors-page
  = make(<wiki-dsp>, source: "page-authors.dsp");

define constant $search-page
  = make(<wiki-dsp>, source: "search-page.dsp");

define constant $non-existing-page-page
  = make(<wiki-dsp>, source: "non-existing-page.dsp");



//// List Page Versions

define class <page-versions-page> (<wiki-dsp>)
end;

define constant $page-versions-page
  = make(<page-versions-page>, source: "list-page-versions.dsp");

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
    respond-to-get($non-existing-page-page, title: title);
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

define constant $connections-page
  = make(<connections-page>, source: "page-connections.dsp");

define method respond-to-get
    (page :: <connections-page>, #key title :: <string>)
  let title = percent-decode(title);
  dynamic-bind (*page* = find-page(title))
    if (*page*)
      next-method();
    else
      respond-to-get($non-existing-page-page, title: title);
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


define method do-pages ()
  case
    get-query-value("go") => 
      redirect-to(page-permanent-link(get-query-value("query")));
    otherwise => 
      process-page($list-pages-page);
  end;
end;

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

define method show-page (#key title :: <string>, version)
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
                     *page* => $view-page-page;
                     authenticated-user() => $edit-page-page;
                     otherwise => $non-existing-page-page;
                   end,
                   title: title);
  end;
end method show-page;

define class <edit-page-page> (<wiki-dsp>)
end;

define constant $edit-page-page
  = make(<edit-page-page>, source: "edit-page.dsp");

define method respond-to-get
    (page :: <edit-page-page>, #key title :: <string>)
  let title = percent-decode(title);
  if (authenticated-user())
    set-attribute(page-context(), "title", title);
    dynamic-bind (*page* = find-page(title))
      if (*page*)
        let content = *page*.page-versions.last.content.content;
        set-attribute(page-context(), "content", content);
        set-attribute(page-context(), "owner", *page*.page-owner);
        set-attribute(page-context(), "tags", unparse-tags(*page*.latest-tags));
      end;
      next-method();
    end;
  else
    // This shouldn't happen unless the user typed in the /edit url,
    // since the edit option shouldn't be available unless logged in.
    add-page-error("You must be logged in to edit wiki pages.");
    respond-to-get($view-page-page, title: title)
  end;
end method respond-to-get;

define method respond-to-post
    (page :: <edit-page-page>, #key title :: <string>)
  let title = percent-decode(title);
  let page = find-page(title);
  with-query-values (title as new-title, content, comment, tags)
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
        rename-page(page, new-title, comment: comment);
      end;
    end;

    if (page-has-errors?())
      // Redisplay the page with errors highlighted.
      respond-to-get($edit-page-page, title: title);
    else
      save-page(title, content | "", comment: comment, tags: tags);
      redirect-to(find-page(title));
    end if;
  end;
end method respond-to-post;

define method show-page-versions-differences (#key title :: <string>, a, b)
  dynamic-bind (*page* = find-page(percent-decode(title)))
    let version :: false-or(<wiki-page-version>)
      = block ()
          if (a)
            element(*page*.page-versions, string-to-integer(a) - 1, default: #f);
          end;
        exception (<error>)
          #f
        end;
    let other-version :: false-or(<wiki-page-version>)
      = block ()
          if (version & instance?(b, <string>))
            element(*page*.page-versions, string-to-integer(b) - 1, default: #f);
          elseif (version)
            element(*page*.page-versions, version.version-number - 2, default: #f);
          end;
        exception (<error>)
          #f
        end;
    dynamic-bind(*version* = version,
                 *other-version* = other-version)
      respond-to-get($view-diff-page);
    end;
  end;
end method show-page-versions-differences;

define method redirect-to-page-or
    (page :: <page>, #key title :: <string>)
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
  curry(redirect-to-page-or, $page-authors-page);

define constant show-remove-page =
  curry(redirect-to-page-or, $remove-page-page);


// tags

define tag show-page-permanent-link in wiki
    (page :: <wiki-dsp>)
    (use-change :: <boolean>)
  if (use-change)
    output("%s", page-permanent-link(*change*.title));
  elseif (*page*)
    output("%s", permanent-link(*page*))
  end;
end;

// rename to main-page-permalink or something
define tag show-page-page-permanent-link in wiki 
    (page :: <wiki-dsp>)
    ()
  if (*page* & discussion-page?(*page*)) 
    let link = permanent-link(*page*);
    last(link.uri-path) := regex-replace(last(link.uri-path), "^Discussion: ", "");
    output("%s", link);
  end;
end tag show-page-page-permanent-link;

define tag show-page-discussion-permanent-link in wiki
    (page :: <wiki-dsp>)
    ()
  if (*page*) 
    let link = permanent-link(*page*);
    last(link.uri-path) := concatenate("Discussion: ", last(link.uri-path));
    output("%s", link);
  end;
end tag show-page-discussion-permanent-link;

define tag show-page-title in wiki
    (page :: <wiki-dsp>)
    ()
  output("%s", escape-xml(if (*page*)
                            *page*.title
                          elseif (*page-title*)
                            *page-title*
                          else
                            ""
                          end if));
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
  output("%s", if (*page*)
                 let content = (*version* | *page*.page-versions.last).content.content;
                 case
                   content-format = "xhtml"
                     => wiki-markup-to-html(content); // parse-wiki-markup(content);
                   otherwise
                     => content; 
                 end case;
               elseif (wf/*form* & element(wf/*form*, "content", default: #f))
                 wf/*form*["content"];
               else
                 ""
               end if);
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

define method find-pages
    (#key tags :: <sequence> = #[],  // strings
          order-by :: false-or(<symbol>))
 => (pages :: <sequence>)
   let pages = map-as(<vector>, identity, storage(<wiki-page>));
   if (~empty?(tags))
     pages := choose(method (page)
                       every?(rcurry(member?, page.page-versions.last.categories,
                                     test:, \=),
                              tags)
                     end,
                     pages);
   end;
   if (order-by)
     pages := sort(pages, test: method (p1, p2)
                                  p1.date-published > p2.date-published
                                end);
   end;
   pages
end method find-pages;

define named-method all-page-titles
    (page :: <wiki-dsp>)
  map(title, find-pages())
end;

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
  for (page in find-pages(tags: tags | #[],
                          order-by: order-by & as(<symbol>, order-by)))
    dynamic-bind(*page* = page)
      do-body();
    end;
  end for;
end;

define body tag with-other-version in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    dynamic-bind(*version* = *other-version*)
      do-body();
    end;
  end if;
end;

define body tag with-diff in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    diff(*other-version*, *version*);
    dynamic-bind(*diff-version* = #f, *diff-other-version* = #f)
      do-body();
    end;
  end if;
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

define named-method page-changed? in wiki
    (page :: <wiki-dsp>)
  instance?(*change*, <wiki-page-change>)
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

define constant $search-page
  = make(<search-page>, source: "search-results.dsp");

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


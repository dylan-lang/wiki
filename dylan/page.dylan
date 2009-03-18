module: wiki-internal

define thread variable *page-title* = #f;


// class

define class <wiki-page> (<versioned-object>, <entry>)
  slot allowed-editors :: type-union(<boolean>, <sequence>) = #t,
    init-keyword: allowed-editors:;
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


// verbs

*change-verbs*[<wiki-page-change>] := 
  table(#"edit" => "edited",
	#"removal" => "removed",
	#"renaming" => "renamed",
	#"add" => "added");


// storage

define method storage-type
    (type == <wiki-page>)
 => (type :: <type>);
  <string-table>;
end;

define inline-only method key
    (page :: <wiki-page>)
 => (res :: <string>);
  page.title;
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
  let location = parse-url("/pages/");
  last(location.uri-path) := title;
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
 => (user :: <user>);
  page.authors := add-new!(page.authors, user, test: method (first, second)
      first.username = second.username
    end);
  user;
end;

define method save-page
    (title :: <string>, content :: <string>, 
     #key comment :: <string> = "", tags :: false-or(<sequence>))
 => ();
  let page :: false-or(<wiki-page>) = find-page(title);
  let action :: <symbol> = #"edit";
  unless (page)
    page := make(<wiki-page>, title: title);
    action := #"add";
  end;
  let version-number :: <integer> = size(page.versions) + 1;
  if (version-number = 1 | (content ~= page.latest-text) | tags ~= page.latest-tags)
    let version = make(<wiki-page-version>,
                       content: make(<raw-content>, content: content),
                       authors: list(authenticated-user()),
                       version: version-number,
                       page: page,
		       categories: tags & as(<vector>, tags));
    let comment = make(<comment>, name: as(<string>, action),
                       authors: list(authenticated-user().username),
                       content: make(<raw-content>, content: comment));
    version.comments[0] := comment;
    version.references := extract-references(version);
    add-author(page, authenticated-user());
    with-storage (pages = <wiki-page>)
      page.versions := add!(page.versions, version);
    end;
    let change = make(<wiki-page-change>,
                      title: title,
                      version: version-number, 
                      action: action,
                      authors: list(authenticated-user().username));
    change.comments[0] := comment;
    save(page);
    save(change);
    dump-data();
  
    generate-connections-graph(page);
  end if;
end method save-page;

define method generate-connections-graph (page :: <wiki-page>) => ();
  let graph = make(gvr/<graph>);
  let node = gvr/create-node(graph, label: page.title);
  let backlinks = find-backlinks(page);
  backlinks := map(title, backlinks);
  gvr/add-predecessors(node, backlinks);
  gvr/add-successors(node, last(page.versions).references);
  for (node in gvr/nodes(graph))
    node.xml/attributes["URL"] := build-uri(page-permanent-link(node.label));
    node.xml/attributes["color"] := "blue";
    node.xml/attributes["style"] := "filled";
    node.xml/attributes["fontname"] := "Verdana"; 
    node.xml/attributes["shape"] := "note";
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
  save-change(<wiki-page-change>, page.title, #"removal", comment);
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
  save-change(<wiki-page-change>, new-title, #"renaming", comment);
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
    if (page & member?(title, last(page.versions).references, test: \=))
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

/*
define method permitted? (action == #"edit-page", #key)
 => (permitted? :: <boolean>);
  (~ authenticated-user()) & error(make(<authentication-error>));
end;
*/

define function discussion?
    (page :: <wiki-page>)
 => (is-discussion? :: <boolean>);
  let (matched?, discussion, title) =
    regex-search-strings("(Discussion: )(.*)", page.title);
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

define inline-only method latest-text
    (page :: <wiki-page>)
 => (text :: <string>);
  page.versions.last.content.content
end;

define inline-only method latest-tags
    (page :: <wiki-page>)
 => (tags :: <sequence>);
  page.versions.last.categories
end;


// pages

define variable *view-page-page* = 
  make(<wiki-dsp>, source: "view-page.dsp");

define variable *view-diff-page* = 
  make(<wiki-dsp>, source: "view-diff.dsp");

define variable *edit-page-page* = 
  make(<wiki-dsp>, source: "edit-page.dsp");

define variable *edit-page-access-page* =
  make(<wiki-dsp>, source: "edit-page-access.dsp");

define variable *remove-page-page* = 
  make (<wiki-dsp>, source: "remove-page.dsp");

define variable *non-existing-page-page* =
  make(<wiki-dsp>, source: "non-existing-page.dsp");

define variable *list-page-versions-page* = 
  make(<wiki-dsp>, source: "list-page-versions.dsp");

define variable *list-pages-page* =
  make(<wiki-dsp>, source: "list-pages.dsp");

define variable *page-connections-page* =
  make(<wiki-dsp>, source: "page-connections.dsp");

define variable *page-authors-page* =
  make(<wiki-dsp>, source: "page-authors.dsp");

define variable *search-page* =
  make(<wiki-dsp>, source: "search-page.dsp");


// actions

define method do-pages ()
  case
    get-query-value("go") => 
      redirect-to(page-permanent-link(get-query-value("query")));
    otherwise => 
      process-page(*list-pages-page*);
  end;
end;

define method do-save-page (#key title)
  let title = percent-decode(title);
  let new-title = get-query-value("title");
  let content = get-query-value("content");
  let comment = get-query-value("comment");
  let tags = get-query-value("tags");
  let page = find-page(title);

  tags := if (instance?(tags, <string>))
            extract-tags(tags)
          else 
            vector()
          end if;

  let errors = #();

  if (~ instance?(title, <string>)
        | title = ""
        | (new-title & (~ instance?(new-title, <string>) | new-title = "")))
    errors := add!(errors, #"title");
  end if;

  if (page & new-title & new-title ~= title & new-title ~= "")
    if (find-page(new-title))
      errors := add!(errors, #"exists");
    else
      rename-page(page, new-title, comment: comment);
      title := new-title;
    end if;
  end if;

  if (empty?(errors))
    save-page(title, content | "", comment: comment, tags: tags);
    redirect-to(find-page(title));
  else
    dynamic-bind (wf/*errors* = errors,
                  wf/*form* = current-request().request-query-values)
      respond-to(#"get", *edit-page-page*);
    end;
  end if;
end;

define method do-remove-page (#key title)
  let page = find-page(percent-decode(title));
  remove-page(page, comment: get-query-value("comment"));
  redirect-to(page);
end;

define method bind-page (#key title)
  *page* := find-page(percent-decode(title));
end;

define method show-page (#key title, version)
  let version = if (version)
      element(*page*.versions, string-to-integer(version) - 1, default: #f);
    end if;
  dynamic-bind (*version* = version, *page-title* = percent-decode(title))
    respond-to(#"get", case
        *page* => *view-page-page*;
	authenticated-user() => *edit-page-page*;
	otherwise => *non-existing-page-page*;
      end case);
  end;
end method show-page;

define method show-edit-page (#key title)
  dynamic-bind (*page-title* = percent-decode(title))
    respond-to(#"get", case
                         authenticated-user() => *edit-page-page*;
                         otherwise => *non-existing-page-page*;
                       end case); 
  end;
end method show-edit-page;

define method show-page-versions-differences (#key title, a, b)
  let version :: false-or(<wiki-page-version>) = block ()
      if (a)
        element(*page*.versions, string-to-integer(a) - 1, default: #f);
      end;
    exception (<error>) #f end;
  let other-version :: false-or(<wiki-page-version>)
    = block ()
        if (version & instance?(b, <string>))
          element(*page*.versions, string-to-integer(b) - 1, default: #f);
        elseif (version)
          element(*page*.versions, version.version-number - 2, default: #f);
        end;
      exception (<error>)
        #f
      end;
  dynamic-bind(*version* = version,
               *other-version* = other-version)
    respond-to(#"get", *view-diff-page*);
  end;
end method show-page-versions-differences;

define method redirect-to-page-or (page :: <page>, #key title)
  if (*page*)
    respond-to(#"get", page);
  else
    redirect-to(page-permanent-link(percent-decode(title)));
  end if;
end;

define constant show-page-versions =
  curry(redirect-to-page-or, *list-page-versions-page*);

define constant show-page-connections =
  curry(redirect-to-page-or, *page-connections-page*);

define constant show-page-authors =
  curry(redirect-to-page-or, *page-authors-page*);

define constant show-remove-page =
  curry(redirect-to-page-or, *remove-page-page*);

define constant show-page-access =
  curry(redirect-to-page-or, *edit-page-access-page*);


// tags

define tag show-page-permanent-link in wiki
 (page :: <wiki-dsp>)
 (use-change :: <boolean>)
  output("%s", 
    if (use-change)
      page-permanent-link(*change*.title)
    elseif (*page*)
      permanent-link(*page*)
    else
      ""
    end if);
end;

define tag show-page-page-permanent-link in wiki 
 (page :: <wiki-dsp>)
 ()
  output("%s", if (*page* & discussion?(*page*)) 
                 let link = permanent-link(*page*);
                 last(link.uri-path)
                   := regex-replace(last(link.uri-path), "^Discussion: ", "");
                 link;
               else
                 ""
               end if);
end;

define tag show-page-discussion-permanent-link in wiki
 (page :: <wiki-dsp>)
 ()
  output("%s", if (*page*) 
                 let link = permanent-link(*page*);
                 last(link.uri-path) := concatenate("Discussion: ", last(link.uri-path));
                 link;
               else
                 ""
               end if);                        
end;

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

define tag show-page-content in wiki 
    (page :: <wiki-dsp>)
    (content-format :: false-or(<string>))
  output("%s", if (*page*)
                 let content = (*version* | *page*.versions.last).content.content;
                 case
                   content-format = "xhtml"
                     => parse-wiki-markup(content); //wiki-markup-to-html(content);
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

define body tag list-page-backlinks in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    for (backlink in find-backlinks(*page*))
      dynamic-bind (*page* = backlink)
        do-body();
      end;
    end for;
  end if;
end;

define body tag list-page-tags in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    for (tag in latest-tags(*page*))
      dynamic-bind(*tag* = tag)
        do-body();
      end;
    end for;
  elseif (wf/*form* & element(wf/*form*, "tags", default: #f))
    output("%s", escape-xml(wf/*form*["tags"]));
  end if;
end;

define body tag list-page-versions in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*page*)
    for (version in reverse(*page*.versions))
      dynamic-bind(*version* = version)
        do-body();
      end;
    end for;
  end if;
end;

define body tag list-pages in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    (tags :: false-or(<string>), sort :: false-or(<string>), use-query-tags :: <boolean>)
   let tagged = get-query-value("tagged");
   tags := if (use-query-tags & instance?(tagged, <string>))
             extract-tags(tagged);
           elseif (tags)
             extract-tags(tags);
           end if;
   let pages = if (sort)
                 sort-table(storage(<wiki-page>), select (sort by \=)
                                                    "published" => published
                                                  end);
               else
                 map-as(<vector>, identity, storage(<wiki-page>));
               end if;
   let tagged-pages = if (tags)
                        choose(method (page)
                                 every?(rcurry(member?, page.versions.last.categories,
                                               test:, \=),
                                        tags)
                               end,
                               pages);
                      else
                        pages
                      end if;
  for (page in tagged-pages)
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

define named-method page-discussion? in wiki
    (page :: <wiki-dsp>)
  *page* & discussion?(*page*);
end;

define named-method latest-page-version? in wiki
    (page :: <wiki-dsp>)
  if (*page*)
    if (*version*) 
     *page*.versions.last = *version*
    else
      #t
    end if;
  end if;
end;

define named-method page-changed? in wiki
    (page :: <wiki-dsp>)
  instance?(*change*, <wiki-page-change>)
end;

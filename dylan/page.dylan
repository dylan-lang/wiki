Module: wiki-internal

define thread variable *page-title* = #f;

// Represents a user-editable wiki page that will be stored by web-framework.
// Not to be confused with <wiki-dsp>, which is a DSP maintained in our
// source code tree.
//
define class <wiki-page> (<versioned-object>, <entry>)
  slot page-owner :: <wiki-user>,
    required-init-keyword: owner:;
  slot access-controls :: <acls> = $default-access-controls,
    init-keyword: access-controls:;
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
 => (user :: <user>);
  page.authors := add-new!(page.authors, user, test: method (first, second)
      first.username = second.username
    end);
  user;
end;

define method save-page
    (title :: <string>, content :: <string>, 
     #key comment :: <string> = "", tags :: false-or(<sequence>))
 => ()
  let page :: false-or(<wiki-page>) = find-page(title);
  let action :: <symbol> = #"edit";
  let active-user :: <wiki-user> = authenticated-user();
  if (page)
    if (~has-permission?(active-user, page, $modify-content))
      // temporary
      error("%s has no permission to edit this page", active-user.username);
    end;
  else
    page := make(<wiki-page>,
                 title: title,
                 owner: active-user);
    action := #"add";
  end;
  let version-number :: <integer> = size(page.versions) + 1;
  if (version-number = 1 | (content ~= page.latest-text) | tags ~= page.latest-tags)
    let version = make(<wiki-page-version>,
                       content: make(<raw-content>, content: content),
                       authors: list(active-user),
                       version: version-number,
                       page: page,
		       categories: tags & as(<vector>, tags));
    let comment = make(<comment>,
                       name: as(<string>, action),
                       authors: list(active-user.username),
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
                      authors: list(active-user.username));
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

define constant $view-page-page
  = make(<wiki-dsp>, source: "view-page.dsp");

define constant $view-diff-page
  = make(<wiki-dsp>, source: "view-diff.dsp");

define constant $edit-page-page
  = make(<wiki-dsp>, source: "edit-page.dsp");

define constant $remove-page-page
  = make (<wiki-dsp>, source: "remove-page.dsp");

define constant $non-existing-page-page
  = make(<wiki-dsp>, source: "non-existing-page.dsp");

define constant $list-page-versions-page
  = make(<wiki-dsp>, source: "list-page-versions.dsp");

define constant $list-pages-page
  = make(<wiki-dsp>, source: "list-pages.dsp");

define constant $page-connections-page
  = make(<wiki-dsp>, source: "page-connections.dsp");

define constant $page-authors-page
  = make(<wiki-dsp>, source: "page-authors.dsp");

define constant $search-page
  = make(<wiki-dsp>, source: "search-page.dsp");


// actions

define method do-pages ()
  case
    get-query-value("go") => 
      redirect-to(page-permanent-link(get-query-value("query")));
    otherwise => 
      process-page($list-pages-page);
  end;
end;

define method do-save-page (#key title :: <string>)
  let title = percent-decode(title);
  let page = find-page(title);
  if (~page)
    // Do something better here.  Need an actual error message.
    redirect-to($non-existing-page-page);
  else
    // maybe add a way to specify arguments to with-query-values, like
    // with-query-values (foo, bar) (trim: #t) ... end
    with-query-values (title as new-title, content, comment, tags)
      let errors = #();
      let tags = iff(tags, extract-tags(tags), #[]);
      let new-title = new-title & trim(new-title);
      if (new-title & ~empty?(new-title) & new-title ~= title)
        // todo -- potential race conditions here.  Should really lock the old and
        //         new pages around the find-page and rename-page. Low priority now.
        if (find-page(new-title))
          errors := add!(errors, #"exists");
        else
          title := new-title;
          rename-page(page, new-title, comment: comment);
        end;
      end;
      if (empty?(errors))
        save-page(title, content | "", comment: comment, tags: tags);
        redirect-to(find-page(title));
      else
        dynamic-bind (wf/*errors* = errors,
                      wf/*form* = current-request().request-query-values)
          respond-to-get($edit-page-page);
        end;
      end if;
    end;
  end if;
end method do-save-page;

define method do-remove-page (#key title)
  let page = find-page(percent-decode(title));
  remove-page(page, comment: get-query-value("comment"));
  redirect-to(page);
end;

define method show-page (#key title :: <string>, version)
  let title = percent-decode(title);
  let page = find-page(title);
  let version = if (page & version)
                  element(page.versions, string-to-integer(version) - 1, default: #f);
                end if;
  dynamic-bind (*page* = page,
                *version* = version,
                *page-title* = title)
    respond-to-get(case
                     *page* => $view-page-page;
                     authenticated-user() => $edit-page-page;
                     otherwise => $non-existing-page-page;
                   end);
  end;
end method show-page;

define method show-edit-page (#key title)
  dynamic-bind (*page-title* = percent-decode(title),
                *page* = find-page(*page-title*))
    respond-to-get(case
                     authenticated-user() => $edit-page-page;
                     otherwise => $non-existing-page-page;
                   end case); 
  end;
end method show-edit-page;

define method show-page-versions-differences (#key title :: <string>, a, b)
  dynamic-bind (*page* = find-page(percent-decode(title)))
    let version :: false-or(<wiki-page-version>)
      = block ()
          if (a)
            element(*page*.versions, string-to-integer(a) - 1, default: #f);
          end;
        exception (<error>)
          #f
        end;
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

define constant show-page-versions =
  curry(redirect-to-page-or, $list-page-versions-page);

define constant show-page-connections =
  curry(redirect-to-page-or, $page-connections-page);

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
    output("%s", escape-xml(*page*.page-owner.username))
  end;
end;

define tag show-page-content in wiki
    (page :: <wiki-dsp>)
    (content-format :: false-or(<string>))
  output("%s", if (*page*)
                 let content = (*version* | *page*.versions.last).content.content;
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
    (tags :: false-or(<string>),
     order-by :: false-or(<string>),
     use-query-tags :: <boolean>)
   let tagged = get-query-value("tagged");
   tags := if (use-query-tags & instance?(tagged, <string>))
             extract-tags(tagged);
           elseif (tags)
             extract-tags(tags);
           end if;
   let pages = if (order-by)
                 sort-table(storage(<wiki-page>),
                            select (sort by \=)
                              "published" => date-published;
                              otherwise => date-published;
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

define named-method is-discussion-page? in wiki
    (page :: <wiki-dsp>)
  *page* & discussion-page?(*page*);
end;

define named-method latest-page-version? in wiki
    (page :: <wiki-dsp>)
  *page* & (~*version* | *page*.versions.last = *version*)
end;

define named-method page-changed? in wiki
    (page :: <wiki-dsp>)
  instance?(*change*, <wiki-page-change>)
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


Module:    wiki
Author:    Carl Gay
Synopsis:  Dylan wiki engine
Copyright: This code is in the public domain.


define variable *database-directory* :: <locator>
  = as(<directory-locator>, "/home/andreas/fd-build/www/wiki/content");

define variable *results-per-page* :: <integer> = 20;  // NYI

define thread variable *title* = #f;
define variable *default-title* = "Home";

// This is only used to save the page content across requests when
// the page title is invalid.
define thread variable *content* = #f;

// Tell Koala how to parse the wiki config element.
//
define sideways method process-config-element
    (node :: <xml-element>, name == #"wiki")
  let cdir = get-attr(node, #"content-directory");
  if (~cdir)
    log-warning("Wiki - No content-directory specified.  Will use ./content/");
    cdir := "./content";
  end;
  *database-directory* := as(<directory-locator>, cdir);
  log-info("Wiki content directory = %s", as(<string>, *database-directory*));
end;

define taglib wiki ()
end;

define class <wiki-page> (<dylan-server-page>)
end;

define method make-wiki-locator
    (title :: <string>, version :: <integer>) => (loc :: <file-locator>)
  merge-locators(as(<file-locator>, 
                    format-to-string("%s.%d", base64-encode(title), version)), 
                 *database-directory*)
end;

// Lookup the editable wiki content of the given page based
// on the page title.  Page content is HTML.
//
define method page-content
    (title :: <string>, #key format = #"raw")
 => (content :: <string>)
  let raw-text = load-page(title) | "(no content)";
  select (format)
    #"raw" => raw-text;
    #"html" => wiki-markup-to-html(raw-text);
    otherwise => error("Invalid format (%=) requested.", format);
  end
end;

define method save-page
    (title :: <string>, content :: <string>)
  let version = newest-version-number(title) + 1;
  // TODO: compare with previous version and don't save if no changes.
  let loc = make-wiki-locator(title, version);
  with-open-file(out = loc,
                 element-type: <character>,
                 direction: #"output",
                 if-exists: #"signal",
                 if-does-not-exist: #"create")
    write(out, content);
  end;
end method save-page;

define method load-page
    (title :: <string>) => (raw-text :: false-or(<string>))
  let version = newest-version-number(title);
  file-contents(make-wiki-locator(title, version));
end method load-page;

define method page-exists?
    (title :: <string>) => (exists? :: <boolean>)
  newest-version-number(title) ~== 0
end;

define function split-version
    (filename :: <string>)
 => (filename :: <string>, version :: false-or(<integer>))
  let parts = split(filename, separator: ".");
  if (parts.size < 2)
    values(filename, #f)
  else
    let base = parts[0];
    if (parts.size > 2)
      base := join(copy-sequence(parts, end: parts.size - 1), ".");
    end;
    values(base,
           block ()
             string-to-integer(parts[parts.size - 1])
           exception (e :: <error>)
             #f
           end)
  end
end function split-version;

// Title is the page title without any version number suffixed to it.
// Returns the largest (newest) version number of the file with that title.
// If no files with this title exist, returns 0.
define method newest-version-number
    (title :: <string>) => (version :: <integer>)
  let biggest :: <integer> = 0;
  let encoded-title = base64-encode(title);
  local method fun (dir-loc, filename, file-type)
          if (file-type = #"file")
            let (base, version) = split-version(filename);
            if (base = encoded-title)
              biggest := max(biggest, version | biggest);
            end;
          end;
        end method fun;
  do-directory(fun, *database-directory*);
  biggest
end method newest-version-number;

define page view-page (<wiki-page>)
    (url: "/wiki/view.dsp",
     source: "wiki/view.dsp")
end;

define method respond-to-get
    (page :: <view-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = get-query-value("title") | *default-title*,
                *content* = page-content(*title*, format: #"html"))
    next-method();    // process the DSP template
  end;
end;

define page edit-page (<wiki-page>)
    (url: "/wiki/edit.dsp",
     source: "wiki/edit.dsp")
end;

define method respond-to-get
    (page :: <edit-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = *title* | get-query-value("title") | *default-title*,
                *content* = *content* | page-content(*title*, format: #"raw"))
    next-method();    // process the DSP template
  end;
end;

define method respond-to-post
    (page :: <edit-page>, request :: <request>, response :: <response>)
  let title = trim(get-query-value("title") | "");
  let content = get-query-value("page-content") | "";
  if (title = "")
    note-form-error("You must supply a valid page title.",
                    field: "title");
    // redisplay edit page.
    dynamic-bind (*title* = title,
                  *content* = content)
      respond-to-get(page, request, response);
    end;
  else
    block ()
      save-page(title, content);
      // Show the page after editing
      respond-to-get(*view-page*, request, response);
    exception (e :: <file-exists-error>)
      note-form-error(format-to-string("A page named '%s' already exists.  Please choose a new title.",
                                       title),
                      field:, "title");
      // redisplay edit page.
      dynamic-bind (*title* = title,
                    *content* = content)
        respond-to-get(page, request, response);
      end;
    end;
  end;
end;

// Not sure this is even needed.
define page new-page (<wiki-page>)
    (url: "/wiki/new.dsp",
     source: "wiki/edit.dsp")
end;

define method respond-to-get
    (page :: <new-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = "",
                *content* = "")
    respond-to-get(*edit-page*, request, response);
  end;
end;

define page search-page (<wiki-page>)
    (url: "/wiki/search.dsp",
     source: "wiki/search.dsp")
end;

define thread variable *search-results* = #();
define thread variable *search-result* = #f;

define method respond-to-get
    (page :: <search-page>, request :: <request>, response :: <response>)
  let search-string = trim(get-query-value("search-terms") | "");
  if (search-string = "")
    note-form-error("You must supply some search terms.",
                    field: "search-terms");
    // TODO: should redisplay the origin page.
    next-method();
  else
    let search-words = split(search-string);
    dynamic-bind (*search-results* = do-search(search-words))
      next-method();
    end;
  end;
end method respond-to-get;

define class <search-result> (<object>)
  constant slot sr-title :: <string>, required-init-keyword: #"title";
  constant slot sr-version :: <integer>, required-init-keyword: #"version";
  constant slot sr-weight :: <integer>, required-init-keyword: #"weight";
end;

// Search all the wiki pages for the given words.
// Always return the page version number in the results
// in case the page is modified while the search is underway.
define method do-search
    (words :: <collection>, #key include-old-versions?)
 => (results :: <collection>)
  // TODO: implement include-old-versions? = #f
  let matching-files = make(<stretchy-vector>);
  // First pass just see if any of the words appear anywhere in
  // any version of the document...
  local method find-matches (dir-loc, file-name, file-type)
          if (file-type == #"file")
            let loc = merge-locators(as(<file-locator>, file-name), dir-loc);
            let weight = search-file(loc, words);
            if (weight > 0)
              let (base, version) = split-version(file-name);
              matching-files := add!(matching-files,
                                     make(<search-result>,
                                          title: base64-decode(base),
                                          version: version,
                                          weight: weight));
            end;
          end;
        end method find-matches;
  do-directory(find-matches, *database-directory*);
  sort(matching-files, test: method (x, y) x.sr-weight > y.sr-weight end)
end method do-search;

// Search the given file for the given words and return a number
// indicating how good a match was found.  Bigger is better.
define method search-file
    (file :: <file-locator>, words)
 => (weight :: <integer>)
  let text = file-contents(file);
  if (~text)
    0
  else
    let weight = 0;
    // TODO: This is hideously expensive.  Optimize it.
    for (i from 0 below text.size)
      for (word in words)
        if (i + word.size <= text.size)
          if (string-equal?(word, copy-sequence(text, start: i, end: i + word.size)))
            inc!(weight, word.size);
          end;
        end;
      end;
    end;
    weight
  end
end method search-file;

define body tag do-search-results in wiki
    (page :: <search-page>, response :: <response>, do-body :: <function>)
    ()
  let next = 0;  // TODO: view 20 results per page
  for (index from next below next + *results-per-page*,
       while: index < size(*search-results*))
    let result = *search-results*[index];
    dynamic-bind(*search-result* = result)
      do-body()
    end;
  end;
end;

define tag search-result-title in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response), sr-title(*search-result*));
end;
  
define tag search-result-version in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response), integer-to-string(sr-version(*search-result*)));
end;
  
define tag show-search-result in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response), *search-result*);
end;

define tag show-page-title in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), *title* | "(no title)");
end;

define tag show-page-content in wiki
    (page :: <wiki-page>, response :: <response>)
    (format :: <string> = "raw")
  write(output-stream(response),
        *content* | page-content(*title*, format: as(<symbol>, format)));
end;

define function main
    () => ()
  start-server();
end;

begin
  main()
end;


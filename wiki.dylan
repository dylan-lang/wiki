Module:    wiki
Author:    Carl Gay
Synopsis:  Dylan wiki engine
Copyright: This code is in the public domain.


// This can be set to a more appropriate value via the <wiki> element
// in koala-config.xml.
define variable *database-directory* :: <locator>
  = as(<directory-locator>, "www/wiki/content");

define thread variable *title* = #f;
define thread variable *version* = #"newest";
define variable *default-title* = "Home";

// This is only used to save the page content across requests when
// the page title is invalid.
define thread variable *content* = #f;

define constant sformat = format-to-string;


define taglib wiki ()
end;

define class <wiki-page> (<dylan-server-page>)
end;

define generic page-editable? (page :: <wiki-page>) => (editable? :: <boolean>);

define method  page-editable? (page :: <wiki-page>) => (editable? :: <boolean>)
  #t
end;

define method make-wiki-locator
    (title :: <string>, version :: <integer>)
 => (loc :: <file-locator>)
  merge-locators(as(<file-locator>, 
                    sformat("%s.%d", base64-encode(title), version)), 
                 *database-directory*)
end;

// Lookup the editable wiki content of the given page based
// on the page title.  Page content is HTML.
//
define method page-content
    (title :: <string>, #key format = #"raw", version = #"newest")
 => (content :: false-or(<string>))
  let raw-text = load-page(title, version: version);
  if (raw-text)
    select (format)
      #"raw" => raw-text;
      // HACK HACK HACK.  Prepend a newline so the start-of-line context applies.
      #"html" => wiki-markup-to-html(concatenate("\n", raw-text));
      otherwise => error("Invalid format (%=) requested.", format);
    end
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
    (title :: <string>, #key version = #"newest")
 => (raw-text :: false-or(<string>))
  let v = ((version == #"newest")
           & newest-version-number(title)
           | version);
  file-contents(make-wiki-locator(title, v));
end method load-page;

define method page-exists?
    (title :: <string>) => (exists? :: <boolean>)
  newest-version-number(title) ~== 0
end;

define function parse-version
    (v, #key default) => (v :: <object>)
  if (~v)
    default | #"newest"
  elseif (string-equal?(v, "newest"))
    #"newest"
  else
    ignore-errors(string-to-integer(v)) | default
  end
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
     source: "wiki/view.dsp",
     alias: #("/wiki/", "/wiki", "/"))
end;

define method respond-to-get
    (page :: <view-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = get-query-value("title") | *default-title*,
                *version* = parse-version(get-query-value("v"), default: #"newest"),
                *content* = page-content(*title*, version: *version*, format: #"html")
                            | "(no content)")
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
                *version* = parse-version(get-query-value("v")),
                *content* = page-content(*title*, version: *version*, format: #"raw")
                            | "")
    log-debug("version = %=, content = %=", *version*, *content*);
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

define method  page-editable? (page :: <search-page>) => (editable? :: <boolean>)
  #f
end;

define named-method editable? in wiki
    (page :: <wiki-page>, request :: <request>)
  page-editable?(page)
end;

define method respond-to-get
    (page :: <search-page>, request :: <request>, response :: <response>)
  let search-string = trim(get-query-value("search-terms") | "");
  dynamic-bind (*title* = sformat("Search Results for &quot;%s&quot;", search-string))
    if (search-string = "")
      note-form-error("You must supply some search terms.",
                      field: "search-terms");
      // TODO: should redisplay the origin page.
      next-method();
    else
      dynamic-bind (*search-results* = do-search(search-string))
        next-method();
      end;
    end;
  end;
end method respond-to-get;

define class <search-result> (<object>)
  constant slot search-result-title :: <string>, required-init-keyword: #"title";
  constant slot search-result-version :: <integer>, required-init-keyword: #"version";
  constant slot search-result-weight :: <integer>, required-init-keyword: #"weight";
  constant slot search-result-summary :: <string>, required-init-keyword: #"summary";
end;

// Search all the wiki pages for the given words.
// Returns an ordered collection of lists, each of which contains all
// matched versions of a given page title.
//
define method do-search
    (search-string :: <collection>, #key include-old-versions?)
 => (results :: <collection>)
  // TODO: implement include-old-versions? = #f
  let words = concatenate(list(search-string), split(search-string));
  let matches = make(<string-table>);
  local method find-matches (dir-loc, file-name, file-type)
          if (file-type == #"file")
            let loc = merge-locators(as(<file-locator>, file-name), dir-loc);
            let (weight, summary) = search-file(loc, words);
            if (weight > 0)
              let (base, version) = split-version(file-name);
              let title = ignore-errors(base64-decode(base));
              if (title)
                matches[base] := add!(element(matches, base, default: list()),
                                      make(<search-result>,
                                           title: title,
                                           version: version,
                                           weight: weight,
                                           summary: summary));
              end;
            end;
          end;
        end method find-matches;
  do-directory(find-matches, *database-directory*);
  local method sr-> (x, y)
          x.search-result-weight > y.search-result-weight
        end;
  for (versions keyed-by title in matches)
    matches[title] := sort(versions, test: sr->);
  end;
  local method srl-> (x, y)
          x[0].search-result-weight > y[0].search-result-weight
        end;
  sort(table-values(matches), test: srl->)
end method do-search;

// Search the given file for the given words and return a number
// indicating how good a match was found.  Bigger is better.
// The first item in 'words' is the entire search string, so it
// should be weighted more heavily.
define method search-file
    (file :: <file-locator>, words)
 => (weight :: <integer>, summary :: <string>)
  let text = file-contents(file);
  if (~text)
    values(0, "")
  else
    let weight = 0;
    let longest-match = 0;
    let summary = "";
    // TODO: This is hideously expensive.  Optimize it.
    for (i from 0 below text.size)
      for (word in words, word-n from 0)
        if (i + word.size <= text.size)
          if (string-equal?(word, copy-sequence(text, start: i, end: i + word.size)))
            inc!(weight, iff(word-n == 0,
                             10 * word.size,
                             5 * word.size));
            if (word.size > longest-match)
              longest-match := word.size;
              // For now just take 200 characters centered around the match...
              summary := copy-sequence(text,
                                       start: max(0, i - 100),
                                       end: min(text.size, i + 100));
            end if;
          end if;
        end if;
      end for;
    end for;
    values(weight, summary)
  end if
end method search-file;

define named-method gen-search-results in wiki
    (page :: <search-page>)
  *search-results*
end;

define function current-search-result ()
  let row = *search-result* | current-row();
  iff(instance?(row, <collection>),
      row[0],
      row)
end;

define tag sr-title in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response), search-result-title(current-search-result()));
end;

define tag sr-version in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response), integer-to-string(search-result-version(current-search-result())));
end;
  
define tag sr-summary in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response), search-result-summary(current-search-result()));
end;
  
define body tag do-versions in wiki
    (page :: <search-page>, response :: <response>, do-body :: <function>)
    ()
  for (sr in copy-sequence(current-row(), start: 1))
    dynamic-bind (*search-result* = sr)
      do-body();
    end;
  end;
end;

// Show the page title.  If v is true, show the version number if it's not
// the newest version of the page.
define tag show-title in wiki
    (page :: <wiki-page>, response :: <response>)
    (v :: <boolean>, for-url :: <boolean>)
  let out = output-stream(response);
  let title = *title* | "(no title)";
  write(out, title);
  if (v)
    // show version, if not newest
    let newest = newest-version-number(title);
    log-debug("newest = %=, *version* = %=", newest, *version*);
    if (*version* ~== #"newest" & *version* ~== newest)
      format(out, for-url & "&v=%s" | " (version %s)", *version*);
    end;
  end;
end;

define tag show-content in wiki
    (page :: <wiki-page>, response :: <response>)
    (format :: <string> = "raw")
  write(output-stream(response),
        page-content(*title*, version: *version*, format: as(<symbol>, format))
        | *content* | "");
end;

define tag show-revisions in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  // TODO
end;

define page recent-changes-page (<wiki-page>)
    (url: "/wiki/recent.dsp",
     source: "wiki/recent.dsp")
end;

define named-method gen-recent-changes
    (page :: <recent-changes-page>)
  // TODO
  #()
end;

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

define function main
    () => ()
  let config-file =
    if(application-arguments().size > 0)
      application-arguments()[0]
    end;
  start-server(config-file: config-file);
end;

begin
  main()
end;


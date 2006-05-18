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
  #f
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
  newest-version-table[base64-encode(title)] := version;
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

define constant newest-version-table :: <string-table> =
 make(<string-table>);

// Title is the page title without any version number suffixed to it.
// Returns the largest (newest) version number of the file with that title.
// If no files with this title exist, returns 0.
define method newest-version-number
    (title :: <string>) => (version :: <integer>)
  element(newest-version-table, base64-encode(title), default: 0);
end method newest-version-number;

define page view-page (<wiki-page>)
    (url: "/wiki/view.dsp",
     source: "wiki/view.dsp",
     alias: #("/wiki/", "/wiki", "/"))
end;

define method page-editable? (page :: <view-page>) => (editable? :: <boolean>)
  #t
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
                *content* = page-content(*title*, 
                                         version: *version*, 
                                         format: #"raw")
                            | "")
    log-debug("version = %=, content = %=", *version*, *content*);
    next-method();    // process the DSP template
  end;
end;

define method respond-to-post
    (page :: <edit-page>, request :: <request>, response :: <response>)
  let title = trim(get-query-value("title") | "");
  let content = get-query-value("page-content") | "";
  if (~ user-logged-in?(request))
    note-form-error("You must be logged in to edit a page.");
    // redisplay edit page.
    dynamic-bind (*title* = title,
                  *content* = content)
      respond-to-get(page, request, response);
    end;
  elseif (title = "")
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
      note-form-error
        (format-to-string
           ("A page named '%s' already exists.  Please choose a new title.",
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

define page login-page (<wiki-page>)
    (url: "/wiki/login.dsp",
     source: "wiki/login.dsp")
end;

define method respond-to-post (page :: <login-page>,
                               request :: <request>,
                               response :: <response>)
  let username = get-query-value("username");
  let password = get-query-value("password");
  let username-supplied? = username & username ~= "";
  let password-supplied? = password & password ~= "";
  if (username-supplied? & password-supplied?)
    //two cases: login or add new user
    let createuser = get-query-value("adduser");
    if (createuser & (createuser ~= ""))
      //try to add user
      let email = get-query-value("email");
      let email-supplied? = email & email ~= "";
      if (email-supplied?)
        unless (adduser(username, password, email))
          note-form-error("Sorry, username already in use.");
        end unless;
      else
        note-form-error("You must supply an eMail-address to add a new user.");
      end if;
    end if;

    if (valid-user?(username, password))
      //try to login with specified username and password
      let session = ensure-session(request);
      set-attribute(session, #"username", username);
      set-attribute(session, #"password", password);
      let referer = get-query-value("referer");
      if (referer & referer ~= "")
        let headers = response.response-headers;
        add-header(headers, "Location", referer);
        see-other-redirect(headers: headers);
      end if;
    else
      note-form-error("Invalid user or wrong password.");
    end if;
  else
    note-form-error("You must supply <b>both</b> a username and password.");
  end;
  next-method();  // process the DSP template
end;

define variable *users* = make(<string-table>);

define constant $user-db = "users.txt";

define method adduser (username :: <string>,
                       password :: <string>,
                       email :: <string>)
 => (result :: <boolean>)
  unless (element(*users*, username, default: #f))
    #f;
  end unless;
  *users*[username] := list(password, email);
  with-open-file(stream = $user-db,
                 direction: #"output",
                 if-exists: #"append")
    write(stream, concatenate(username, ":", password, ":", email, "\n"));
  end;
  #t;
end;

define method restore-users () => ()
  with-open-file(stream = $user-db,
                 direction: #"input",
                 if-does-not-exist: #"create")
    until(stream-at-end?(stream))
      let line = read-line(stream, on-end-of-stream: #f);
      if (line)
        let password-start = char-position(':', line, 0, line.size);
        let email-start = char-position-from-end(':', line, 0, line.size);
        let user = copy-sequence(line,
                                 start: 0,
                                 end: password-start);
        let password = copy-sequence(line,
                                     start: password-start + 1,
                                     end: email-start);
        let email = copy-sequence(line,
                                  start: email-start + 1,
                                  end: line.size);
        *users*[user] := list(password, email);
      end if;
    end until;
  end;
end;

define method valid-user? (username :: <string>,
                           password :: <string>)
 => (result :: <boolean>)
  if ((element(*users*, username, default: #f)) &
        (*users*[username][0] = password))
    #t;
  else
    #f;
  end if;
end;

define page logout-page (<wiki-page>)
    (url: "/wiki/logout.dsp",
     source: "wiki/logout.dsp")
end;

define method respond-to-get (page :: <logout-page>,
                              request :: <request>,
                              response :: <response>)
  clear-session(request);
  next-method();  // Must call this if you want the DSP template to be processed.
end;



define page search-page (<wiki-page>)
    (url: "/wiki/search.dsp",
     source: "wiki/search.dsp")
end;

define thread variable *search-results* = #();
define thread variable *search-result* = #f;

define named-method editable? in wiki
    (page :: <wiki-page>, request :: <request>)
  let session = get-session(request);
  session & get-attribute(session, #"username") & page-editable?(page)
end;

define named-method logged-in? in wiki
    (page, request)
  user-logged-in?(request)
end;

define method user-logged-in? (request :: <request>)
  let session = get-session(request);
  session & get-attribute(session, #"username");
end method user-logged-in?;

define method respond-to-get
    (page :: <search-page>, request :: <request>, response :: <response>)
  let search-string = trim(get-query-value("search-terms") | "");
  dynamic-bind (*title* = sformat("Search Results for &quot;%s&quot;",
                                  search-string))
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
            let (base, version) = split-version(file-name);
            let title = ignore-errors(base64-decode(base));
            let (weight, summary) = search-file(title, loc, words);
            if (weight > 0)
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
    (title :: <string>, file :: <file-locator>, words)
 => (weight :: <integer>, summary :: <string>)
  let text = file-contents(file) | "";
  let (weight, summary) = search-text(title, words);
  if (weight > 0)
    weight := weight * 2;
    summary := copy-sequence(text, start: 0, end: min(text.size, 200));
  end;
  let (weight2, summary2) = search-text(text, words);
  weight := weight + weight2;
  if (size(summary2) ~= 0)
    summary := summary2;
  end;
  values(weight, summary)
end method search-file;

// TODO: This is truly awful.  It needs to be rewritten in a way that
//       * isn't hideously expensive
//       * properly weights matches of several search terms in order
//       * renders the wiki markup in the summary text and highlights search terms
//       * (optionally?) searches the rendered wiki markup, not the raw source
define method search-text
    (text :: <string>, words)
 => (weight :: <integer>, summary :: <string>)
  let longest-match = 0;
  let weight = 0;
  let summary = "";
  for (i from 0 below text.size)
    for (word in words,
         word-n from 0)
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
end method search-text;

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
  write(output-stream(response),
        integer-to-string(search-result-version(current-search-result())));
end;
  
define tag sr-summary in wiki
    (page :: <search-page>, response :: <response>)
    ()
  write(output-stream(response),
        search-result-summary(current-search-result()));
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

define body tag show-revisions in wiki
    (page :: <wiki-page>, response :: <response>, do-body :: <function>)
    (first :: <string>, last :: <string>)
    let revisions = make(<list>);
    let last = as(<integer>,last);
    local method find-revisions (dir-loc, file-name, file-type)
          if (file-type == #"file")
            let loc = merge-locators(as(<file-locator>, file-name), dir-loc);
            let (base, version) = split-version(file-name);
            let title = ignore-errors(base64-decode(base));
            if (title & (title = *title*))
              revisions := add!(revisions, version);
            end;
          end;
    end;
    do-directory(find-revisions, *database-directory*);
    log-debug("%=", revisions);
    let esize = 0;
        if (size(revisions) <= last) 
          esize := size(revisions); 
        else 
          esize := last; 
        end; 
    revisions := copy-sequence (reverse!(sort(revisions)), start: as(<integer>, first), end: esize);
    for(rev in revisions)
      dynamic-bind (*search-result* = rev)
        do-body();
      end;
    end;
end;

define tag version in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), integer-to-string(*search-result*));
end;

define tag username in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  let session = get-session(get-request(response));
  session & write(output-stream(response),
                  get-attribute(session, #"username"));
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
  populate-version-cache();
end;

define method populate-version-cache() => ()
  local method fun (dir-loc, filename, file-type)
          if (file-type = #"file")
            let (base, version) = split-version(filename);
            let biggest = element(newest-version-table, base, default: 0);
            newest-version-table[base] := max(biggest, version | biggest);
          end;
        end method fun;
  do-directory(fun, *database-directory*);
end method;

define function main
    () => ()
  let config-file =
    if(application-arguments().size > 0)
      application-arguments()[0]
    end;
  //register-url("/wiki/wiki.css", maybe-serve-static-file);
  restore-users();
  start-server(config-file: config-file);
end;

begin
  main()
end;


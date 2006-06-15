Module:    wiki
Author:    Carl Gay
Synopsis:  Dylan wiki engine
Copyright: This code is in the public domain.


define method storage-type (type == <wiki-page-content>) => (res)
  <string-table>;
end;

define thread variable *title* = #f;
define thread variable *version* = #f;

define variable *default-title* = "Home";

// This is only used to save the page content across requests when
// the page title is invalid.
define thread variable *content* = #f;

define taglib wiki ()
end;

define class <wiki-page> (<dylan-server-page>)
  slot page-title :: false-or(<string>) = #f, init-keyword: page-title:;
end;

define generic page-editable? (page :: <wiki-page>) => (editable? :: <boolean>);

define method  page-editable? (page :: <wiki-page>) => (editable? :: <boolean>)
  #f
end;

// Lookup the editable wiki content of the given page based
// on the page title.  Page content is HTML.
//
define method page-content
    (title :: <string>, #key format = #"raw", version)
 => (content :: false-or(<string>))
  let page = find-page(title);
  if (page)
    let latest = page.revisions.last;
    let raw-text = if (version & version > 0 & version <= latest.page-version)
                     page.revisions[version - 1].content;
                   else
                     latest.content
                   end;
    select (format)
      #"raw" => raw-text;
      // HACK HACK HACK.  Prepend a newline so the start-of-line context applies.
      #"html" => wiki-markup-to-html(concatenate("\n", raw-text));
      otherwise => error("Invalid format (%=) requested.", format);
    end
  end
end;


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
                *version* = ignore-errors(string-to-integer(get-query-value("v"))),
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
  dynamic-bind (*title* = *title* | get-query-value("title"),
                *content* = if (*title* & find-page(*title*))
                              latest-text(find-page(*title*));
                            else
                              ""
                            end)
    log-debug("title = %=, content = %=", *title*, *content*);
    next-method();    // process the DSP template
  end;
end;

define named-method new-page? in wiki
  (page :: <wiki-page>, request :: <request>)
  *title* = ""
end;

define method respond-to-post
    (page :: <edit-page>, request :: <request>, response :: <response>)
  let title = trim(get-query-value("title") | "");
  let content = get-query-value("page-content") | "";
  if (~ logged-in?(request))
    note-form-error("You must be logged in to edit a page.");
    // redisplay edit page.
    dynamic-bind (*title* = title,
                  *content* = content)
      respond-to-get(page, request, response);
    end;
  elseif (title = "")
    note-form-error("You must supply a valid page title.", field: "title");
    // redisplay edit page.
    dynamic-bind (*title* = title,
                  *content* = content)
      respond-to-get(page, request, response);
    end;
  else
    save-page(title, content, comment: get-query-value("comment"));
    // Show the page after editing
    respond-to-get(*view-page*, request, response);
  end;
end;

// Not sure this is even needed.
define page new-page (<wiki-page>)
    (url: "/wiki/new.dsp",
     source: "wiki/edit.dsp")
  keyword page-title:, init-value: "(new page)";
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
  keyword page-title:, init-value: "Login";
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
        make(<user>, username: username, password: password, email: email);
      else
        note-form-error("You must supply an eMail-address to add a new user.");
      end if;
    end if;

    if (login(request))
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


define page index-page (<wiki-page>)
    (url: "/wiki/index.dsp",
     source: "wiki/index.dsp")
end;

define page search-page (<wiki-page>)
    (url: "/wiki/search.dsp",
     source: "wiki/search.dsp")
end;

define page backlink-page (<wiki-page>)
    (url: "/wiki/backlink.dsp",
     source: "wiki/backlink.dsp")
end;

define thread variable *search-results* = #();
define thread variable *search-result* = #f;

define named-method editable? in wiki
    (page :: <wiki-page>, request :: <request>)
  logged-in?(request) & page-editable?(page)
end;

define named-method login? in wiki
    (page :: <wiki-page>, request :: <request>)
  logged-in?(request)
end;

define named-method admin? in wiki
    (page :: <wiki-page>, request :: <request>)
  logged-in?(request) & current-user().access <= 23;
end;

define method respond-to-get
    (page :: <search-page>, request :: <request>, response :: <response>)
  let search-string = trim(get-query-value("search-terms") | "");
  dynamic-bind (*title* = concatenate("Search Results for &quot;", search-string, "&quot;"))
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
  let words = concatenate(list(search-string), split(search-string));
  let matches = make(<string-table>);
  local method maybe-add (string, version, title, title-weight)
          let (weight, summary) = search-text(string, words);
          weight := weight + title-weight;
          if (weight > 0)
            matches[title] := add!(element(matches, title, default: #()),
                                   make(<search-result>,
                                        title: title,
                                        weight: weight,
                                        version: version,
                                        summary: summary));
          end;
        end;
  for (title in key-sequence(storage(<wiki-page-content>)))
    let title-weight = search-text(title, words);
    if (include-old-versions?)
      map(method(x)
            maybe-add(x.content, x.page-version, title, title-weight)
          end, storage(<wiki-page-content>)[title].revisions);
    else
      let page = storage(<wiki-page-content>)[title].revisions.last;
      maybe-add(page.content, page.page-version, title, title-weight);
    end;
  end;
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
  let title = *title* | page-title(page) | "(no title)";
  write(out, title);
  if (*title* & v)
    let wiki-page = find-page(*title*);
    if (wiki-page)
      // show version, if not newest
      let newest = page-version(last(wiki-page.revisions));
      log-debug("newest = %=, *version* = %=", newest, *version*);
      if (*version* & *version* < newest)
        format(out, for-url & "&v=%s" | " (version %s)", *version*);
      end;
    end;
  end;
end;

define tag show-content in wiki
    (page :: <wiki-page>, response :: <response>)
    (format :: <string> = "raw")
  write(output-stream(response),
        (*title* & page-content(*title*, version: *version*, format: as(<symbol>, format)))
        | *content*);
end;

define body tag show-revisions in wiki
    (page :: <wiki-page>, response :: <response>, do-body :: <function>)
    (count :: <string>)
  show-revisions-aux(page, do-body, string-to-integer(count));
end;

define method show-revisions-aux (page :: <wiki-page>, do-body :: <function>, count :: <integer>)
end;

define method show-revisions-aux (page :: <view-page>, do-body :: <function>, count :: <integer>)
  let page = find-page(*title*);
  if (page)
    let revs = page.revisions.size;
    let upper-bound = min(count, revs);
    for(i from 0 below upper-bound)
      dynamic-bind (*version* = revs - i)
        do-body();
      end;
    end;
  end;
end;

define method respond-to-get
    (page :: <backlink-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = get-query-value("title") | *default-title*)
    next-method();    // process the DSP template
  end;
end;

define body tag show-backlink in wiki
  (page :: <backlink-page>, response :: <response>, do-body :: <function>)
  ()
  for (backlink in find-backlinks(*title*))
    dynamic-bind (*title* = backlink.page-title)
      do-body()
    end;
  end;
end;

define tag version in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), integer-to-string(*version*));
end;

define tag username in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  let user = current-user();
  if (user)
    write(output-stream(response), user.username);
  end;
end;  

define body tag show-index in wiki
  (page :: <wiki-page>, response :: <response>, do-body :: <function>)
  ()
  for (key in sort(key-sequence(storage(<wiki-page-content>))))
    dynamic-bind(*title* = key)
      do-body();
    end;
  end;
end;

define page recent-changes-page (<wiki-page>)
    (url: "/wiki/recent.dsp",
     source: "wiki/recent.dsp")
end;

define page diff-page (<wiki-page>)
    (url: "/wiki/diff.dsp",
    source: "wiki/diff.dsp")
end;

define thread variable *other-version* = #f;

define method respond-to-get
    (page :: <diff-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = get-query-value("title"),
                *version* = ignore-errors(string-to-integer(get-query-value("version"))),
                *other-version* = ignore-errors(string-to-integer(get-query-value("otherversion"))) | *version* - 1)
    next-method();
  end;
end;

define method print-diffs (out, diff, source, target)
  do(rcurry(print-diff, out, source, target), diff);
end;

define method print-diff (diff :: <insert-entry>, out, source, target)
  write(out, format-to-string("added lines %d - %d:<br>", diff.source-index, diff.element-count + diff.source-index - 1));
  for (line in copy-sequence(target, start: diff.source-index, end: diff.source-index + diff.element-count),
       lineno from diff.source-index)
    write(out, format-to-string("%d: %s<br>", lineno, line));
  end;
end;

define method print-diff (diff :: <delete-entry>, out, source, target)
  write(out, format-to-string("removed lines %d - %d:<br>", diff.dest-index, diff.element-count + diff.dest-index - 1));
  for (line in copy-sequence(source, start: diff.dest-index, end: diff.dest-index + diff.element-count),
       lineno from diff.dest-index)
    write(out, format-to-string("%d: %s<br>", lineno, line));
  end;
end;

define tag show-diff in wiki
  (page :: <diff-page>, response :: <response>)
  ()
  let page = *title* & find-page(*title*);
  let version = *version* & *version* - 1;
  let otherversion = *other-version* & *other-version* - 1;
  //this needs to be refactored
  if (version & otherversion & page & version < page.revisions.size & otherversion < page.revisions.size & otherversion >= -1)
    let target = split(page.revisions[version].content, separator: "\n");
    let source = if (otherversion = -1) #() else split(page.revisions[otherversion].content, separator: "\n") end;
    print-diffs(output-stream(response), sequence-diff(source, target), source, target);
  end;
end;

define tag otherversion in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), integer-to-string(*other-version*));
end;

define thread variable *change* = #f;

define body tag gen-recent-changes in wiki
    (page :: <wiki-page>, response :: <response>, do-body :: <function>)
    (count)
  let count = string-to-integer(get-query-value("count") | count);
  for (i from 0 below count,
       change in reverse(storage(<wiki-page-diff>)))
    dynamic-bind(*change* = change)
      do-body()
    end;
  end;
end;

define method print-date (date :: <date>)
  let $month-names
    = #["Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  let (iyear, imonth, iday, ihours, iminutes,
       iseconds, day-of-week, time-zone-offset)
    = decode-date(date);
  local method wrap0 (i :: <integer>) => (string :: <string>)
          if (i < 10)
            concatenate("0", integer-to-string(i));
          else
            integer-to-string(i)
          end;
        end;
  concatenate(integer-to-string(iday), " ",
              $month-names[imonth - 1], "  ",
              integer-to-string(iyear), "  ",
              wrap0(ihours), ":",
              wrap0(iminutes), ":",
              wrap0(iseconds));
end;

define tag show-change-timestamp in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), print-date(*change*.timestamp));
end;

define tag show-change-title in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), *change*.wiki-page-content.page-title);
end;

define tag show-change-version in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), integer-to-string(*change*.page-version));
end;

define tag show-change-author in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), *change*.author);
end;

define tag show-change-comment in wiki
    (page :: <wiki-page>, response :: <response>)
    ()
  write(output-stream(response), *change*.comment);
end;

define page admin-page (<wiki-page>)
    (url: "/wiki/admin.dsp",
    source: "wiki/admin.dsp")
end;

define page version-page (<wiki-page>)
    (url: "/wiki/version.dsp",
     source: "wiki/version.dsp")
end;

define body tag show-versions in wiki
    (page :: <wiki-page>, response :: <response>, do-body :: <function>)
    ()
  for (version in reverse(find-page(*title*).revisions))
    dynamic-bind (*change* = version)
      do-body();
    end;
  end;
end;

define method respond-to-get
    (page :: <version-page>, request :: <request>, response :: <response>)
  dynamic-bind (*title* = get-query-value("title"))
    next-method();
  end;
end;



define variable *xmpp-bot* = #f;
define function main
    () => ()
  let config-file =
    if(application-arguments().size > 0)
      application-arguments()[0]
    end;
  //register-url("/wiki/wiki.css", maybe-serve-static-file);
  dumper();
  *xmpp-bot* := make(<xmpp-bot>, jid: "dylanbot@jabber.berlin.ccc.de/here", password: "fnord");
  sleep(5);
  start-server(config-file: config-file);
end;


